-- Shared, game-independent lifecycle. Definitions contain no per-run state;
-- instances and RNG/clock state are plain saveable data. Game hooks live in
-- overrides/chaos_clock.lua, not in the director.
PVP.CHAOS = { effects = {}, handlers = {} }
local C = PVP.CHAOS

function C.define(def)
	assert(type(def.key) == "string" and not C.effects[def.key], "Duplicate/invalid Chaos effect")
	assert(def.duration == "instant" or type(def.duration) == "table", "Missing Chaos duration")
	if type(def.duration) == "table" then
		assert(type(def.duration.boundary) == "string", "Missing Chaos expiry boundary")
		local count = def.duration.count
		assert(
			type(count) == "number" and count > 0 and count < math.huge and count % 1 == 0,
			"Chaos duration must count positive whole boundaries"
		)
	end
	assert(def.pending or def.payload or def.events, "Missing Chaos payload")
	def.claims = def.claims or {}
	C.effects[def.key] = def
end

function C.new_state(seed)
	local rng = 1
	for i = 1, #tostring(seed) do
		rng = (rng * 31 + tostring(seed):byte(i)) % 2147483647
	end
	return {
		version = 1,
		next_id = 1,
		active = {},
		boundaries = {},
		rng = math.max(1, rng),
		scheduler = { enabled = false, interval = 30, remaining = 30 },
	}
end

function C.runtime(state, adapter)
	assert(state.version == 1, "Unsupported Chaos save version")
	local runtime = { state = state }

	function runtime:eligible(key)
		local def = C.effects[key]
		if not def then return false, "Unknown effect" end
		if def.pending then return false, def.pending end
		local ok, reason = adapter.allowed(def)
		if not ok then return false, reason end
		for _, instance in ipairs(state.active) do
			local active = assert(C.effects[instance.key], "Unknown saved Chaos effect")
			if instance.key == key then return false, "Already active" end
			for _, claim in ipairs(def.claims) do
				for _, owned in ipairs(active.claims) do
					if claim == owned then return false, "Conflicts with " .. active.label end
				end
			end
		end
		return true
	end

	function runtime:candidates()
		local keys = {}
		for key in pairs(C.effects) do
			if self:eligible(key) then keys[#keys + 1] = key end
		end
		table.sort(keys)
		return keys
	end

	function runtime:activate(key)
		local ok, reason = self:eligible(key)
		if not ok then return nil, reason end
		local def = C.effects[key]
		local instance = { id = state.next_id, key = key, fired = {} }
		if def.duration ~= "instant" then instance.remaining = def.duration.count end
		-- Loading a save must NOT apply this receipt a second time.
		instance.receipt = adapter.apply(def.payload or {}, instance)
		state.next_id = state.next_id + 1
		if def.duration ~= "instant" then state.active[#state.active + 1] = instance end
		state.last = "Activated " .. def.label
		return instance
	end

	function runtime:random()
		local keys = self:candidates()
		if #keys == 0 then return nil, "No eligible effects here" end
		-- Dedicated saved stream: never consumes or depends on gameplay RNG.
		state.rng = (state.rng * 16807) % 2147483647
		return self:activate(keys[(state.rng % #keys) + 1])
	end

	function runtime:expire(id)
		for i, instance in ipairs(state.active) do
			if instance.id == id then
				adapter.remove(instance.receipt)
				table.remove(state.active, i)
				state.last = "Expired " .. C.effects[instance.key].label
				return true
			end
		end
		return false
	end

	function runtime:clear()
		for i = #state.active, 1, -1 do
			self:expire(state.active[i].id)
		end
	end

	function runtime:event(name, context)
		for _, instance in ipairs(state.active) do
			local event = (C.effects[instance.key].events or {})[name]
			if event and not (event.once and instance.fired[name]) then
				-- Consume before dispatch; a handler may itself emit contexts.
				instance.fired[name] = true
				assert(C.handlers[event.handler], "Unknown Chaos handler")(adapter, instance, context)
			end
		end
	end

	function runtime:boundary(name, token)
		if token ~= nil then
			if state.boundaries[name] == token then return end
			state.boundaries[name] = token
		end
		for i = #state.active, 1, -1 do
			local instance = state.active[i]
			if C.effects[instance.key].duration.boundary == name then
				instance.remaining = instance.remaining - 1
				if instance.remaining <= 0 then self:expire(instance.id) end
			end
		end
	end

	-- Explicit ticks only: no wall-clock hook or catch-up burst. Due events wait
	-- for a safe eligible point instead of being silently lost.
	function runtime:advance(dt, paused)
		assert(type(dt) == "number" and dt >= 0 and dt < math.huge, "Invalid Chaos tick")
		local clock = state.scheduler
		if paused or not clock.enabled then return end
		clock.remaining = math.max(0, clock.remaining - dt)
		if clock.remaining > 0 then return end
		local instance, reason = self:random()
		if instance then clock.remaining = clock.interval end
		return instance, reason
	end

	return runtime
end
