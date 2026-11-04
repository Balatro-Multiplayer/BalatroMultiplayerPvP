-- A server-echo barrier, NOT disk durability. One checkpoint is in flight; later
-- cumulative state and effects wait behind it. Losing authority cancels publication.
PVP.RefereeCheckpoint = {}
local Checkpoint = PVP.RefereeCheckpoint
Checkpoint.__index = Checkpoint

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = copy(item) end
	return out
end
Checkpoint.copy = copy

local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in pairs(a) do if not same(value, b[key]) then return false end end
	for key in pairs(b) do if a[key] == nil then return false end end
	return true
end

function Checkpoint.new(options)
	return setmetatable({
		_scope = assert(options.scope), _writer = assert(options.writer),
		_new_id = assert(options.new_id), _write = assert(options.write),
		_publish = assert(options.publish), _on_timeout = assert(options.on_timeout),
		_retry = options.retry_interval or 2, _timeout = options.timeout or 30,
		_revision = 0, _effects = {},
	}, Checkpoint)
end

function Checkpoint:stage(effect)
	if self._closed then return false end
	self._effects[#self._effects + 1] = copy(effect)
	return true
end

function Checkpoint:_send()
	local pending = self._pending
	if not pending or self._closed or self._paused or self._stalled then return end
	self._retry_in = self._retry
	self._write(copy(pending)) -- Freeze even against local/offline transports.
end

function Checkpoint:_pump()
	if self._closed or self._pending or self._publishing or not self._desired then return end
	local state = self._desired
	self._desired = nil
	if #self._effects == 0 and same(state, self._confirmed) then return end
	self._revision = self._revision + 1
	state._delivery = {
		scope = self._scope, writer = self._writer, id = self._new_id(),
		revision = self._revision, effects = self._effects,
	}
	self._effects = {}
	self._pending, self._elapsed, self._retry_in = state, 0, 0
	self:_send()
end

function Checkpoint:commit(state)
	if self._closed then return false end
	self._desired = copy(state)
	self:_pump()
	return true
end

-- Match the entire submitted value, not just an ID or an arbitrary metadata event.
-- API snapshot/metadata handlers may call this repeatedly and in different orders.
function Checkpoint:receive(value)
	if self._closed or not self._pending or not same(value, self._pending) then return false end
	local committed = self._pending
	self._pending, self._stalled = nil, false
	self._confirmed = copy(committed)
	self._confirmed._delivery = nil
	self._publishing = true
	local ok, err = pcall(self._publish, copy(committed))
	self._publishing = false
	if not ok then
		-- Effects may be partially published. Never blindly replay that callback.
		self._closed = true
		error(err, 0)
	end
	self:_pump()
	return true
end

function Checkpoint:update(dt)
	assert(type(dt) == "number" and dt == dt and dt >= 0 and dt < math.huge, "invalid checkpoint dt")
	if self._closed or self._paused or self._stalled or not self._pending then return end
	self._elapsed, self._retry_in = self._elapsed + dt, self._retry_in - dt
	if self._elapsed >= self._timeout then
		self._stalled = true
		self._on_timeout()
	elseif self._retry_in <= 0 then
		self:_send()
	end
end

function Checkpoint:pause()
	self._paused = true
end
function Checkpoint:resume()
	if self._closed then return false end
	self._paused, self._stalled, self._elapsed = false, false, 0
	self:_send()
	return true
end
function Checkpoint:close()
	self._closed = true
	self._pending, self._desired, self._effects = nil, nil, {}
end
