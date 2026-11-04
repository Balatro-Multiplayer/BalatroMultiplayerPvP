-- Run from the repo root: texlua tests/unit/reliable_messages_test.lua
PVP = {}
dofile("lib/reliable_messages.lua")
local RM = PVP.ReliableMessages
local passed = 0
local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end
local function test(name, fn)
	fn()
	passed = passed + 1
	print("ok   " .. name)
end
local function packet(kind, seq, payload, scope)
	return { kind = kind, scope = scope or "run-1", seq = seq, payload = payload }
end
local function network(options)
	local n = { peers = {}, queue = {}, calls = {}, timeouts = {}, attempts = {}, down = {} }
	function n:add(peer, overrides)
		local config = {
			scope = "run-1",
			transmit = function(to, envelope)
				self.attempts[#self.attempts + 1] = { from = peer, to = to, envelope = envelope }
				if self.down[peer] then return false end
				self.queue[#self.queue + 1] = { from = peer, to = to, envelope = envelope }
				return true
			end,
			on_message = function(from, payload, seq)
				self.calls[#self.calls + 1] = { to = peer, from = from, payload = payload, seq = seq }
				return true, { accepted = seq }
			end,
			on_timeout = function(to, seq, payload)
				self.timeouts[#self.timeouts + 1] = { from = peer, to = to, seq = seq, payload = payload }
			end,
		}
		for key, value in pairs(options or {}) do config[key] = value end
		for key, value in pairs(overrides or {}) do config[key] = value end
		self.peers[peer] = RM.new(config)
		return self.peers[peer]
	end
	function n:deliver(index)
		local p = assert(table.remove(self.queue, index or 1), "no queued packet")
		return self.peers[p.to]:receive(p.from, p.envelope)
	end
	function n:flush()
		local count = 0
		while #self.queue > 0 do
			self:deliver()
			count = count + 1
			assert(count < 10000, "unexpected message loop")
		end
	end
	n:add("a"); n:add("b"); n:add("c")
	return n, n.peers.a, n.peers.b
end

test("one call queues, applies and acknowledges an opaque payload", function()
	local n, a = network()
	local seq = a:send("b", { action = "anything", score = "1e100" })
	equal(a:is_pending("b", seq), true)
	n:deliver()
	equal(n.calls[1].payload.score, "1e100")
	equal(a:is_pending("b", seq), true)
	n:deliver()
	equal(a:is_pending("b", seq), false)
	a:update(60)
	equal(#n.timeouts, 0)
end)

test("payload is frozen, including across retries and receiver mutations", function()
	local n, a = network()
	local input = { nested = { score = "100" } }
	a:send("b", input)
	input.nested.score = "999"
	n.queue[1].envelope.payload.nested.score = "transport mutation"
	n.queue = {}
	a:update(2)
	equal(n.queue[1].envelope.payload.nested.score, "100")
	n:add("b", { on_message = function(_, payload) payload.nested.score = "handler mutation"; return true end })
	n:deliver()
	n.queue = {}
	a:update(2)
	equal(n.queue[1].envelope.payload.nested.score, "100")
end)

test("scalar false and nil payloads survive without content inspection", function()
	local n, a = network()
	for _, payload in ipairs({ "hello", 42, false }) do
		a:send("b", payload); n:flush()
		equal(n.calls[#n.calls].payload, payload)
	end
	a:send("b", nil); n:flush()
	equal(#n.calls, 4)
	equal(n.calls[4].payload, nil)
end)

test("only one head is in flight and later events wait for its ACK", function()
	local n, a = network()
	local first, second = a:send("b", "first"), a:send("b", "second")
	equal(first, 1); equal(second, 2)
	equal(#n.queue, 1)
	n:deliver()
	equal(#n.calls, 1)
	n:deliver()
	equal(n.queue[1].envelope.seq, 2)
	n:flush()
	equal(n.calls[1].payload, "first")
	equal(n.calls[2].payload, "second")
	equal(a:is_pending("b", second), false)
end)

test("different recipients have independent sequences and progress", function()
	local n, a = network()
	a:send("b", "b1"); a:send("b", "b2")
	local c1 = a:send("c", "c1")
	equal(c1, 1)
	n:deliver(2); n:deliver(2)
	equal(a:is_pending("c", c1), false)
	equal(a:is_pending("b", 1), true)
	n:flush()
end)

test("false send and lost socket writes retry the same sequence", function()
	local n, a = network()
	n.down.a = true
	local seq = a:send("b", "event")
	equal(#n.queue, 0)
	a:update(1); equal(#n.attempts, 1)
	n.down.a = false
	a:update(1); equal(n.queue[1].envelope.seq, seq)
	n.queue = {} -- Successful write lost downstream.
	a:update(2); n:flush()
	equal(#n.calls, 1)
	equal(a:is_pending("b", seq), false)
end)

test("lost ACK retries without reapplying, and returns cached state", function()
	local applied = 0
	local n, a = network({ on_ack = function(_, response) equal(response.lives, 3); return true end })
	n:add("b", { on_message = function() applied = applied + 1; return true, { lives = 3 } end })
	local seq = a:send("b", "event")
	n:deliver(); n.queue = {}
	a:update(2); n:flush()
	equal(applied, 1)
	equal(a:is_pending("b", seq), false)
end)

test("false response values are preserved in cached acknowledgments", function()
	local n, a = network({ on_ack = function(_, response) equal(response, false); return true end })
	n:add("b", { on_message = function() return true, false end })
	local seq = a:send("b", "event")
	n:flush()
	equal(a:is_pending("b", seq), false)
end)

test("receiver refuses sequence gaps and never skips missing effects", function()
	local n, _, b = network()
	equal(b:receive("a", packet("message", 2, "second")), false)
	equal(#n.calls, 0)
	equal(n.queue[1].envelope.seq, 0)
	n.queue = {}
	b:receive("a", packet("message", 1, "first"))
	b:receive("a", packet("message", 2, "second"))
	b:receive("a", packet("message", 1, "duplicate"))
	equal(#n.calls, 2)
	equal(n.calls[1].payload, "first")
	equal(n.calls[2].payload, "second")
	equal(n.queue[3].envelope.seq, 2)
end)

test("wrong peer, wrong scope, stale and unsent future ACKs cannot advance", function()
	local _, a = network()
	a:send("b", "first"); a:send("b", "second")
	equal(a:receive("c", packet("ack", 1)), false)
	equal(a:receive("b", packet("ack", 1, nil, "other-run")), false)
	equal(a:receive("b", packet("ack", 2)), false)
	equal(a:receive("b", packet("ack", 0)), false)
	equal(a:receive("b", packet("ack", 1)), true)
	equal(a:receive("b", packet("ack", 1)), false)
	equal(a:is_pending("b", 2), true)
end)

test("authenticated senders have separate receive cursors", function()
	local n, _, b = network()
	b:receive("a", packet("message", 1, "a"))
	b:receive("c", packet("message", 1, "c"))
	b:receive("a", packet("message", 1, "duplicate"))
	equal(#n.calls, 2)
end)

test("transient refusal retries; handler errors block uncertain effects", function()
	local n, a = network()
	local ready, calls = false, 0
	n:add("b", { on_message = function()
		calls = calls + 1
		return ready
	end })
	a:send("b", "event"); n:flush()
	equal(calls, 1)
	ready = true; a:update(2); n:flush()
	equal(calls, 2)
	n:add("b", { on_message = function() calls = calls + 1; error("partial failure") end })
	local p = packet("message", 1, "event")
	equal(pcall(function() n.peers.b:receive("a", p) end), false)
	equal(n.peers.b:receive("a", p), false)
	equal(calls, 3) -- Do not automatically repeat a possibly-partially-applied effect.
end)

test("response application must accept before the next event can send", function()
	local ready = false
	local n, a = network({ on_ack = function() return ready end })
	a:send("b", "first"); a:send("b", "second")
	n:flush()
	equal(a:head("b"), 1)
	equal(#n.calls, 1)
	ready = true; a:update(2); n:flush()
	equal(#n.calls, 2)
	equal(a:head("b"), nil)
end)

test("response-handler errors stall rather than partially applying twice", function()
	local calls = 0
	local n, a = network({ on_ack = function() calls = calls + 1; error("apply failed") end })
	a:send("b", "event")
	n:deliver()
	equal(pcall(function() n:deliver() end), false)
	equal(a:is_stalled("b"), true)
	equal(a:resume("b"), false)
	a:receive("b", packet("ack", 1))
	equal(calls, 1)
end)

test("timeout warns once, retains the head and blocks later events", function()
	local n, a = network()
	a:send("b", "first"); a:send("b", "second")
	n.queue = {}; a:update(30); a:update(60)
	equal(#n.timeouts, 1)
	equal(n.timeouts[1].seq, 1)
	equal(n.timeouts[1].payload, "first")
	equal(a:is_pending("b", 1), true)
	equal(a:is_pending("b", 2), true)
	equal(a:is_stalled("b"), true)
	equal(#n.queue, 0)
	a:resume("b"); n:flush()
	equal(#n.calls, 2)
	equal(a:is_stalled("b"), false)
end)

test("late valid ACK can unstall delivery without a fresh event identity", function()
	local n, a = network()
	a:send("b", "first"); a:send("b", "second")
	n:deliver() -- ACK is in flight.
	a:update(30)
	equal(a:is_stalled("b"), true)
	n:flush()
	equal(#n.calls, 2)
	equal(a:is_pending("b", 2), false)
end)

test("queued time does not consume the next event's deadline", function()
	local n, a = network()
	a:send("b", "first"); a:send("b", "second")
	a:update(29)
	n:deliver(); n:deliver(2) -- ACK first (past a queued retry); second now begins.
	a:update(1)
	equal(#n.timeouts, 0)
end)

test("pause stops sending and deadline accounting until resume", function()
	local n, a = network()
	a:pause("b"); a:send("b", "event")
	a:update(100)
	equal(#n.queue, 0)
	equal(#n.timeouts, 0)
	a:resume("b"); n:flush()
	equal(#n.calls, 1)
end)

test("reconcile an idle channel replays its last confirmed identity", function()
	local n, a = network()
	a:send("b", "event"); n:flush()
	a:resume("b", true)
	equal(n.queue[1].envelope.seq, 1)
	n:flush()
	equal(#n.calls, 1)
	equal(a:send("b", "next"), 2)
	n:flush()
end)

test("retarget requires explicit resume and rejects old-peer ACKs", function()
	local n, a = network()
	a:send("b", "event")
	n.queue = {}
	equal(a:retarget("b", "c"), true)
	a:update(10); equal(#n.queue, 0)
	equal(a:receive("b", packet("ack", 1)), false)
	a:resume("c"); n:flush()
	equal(n.calls[1].to, "c")
	equal(a:is_pending("c", 1), false)
end)

test("pending capacity refuses without allocating a sequence gap", function()
	local n, a = network({ max_pending = 1 })
	a:send("b", "first")
	local seq, reason = a:send("b", "second")
	equal(seq, nil); equal(reason, "full")
	n:flush()
	equal(a:send("b", "second"), 2)
	n:flush()
end)

test("peer limits bound both transmit channels and receive cursors", function()
	local _, a = network({ max_peers = 1 })
	a:send("b", "event")
	local seq, reason = a:send("c", "event")
	equal(seq, nil); equal(reason, "peers-full")
	equal(a:receive("b", packet("message", 1)), true)
	equal(a:receive("c", packet("message", 1)), false)
end)

test("malformed payloads fail before allocating a sequence", function()
	local _, a = network()
	local cyclic = {}; cyclic.self = cyclic
	for _, invalid in ipairs({ cyclic, { value = math.huge }, { [2] = "hole" }, { a = 1, [1] = 2 }, function() end }) do
		equal(pcall(function() a:send("b", invalid) end), false)
	end
	equal(a:send("b", "valid"), 1)
end)

test("malformed envelopes never apply effects", function()
	local n, _, b = network()
	for _, seq in ipairs({ -1, 0, 0.5, math.huge, 0 / 0, "1", 9007199254740992 }) do
		equal(b:receive("a", packet("message", seq)), false)
	end
	equal(b:receive("a", nil), false)
	equal(b:receive("a", packet("message", 1, nil, "old-run")), false)
	equal(b:receive("*", packet("message", 1)), false)
	equal(b:receive("a", packet("unknown", 1)), false)
	equal(#n.calls, 0)
end)

test("synchronous loopback drains a full FIFO without recursive stack growth", function()
	local peers, effects = {}, 0
	for _, peer in ipairs({ "a", "b" }) do
		peers[peer] = RM.new({
			scope = "sync",
			transmit = function(to, envelope) peers[to]:receive(peer, envelope) end,
			on_message = function(_, payload) effects = effects + 1; equal(payload, effects); return true end,
			on_timeout = function() error("unexpected timeout") end,
		})
	end
	peers.a:pause("b")
	for i = 1, 128 do peers.a:send("b", i) end
	peers.a:resume("b")
	equal(effects, 128)
	equal(peers.a:head("b"), nil)
end)

test("reentrant duplicate cannot prematurely ACK a handler", function()
	local n = network()
	local b, calls = nil, 0
	local p = packet("message", 1, "event")
	b = n:add("b", { on_message = function()
		calls = calls + 1
		equal(b:receive("a", p), false)
		equal(#n.queue, 0)
		return true
	end })
	b:receive("a", p)
	equal(calls, 1)
	equal(#n.queue, 1)
end)

test("close and callback-driven close cancel pending work safely", function()
	local n, a, b = network()
	a:send("b", "event"); a:close(); a:update(100)
	equal(a:receive("b", packet("ack", 1)), false)
	equal(a:send("b", "new"), nil)
	b:close(); n:flush()
	equal(#n.calls, 0)
	equal(#n.timeouts, 0)
	local other
	other = n:add("a", { on_timeout = function() other:close() end })
	other:send("b", "event"); other:update(30)
	equal(other:head("b"), nil)
end)

test("long frames do not burst retries; invalid clocks and configuration fail", function()
	local n, a = network()
	a:send("b", "event"); n.queue = {}; a:update(20); a:update(0)
	equal(#n.queue, 1)
	for _, dt in ipairs({ -1, math.huge, 0 / 0 }) do equal(pcall(function() a:update(dt) end), false) end
	local config = { scope = "s", transmit = function() end, on_message = function() end, on_timeout = function() end }
	for _, change in ipairs({ { scope = "" }, { timeout = 0 }, { max_peers = -1 }, { on_ack = true }, { snapshot = true } }) do
		local options = {}; for k, v in pairs(config) do options[k] = v end
		for k, v in pairs(change) do options[k] = v end
		equal(pcall(RM.new, options), false)
	end
end)

test("checkpointed outgoing channels retain frozen queues and resume explicitly", function()
	local n, a = network()
	a:pause("b"); a:send("b", { value = 1 }); a:send("b", { value = 2 })
	local saved = a:export_channels()
	local restored = n:add("c")
	restored:restore_channels(saved)
	saved.b.queue[1].payload.value = 99
	local exported = restored:export_channels(); exported.b.queue[1].payload.value = 88
	restored:update(100); equal(#n.queue, 0)
	restored:resume("b"); equal(n.queue[1].envelope.payload.value, 1)
	n:flush(); equal(restored:head("b"), nil)
	equal(restored:send("b", { value = 3 }), 3)
end)

test("restored receiver cursors suppress duplicates and retain a frozen response", function()
	local n, _, b = network()
	b:receive("a", packet("message", 1, "effect")); n.queue = {}
	local saved = b:export_received()
	local restored = n:add("c"); restored:restore_received(saved)
	saved.a.response.accepted = 99
	restored:receive("a", packet("message", 1, "duplicate"))
	equal(#n.calls, 1); equal(n.queue[1].envelope.response.accepted, 1)
	restored:receive("a", packet("message", 2, "next")); equal(#n.calls, 2)
end)

test("invalid checkpoint queues reject atomically including holes and capacity", function()
	local invalid = {
		{ b = { next_seq = 3, queue = { { seq = 1 }, { seq = 1 } } } },
		{ b = { next_seq = 3, queue = { { seq = 1 } } } },
		{ b = { next_seq = 3, queue = { [2] = { seq = 2 } } } },
		{ b = { next_seq = 2, queue = { { seq = 1 } } }, c = { next_seq = 2, queue = { { seq = 1 } } } },
	}
	for _, saved in ipairs(invalid) do
		local _, a = network({ max_pending = 1 })
		equal(pcall(function() a:restore_channels(saved) end), false)
		equal(a:head("b"), nil); equal(a:send("b", "valid"), 1)
	end
	local _, a = network({ max_peers = 1 })
	equal(pcall(function() a:restore_received({ b = { seq = 1 }, c = { seq = 2 } }) end), false)
	equal(next(a:export_received()), nil)
	equal(pcall(function() a:restore_received({ b = { seq = -1 } }) end), false)
	a:restore_received({ b = { seq = 1 } })
	equal(pcall(function() a:restore_received({}) end), false)
end)

print(("all %d reliable_messages tests passed"):format(passed))
