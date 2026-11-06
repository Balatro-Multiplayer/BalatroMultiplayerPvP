-- Ordered, payload-agnostic channels. Own a manager per lobby/run; feed receive
-- and update centrally. One in-flight head per peer, with contiguous sequences.
-- Timeout stalls but RETAINS the queue. resume(peer) retries the same identity.
-- State is in memory: retarget requires restored receiver progress (or an adapter
-- with idempotent snapshot semantics). This is not durable/transactional delivery.
PVP.ReliableMessages = {}
local RM = PVP.ReliableMessages
RM.__index = RM
local MAX_SEQUENCE = 9007199254740991 -- Exact through Lua numbers and JSON.

local function nonempty_string(value)
	return type(value) == "string" and value ~= ""
end
local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function sequence(value)
	return finite(value) and value >= 0 and value <= MAX_SEQUENCE and value % 1 == 0
end

-- Freeze plain JSON-shaped data. No payload semantics; adapters may supply a
-- serializer round-trip instead. Fail before queueing, so bad data creates no gap.
local function snapshot(value, ancestors)
	local kind = type(value)
	if kind == "nil" or kind == "string" or kind == "boolean" then return value end
	if kind == "number" then
		assert(finite(value), "payload numbers must be finite")
		return value
	end
	assert(kind == "table" and getmetatable(value) == nil, "payload must be plain serializable data")
	ancestors = ancestors or {}
	assert(not ancestors[value], "payload must not contain cycles")
	ancestors[value] = true
	local out, numeric, strings, count, maximum = {}, false, false, 0, 0
	for key, item in pairs(value) do
		if type(key) == "string" then
			strings = true
		else
			assert(sequence(key) and key >= 1, "payload keys must be strings or array indexes")
			numeric, maximum = true, math.max(maximum, key)
		end
		count = count + 1
		out[key] = snapshot(item, ancestors)
	end
	assert(not (numeric and strings) and (not numeric or maximum == count), "payload arrays must be contiguous")
	ancestors[value] = nil
	return out
end

function RM.new(options)
	assert(nonempty_string(options.scope), "reliable messages need a lobby/run scope")
	for _, key in ipairs({ "transmit", "on_message", "on_timeout" }) do
		assert(type(options[key]) == "function", "reliable messages need " .. key)
	end
	assert(options.on_ack == nil or type(options.on_ack) == "function", "on_ack must be a function")
	assert(options.snapshot == nil or type(options.snapshot) == "function", "snapshot must be a function")
	local retry_interval, timeout = options.retry_interval or 2, options.timeout or 30
	local max_pending, max_peers = options.max_pending or 128, options.max_peers or 128
	assert(finite(retry_interval) and retry_interval > 0, "retry_interval must be positive and finite")
	assert(finite(timeout) and timeout > 0, "timeout must be positive and finite")
	assert(sequence(max_pending) and max_pending > 0, "max_pending must be a positive integer")
	assert(sequence(max_peers) and max_peers > 0, "max_peers must be a positive integer")
	return setmetatable({
		_scope = options.scope, _transmit = options.transmit,
		_on_message = options.on_message, _on_timeout = options.on_timeout, _on_ack = options.on_ack,
		_snapshot = options.snapshot or snapshot,
		_retry_interval = retry_interval, _timeout = timeout,
		_max_pending = max_pending, _max_peers = max_peers,
		_channels = {}, _channel_count = 0, _pending_count = 0,
		_received = {}, _received_count = 0,
	}, RM)
end

local function channel(self, peer)
	assert(nonempty_string(peer) and peer ~= "*", "delivery needs one concrete peer")
	local c = self._channels[peer]
	if not c then
		if self._channel_count >= self._max_peers then return nil end
		c = { next_seq = 1, queue = {}, first = 1, last = 0 }
		self._channels[peer] = c
		self._channel_count = self._channel_count + 1
	end
	return c
end

local function transmit_head(self, peer, c)
	if c.sending then return end
	-- Drain synchronous ACKs iteratively, not recursively through the whole queue.
	while self._channels[peer] == c and not c.paused and not c.stalled and not c.applying do
		local entry = c.queue[c.first]
		if not entry then return end
		entry.sent = true -- Before transmit: a local transport may ACK synchronously.
		entry.retry_in = self._retry_interval
		c.sending = true
		local ok, err = pcall(self._transmit, peer, {
			kind = "message", scope = self._scope, seq = entry.seq,
			payload = self._snapshot(entry.payload),
		})
		c.sending = false
		if not ok then error(err, 0) end
		if c.queue[c.first] == entry then return end
	end
end

-- Returns a sequence, or nil + closed/full/peers-full. A sequence means queued,
-- not acknowledged. payload is frozen now; callers may reuse/mutate their table.
function RM:send(peer, payload)
	if self._closed then return nil, "closed" end
	if self._pending_count >= self._max_pending then return nil, "full" end
	local frozen = self._snapshot(payload)
	local c = channel(self, peer)
	if not c then return nil, "peers-full" end
	assert(c.next_seq <= MAX_SEQUENCE, "channel sequence exhausted")
	local seq = c.next_seq
	c.next_seq = seq + 1
	c.last = c.last + 1
	c.queue[c.last] = { seq = seq, payload = frozen, elapsed = 0, retry_in = 0 }
	self._pending_count = self._pending_count + 1
	if c.first == c.last then transmit_head(self, peer, c) end
	return seq
end

-- Read-only view for protocol adapters; never mutate the returned payload.
function RM:head(peer)
	local c = self._channels[peer]
	local entry = c and c.queue[c.first]
	if entry then return entry.seq, entry.payload end
end
function RM:is_pending(peer, seq)
	local c = self._channels[peer]
	if not c then return false end
	for index = c.first, c.last do
		if c.queue[index].seq == seq then return true end
	end
	return false
end
function RM:is_stalled(peer)
	local c = self._channels[peer]
	return c ~= nil and c.stalled == true
end

-- Adapters with their own wire ACK may call this after validating their scope
-- and authoritative response. Only the actually-sent head may be acknowledged.
-- on_ack(peer, response, seq), if provided, must return true after applying state.
function RM:acknowledge(peer, seq, response)
	if self._closed or not sequence(seq) then return false end
	local c = self._channels[peer]
	local entry = c and c.queue[c.first]
	if not entry or not entry.sent or entry.seq ~= seq or c.applying or c.fault then return false end
	if self._on_ack then
		c.applying = true
		local ok, accepted = pcall(self._on_ack, peer, response, seq)
		c.applying = false
		if not ok then c.fault = true; c.stalled = true; error(accepted, 0) end
		if self._closed or self._channels[peer] ~= c or accepted ~= true then return false end
	end
	c.confirmed = entry
	c.queue[c.first] = nil
	c.first = c.first + 1
	self._pending_count = self._pending_count - 1
	c.stalled = false
	if c.first > c.last then c.queue, c.first, c.last = {}, 1, 0 end
	transmit_head(self, peer, c)
	return true
end

-- Clock only the in-flight head. Queued events get their own full deadline.
-- A timeout is UNKNOWN delivery; retain the head and block dependent events.
function RM:update(dt)
	assert(finite(dt) and dt >= 0, "dt must be finite and nonnegative")
	if self._closed then return end
	local heads = {}
	for peer, c in pairs(self._channels) do
		heads[#heads + 1] = { peer = peer, channel = c, entry = c.queue[c.first] }
	end
	for _, item in ipairs(heads) do
		local peer, c, entry = item.peer, item.channel, item.entry
		if entry and self._channels[peer] == c and c.queue[c.first] == entry
			and not c.paused and not c.stalled and not c.applying then
			entry.elapsed = entry.elapsed + dt
			entry.retry_in = entry.retry_in - dt
			if entry.elapsed >= self._timeout then
				c.stalled = true -- Mark first: callbacks may resume/close the manager.
				self._on_timeout(peer, entry.seq, self._snapshot(entry.payload))
			elseif entry.retry_in <= 0 then
				transmit_head(self, peer, c)
			end
		end
	end
end

function RM:pause(peer)
	if self._closed then return false end
	local c = channel(self, peer)
	if not c then return false end
	c.paused = true
	return true
end

-- Re-arm retained work. replay_confirmed=true also queries using the last
-- confirmed event when idle; only use when duplicate handling/state restoration
-- is guaranteed. It does NOT allocate a fresh event identity.
function RM:resume(peer, replay_confirmed)
	if self._closed then return false end
	local c = self._channels[peer]
	if not c or c.fault or c.applying then return false end
	local entry = c.queue[c.first]
	if not entry and replay_confirmed and c.confirmed then
		if self._pending_count >= self._max_pending then return false end
		entry = { seq = c.confirmed.seq, payload = c.confirmed.payload, elapsed = 0 }
		c.queue[1], c.first, c.last = entry, 1, 1
		self._pending_count = self._pending_count + 1
	end
	c.paused, c.stalled = false, false
	if entry then entry.elapsed = 0; transmit_head(self, peer, c) end
	return true
end

-- Explicit handover hook, NOT automatic host migration. Caller must restore the
-- same logical receiver's progress before moving a channel. Old-peer ACKs fail.
function RM:retarget(old_peer, new_peer)
	assert(nonempty_string(new_peer) and new_peer ~= "*", "retarget needs one concrete peer")
	if self._closed then return false end
	local c = self._channels[old_peer]
	if old_peer == new_peer then return c ~= nil end
	if not c or self._channels[new_peer] or c.applying then return false end
	self._channels[old_peer], self._channels[new_peer] = nil, c
	c.paused = true
	return true
end

local function send_ack(self, peer, state)
	self._transmit(peer, {
		kind = "ack", scope = self._scope, seq = state.seq,
		response = self._snapshot(state.response),
	})
end

-- from MUST come from authenticated transport metadata. on_message(from,
-- payload, seq) returns true, response after safe acceptance, or false/nil for a
-- transient refusal with NO effects. Errors block the stream: no automatic
-- re-execution of a handler which may already have partially changed game state.
function RM:receive(from, envelope)
	if self._closed or not nonempty_string(from) or from == "*" or type(envelope) ~= "table"
		or envelope.scope ~= self._scope or not sequence(envelope.seq) then return false end
	if envelope.kind == "ack" then return self:acknowledge(from, envelope.seq, envelope.response) end
	if envelope.kind ~= "message" or envelope.seq == 0 then return false end
	local state = self._received[from]
	if not state then
		if self._received_count >= self._max_peers then return false end
		state = { seq = 0 }
		self._received[from] = state
		self._received_count = self._received_count + 1
	end
	if state.processing or state.fault then return false end
	if envelope.seq > state.seq + 1 then send_ack(self, from, state); return false end
	if envelope.seq == state.seq + 1 then
		state.processing = true
		local ok, accepted, response = pcall(function()
			local accept, result = self._on_message(from, self._snapshot(envelope.payload), envelope.seq)
			if accept == true then return true, self._snapshot(result) end
			return accept
		end)
		state.processing = false
		if not ok then state.fault = true; error(accepted, 0) end
		if self._closed or accepted ~= true then return false end
		state.seq, state.response = envelope.seq, response
	end
	send_ack(self, from, state)
	return true
end

-- Checkpoint hooks for a live process changing authority. They do not write
-- files or solve game-restart recovery. Restore into a fresh manager before use.
function RM:export_channels()
	local saved = {}
	for peer, c in pairs(self._channels) do
		local queue = {}
		for index = c.first, c.last do
			local entry = c.queue[index]
			queue[#queue + 1] = { seq = entry.seq, payload = self._snapshot(entry.payload) }
		end
		saved[peer] = { next_seq = c.next_seq, queue = queue }
	end
	return saved
end

function RM:restore_channels(saved)
	assert(not self._closed and self._channel_count == 0, "restore needs fresh outgoing channels")
	assert(type(saved) == "table", "invalid saved channels")
	saved = snapshot(saved) -- Reject sparse queues/extra array keys before importing anything.
	local channels, peers, pending = {}, 0, 0
	for peer, value in pairs(saved) do
		assert(nonempty_string(peer) and peer ~= "*" and type(value) == "table", "invalid saved peer")
		assert(sequence(value.next_seq) and value.next_seq >= 1 and type(value.queue) == "table", "invalid saved channel")
		local c = { next_seq = value.next_seq, queue = {}, first = 1, last = 0, paused = true }
		local expected
		for _, entry in ipairs(value.queue) do
			assert(sequence(entry.seq) and entry.seq > 0 and entry.seq < c.next_seq
				and (not expected or entry.seq == expected), "invalid saved queue sequence")
			expected = entry.seq + 1
			c.last, pending = c.last + 1, pending + 1
			c.queue[c.last] = { seq = entry.seq, payload = self._snapshot(entry.payload), elapsed = 0, retry_in = 0, sent = true }
		end
		assert(not expected or expected == c.next_seq, "saved queue is missing its tail")
		peers = peers + 1
		channels[peer] = c
	end
	assert(peers <= self._max_peers and pending <= self._max_pending, "saved channels exceed capacity")
	self._channels, self._channel_count, self._pending_count = channels, peers, pending
end

function RM:export_received()
	local out = {}
	for peer, state in pairs(self._received) do
		assert(not state.processing and not state.fault, "cannot checkpoint uncertain receiver effects")
		out[peer] = { seq = state.seq, response = self._snapshot(state.response) }
	end
	return out
end

function RM:restore_received(saved)
	assert(not self._closed and self._received_count == 0, "restore needs fresh receiver cursors")
	local received, count = {}, 0
	for peer, state in pairs(saved) do
		assert(nonempty_string(peer) and peer ~= "*" and type(state) == "table" and sequence(state.seq), "invalid saved cursor")
		count = count + 1
		received[peer] = { seq = state.seq, response = self._snapshot(state.response) }
	end
	assert(count <= self._max_peers, "saved cursors exceed capacity")
	self._received, self._received_count = received, count
end

function RM:close()
	self._closed = true
	self._channels, self._received = {}, {}
	self._pending_count, self._channel_count, self._received_count = 0, 0, 0
end
