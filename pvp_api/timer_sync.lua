-- Critical timer transitions, not clock ticks. The referee checkpoints each
-- accepted state with the reliable cursors/outbox. Live processes only.
PVP.TimerSync = {}
local T = PVP.TimerSync

local function lobby()
	local l = MPAPI.get_current_lobby()
	return l and l.mod_id == PVP.id and l or nil
end
local function finite(n)
	return type(n) == "number" and n == n and n >= 0 and n < math.huge
end
local function integer(n)
	return finite(n) and n % 1 == 0 and n <= 9007199254740991
end
local function client(l)
	local run = l._game and l._game.started and l._game.started.run_id
	if not run then return end
	local s = l._pvp_timer_sync
	if not s or s.run ~= run then
		s = { run = run, states = {}, negotiated = {}, generations = {}, applied = {}, pending_states = {} }
		l._pvp_timer_sync = s
	end
	return s
end
local function snapshot(l)
	local s = (l:get_metadata() or {})[PVP.REF_CHECKPOINT_KEY]
	local run = l._game and l._game.started and l._game.started.run_id
	return s and s.tag == tostring(run) and s or nil
end
local function capable(s, a, b, l)
	if not (s and s.timer_protocol == 1 and s.players and s.players[a] and s.players[b]
		and s.players[a].timer_protocol == 1 and s.players[b].timer_protocol == 1) then return false end
	-- Any connected participant can become referee. Do not negotiate a schema
	-- that a legacy participant could not restore after host migration.
	for _, player in ipairs(l:get_players()) do
		if not s.players[player.id] or s.players[player.id].timer_protocol ~= 1 then return false end
	end
	return true
end
-- A negotiated run cannot silently downgrade. Retain the critical FIFO until
-- every potential referee supports it again; never send unknown keys to an old host.
function T.transport_supported(l)
	local snap = snapshot(l)
	if not snap or snap.timer_protocol ~= 1 or not snap._delivery
		or snap._delivery.writer ~= (l.host_id or l.player_id) then return false end
	for _, player in ipairs(l:get_players()) do
		if not snap.players or not snap.players[player.id] or snap.players[player.id].timer_protocol ~= 1 then return false end
	end
	return true
end
function T.referee_supported()
	local l = lobby()
	if not l then return false end
	for _, player in ipairs(l:get_players()) do
		local pl = PVP.REF.players[player.id]
		if not pl or pl.timer_protocol ~= 1 then return false end
	end
	return true
end
local function generation(s, snap, id)
	return math.max(s.generations[id] or 0,
		snap and snap.players and snap.players[id] and snap.players[id].timer_generation or 0)
end

-- Boundary outputs carry their generation, since delivery of the confirming
-- metadata echo to another client can lag behind delivery of the output itself.
function T.decorate(key, params)
	if key ~= "pvp_start_blind" and key ~= "pvp_end_pvp" and key ~= "pvp_round_state"
		and key ~= "pvp_timer_hand_lost" then return params end
	local out = {}; for k, v in pairs(params or {}) do out[k] = v end
	out.timer_generations = {}
	for id, pl in pairs(PVP.REF.players) do out.timer_generations[id] = pl.timer_generation or 0 end
	return out
end
function T.note_generations(params)
	local l = lobby(); local s = l and client(l)
	if not s or type(params) ~= "table" or type(params.timer_generations) ~= "table" then return end
	for id, value in pairs(params.timer_generations) do
		if type(id) == "string" and integer(value) then
			s.generations[id] = math.max(s.generations[id] or 0, value)
			local state = s.states[id]
			if state and state.generation < value then
				local other = l.player_id == state.target and state.starter or state.target
				if other == PVP.current_target_id() then
					PVP.GAME[l.player_id == state.target and "nemesis_timer_started" or "timer_started"] = false
				end
			end
		end
	end
end
local function same_phase(a, b)
	return a and b and a.round == b.round and a.target_hands == b.target_hands
		and a.starter_hands == b.starter_hands and a.target_score == b.target_score
		and a.starter_score == b.starter_score
end
local function same_target_phase(a, b)
	return a and b and a.round == b.round and a.target_hands == b.target_hands and a.target_score == b.target_score
end
local function live_phase(l, target, starter)
	local round, enemy = PVP.GAME.round_sync, PVP.GAME.enemy
	if not round or not enemy then return end
	local me = l.player_id
	local mine, theirs = PVP.Score.or_zero(PVP.GAME.score), PVP.Score.or_zero(enemy.real_score or enemy.score)
	local hands = G.GAME.current_round.hands_left
	return { round = round.id, target_score = target == me and mine or theirs,
		starter_score = starter == me and mine or theirs, target_hands = target == me and hands or enemy.hands,
		starter_hands = starter == me and hands or enemy.hands }
end
local function referee_phase(target, starter)
	local r, players = PVP.REF.round, PVP.REF.players
	if not r or r.outcome then return end
	return { round = r.id, target_score = PVP.Score.or_zero(players[target].score),
		starter_score = PVP.Score.or_zero(players[starter].score),
		target_hands = players[target].hands_left, starter_hands = players[starter].hands_left }
end
local function snapshot_phase(s, target, starter)
	if not s or not s.round or s.round.outcome or not s.players
		or not s.players[target] or not s.players[starter] then return end
	return { round = s.round.id, target_score = s.players[target].score,
		starter_score = s.players[starter].score,
		target_hands = s.players[target].hands, starter_hands = s.players[starter].hands }
end
local function publish(state)
	PVP.referee_send("pvp_timer_state", state.starter, state)
	if state.target ~= state.starter then PVP.referee_send("pvp_timer_state", state.target, state) end
end

-- Called inside the reliable input transaction, after membership validation.
function T.hello(from, params)
	local pl = PVP.REF.players[from]
	if pl then pl.timer_protocol = params.timer_protocol == 1 and 1 or nil end
end

function T.on_event(from, p)
	local l = lobby()
	if not l or not l.is_host then return end
	local target, starter = PVP.REF.players[p.target], PVP.REF.players[p.starter]
	if not target or not starter or target.lives <= 0 or starter.lives <= 0
		or target.timer_protocol ~= 1 or starter.timer_protocol ~= 1
		or p.target == p.starter or (from ~= p.target and from ~= p.starter)
		or not finite(p.time) or not integer(p.generation)
		or p.generation ~= (target.timer_generation or 0) then return end
	PVP.REF.timers = PVP.REF.timers or {}
	local state = PVP.REF.timers[p.target]
	if p.isPvP and (p.kind == "start" or (p.kind == "pause" and not state)) then
		if not same_phase(p.phase, referee_phase(p.target, p.starter)) then return end
		if state and not same_phase(state.phase, p.phase) then
			target.timer_generation = (target.timer_generation or 0) + 1
			state = nil
		end
	end
	if (p.kind == "start" or p.kind == "pause") and not state then
		if from ~= p.starter then return end
		state = { id = MPAPI.generate_id(), cycle = 1, revision = 0,
			target = p.target, starter = from, generation = target.timer_generation or 0,
			isPvP = p.isPvP == true, phase = p.phase, time = p.time, running = p.kind == "start" }
		PVP.REF.timers[p.target] = state
	else
		if not state or state.starter ~= p.starter or state.generation ~= p.generation
			or state.isPvP ~= (p.isPvP == true) then return end
		-- Start/Pause intent may precede the first state echo. Only the starter
		-- can omit identity; stale samples still require the exact current cycle.
		local initial = p.kind == "start" and p.id == nil and state.cycle == 1 and state.running
		local owner_intent = (p.kind == "start" or p.kind == "pause") and from == state.starter
		local same_cycle = p.id == state.id and p.cycle == state.cycle
		if not initial and not owner_intent and not same_cycle then return end
		if owner_intent and p.id ~= nil and p.id ~= state.id then return end
		if p.kind == "expire" then
			-- Validate the old cycle BEFORE a life/forgiveness effect. A delayed
			-- expiry after Pause must not cost a life. Loss and restart are one
			-- checkpointed transaction, not competing inputs from two players.
			if from ~= state.target or not state.running then return end
			if state.isPvP then
				-- A hand that stays behind does not stop the existing countdown.
				-- Validate the current reported phase, not the hand it first started on.
				if not same_target_phase(p.phase, referee_phase(p.target, p.starter))
					or PVP.Score.greater(target.score, starter.score)
					or (PVP.Score.equal(target.score, starter.score) and target.first_ready) then return end
				PVP.referee_on_fail_pvp_timer(from)
				return
			end
			if p.time <= 0 then return end
			local allowance = PVP.LOBBY.config.timer_forgiveness or 0
			local claimed = integer(p.forgiven) and math.min(p.forgiven, allowance) or 0
			target.timer_forgiven = math.max(target.timer_forgiven or 0, claimed)
			local forgiven = target.timer_forgiven < allowance
			if forgiven then target.timer_forgiven = target.timer_forgiven + 1 end
			PVP.referee_send("pvp_timer_expired", from, { forgiven = target.timer_forgiven,
				blind_result = not forgiven and p.blind_result or nil })
			if not forgiven then
				if type(p.blind_result) == "table" then PVP.referee_on_blind_result(from, p.blind_result) end
				PVP.referee_on_fail_timer(from)
			end
			if PVP.REF.timers[p.target] ~= state then return end
			if target.lives <= 0 then
				state.running, state.time = false, 0
			else
				state.cycle = state.cycle + 1
				state.time = p.time
			end
		elseif p.kind == "pause" then
			if from ~= state.starter then return end
			-- Stop intent survives an expiry racing the opposite input FIFO, but
			-- an old-cycle remaining-time sample must not shorten the new cycle.
			if same_cycle or (p.id == nil and state.cycle == 1) then state.time = math.min(state.time, p.time) end
			state.running = false
			if state.isPvP then state.phase = referee_phase(p.target, p.starter) end
		elseif p.kind == "start" then
			if from ~= state.starter then return end
			if not state.running then
				-- Resume is explicit, unlike a sync. Skips may have legitimately
				-- added time while paused. Retire old samples before accepting it.
				state.cycle = state.cycle + 1
				if same_cycle then state.time = p.time end
			elseif same_cycle or initial then state.time = math.min(state.time, p.time) end
			state.running = true
		elseif p.kind == "sync" then
			if state.isPvP then
				if not same_phase(p.phase, referee_phase(p.target, p.starter)) then return end
				state.phase = p.phase
			end
			-- A sync never resumes a paused timer or increases time in this cycle.
			state.time = math.min(state.time, p.time)
		else return end
	end
	state.revision = state.revision + 1
	publish(state)
end

-- Starting/ending a PvP round retires the earlier timer identities. Delayed
-- inputs cannot recreate them, even after the local timer flags were cleared.
function T.retire(ids)
	local timers = PVP.REF.timers or {}
	for id in pairs(ids) do
		local pl = PVP.REF.players[id]
		if pl then pl.timer_generation = (pl.timer_generation or 0) + 1 end
	end
	for target, state in pairs(timers) do
		if ids[target] or ids[state.starter] then
			if not ids[target] then
				local pl = PVP.REF.players[target]
				pl.timer_generation = (pl.timer_generation or 0) + 1
			end
			timers[target] = nil
		end
	end
end
function T.sync_referee()
	for _, state in pairs(PVP.REF.timers or {}) do publish(state) end
end

-- Returns false only for legacy/mixed-version pairs or no usable live timer.
-- Once negotiated, missing authority metadata must retain the critical request,
-- never fall back to a one-shot broadcast.
function T.send(kind, time)
	local l = lobby()
	local s = l and client(l)
	if not s or not finite(time) then return false end
	local me, other = l.player_id, PVP.current_target_id()
	if not other then return false end
	local timed = kind == "expire" or (kind == "sync" and PVP.GAME.nemesis_timer_started)
	local target, starter = timed and me or other, timed and other or me
	local state, snap = s.states[target], snapshot(l)
	if not s.negotiated[target] and not capable(snap, target, starter, l) then return false end
	local gen = generation(s, snap, target)
	if state and state.generation < gen then state = nil end
	if kind ~= "start" and kind ~= "pause" and not state then return s.negotiated[target] == true end
	local is_pvp = state and state.isPvP
	if not state then is_pvp = PVP.is_pvp_boss() and PVP.is_layer_active("pvp_timer") end
	local phase = is_pvp and live_phase(l, target, starter) or nil
	if kind == "pause" then s.pending_start = nil end
	if kind == "start" and is_pvp and not same_phase(phase, snapshot_phase(snap, target, starter)) then
		-- A hand report uses another reliable channel. Wait for its accepted
		-- phase rather than racing a timer Start ahead of that report.
		s.pending_start = { target = target, phase = phase }
		return true
	end
	if kind == "expire" and is_pvp and not same_target_phase(phase, snapshot_phase(snap, target, starter)) then
		s.pending_expire = { target = target, phase = phase, id = state.id, cycle = state.cycle, time = time }
		return true
	end
	if kind == "start" then s.pending_start = nil end
	if kind == "expire" then s.pending_expire = nil end
	local p = { kind = kind, time = time, target = target, starter = starter, phase = phase,
		generation = state and state.generation or gen,
		id = state and state.id, cycle = state and state.cycle,
		isPvP = is_pvp == true }
	if kind == "expire" and not is_pvp then
		local game = G.GAME
		local boss_cash_out = game.blind_on_deck == "Boss" and game.round_resets.blind_states
			and game.round_resets.blind_states.Boss == "Defeated"
		p.forgiven = PVP.GAME.timers_forgiven or 0
		p.blind_result = { ante = game.round_resets.ante, blind = boss_cash_out and "Small" or game.blind_on_deck, beaten = false }
	end
	if not PVP.send_referee_event("pvp_timer_transition", p) then return false end
	s.negotiated[target] = true
	return true
end

function T.resync()
	if not (PVP.GAME.timer_started or PVP.GAME.nemesis_timer_started) then return false end
	return T.send("sync", PVP.GAME.timer)
end
function T.ignore_legacy(from)
	local l = lobby()
	local s = l and client(l)
	return s and from == PVP.current_target_id()
		and (s.negotiated[l.player_id] or s.negotiated[from]) or false
end

local function apply_state(l, s, p)
	local other = l.player_id == p.target and p.starter or p.target
	if other ~= PVP.current_target_id() or p.generation < generation(s, snapshot(l), p.target) then return true end
	local from_nemesis = l.player_id == p.target
	local flag = from_nemesis and "nemesis_timer_started" or "timer_started"
	local in_pvp = PVP.GAME.pvp_countdown_in_progress or (PVP.is_pvp_boss() and G.GAME.blind and G.GAME.blind.in_blind)
	if (not p.isPvP and in_pvp) or (p.isPvP and (PVP.GAME.end_pvp or not PVP.is_pvp_boss()
		or G.GAME.current_round.hands_left <= 0)) then return true end
	if p.isPvP then
		local phase = live_phase(l, p.target, p.starter)
		if not same_phase(phase, p.phase) then
			-- A score relay may lag the reliable output: retain one latest state
			-- until the matching hand arrives. Never apply it to a later hand.
			return phase and p.phase and (phase.round ~= p.phase.round
				or phase.target_hands < p.phase.target_hands or phase.starter_hands < p.phase.starter_hands)
		end
		local score = PVP.GAME.enemy.real_score or PVP.GAME.enemy.score
		local leading = PVP.Score.greater(PVP.GAME.score, score)
			or (PVP.Score.equal(PVP.GAME.score, score) and PVP.GAME.pvp_reached_first)
		if p.running and ((from_nemesis and leading) or (not from_nemesis and not leading)) then return true end
	end
	local time = p.running and math.max(0, p.time - math.max(0, love.timer.getTime() - p.received_at)) or p.time
	local previous = s.applied[p.target]
	local new_cycle = not previous or previous.generation ~= p.generation or previous.cycle ~= p.cycle
	local was_running = PVP.GAME[flag] == true
	if not PVP.timer_is_local() then
		if new_cycle then
			PVP.GAME.timer = p.cycle == 1 and was_running and math.min(PVP.GAME.timer, time) or time
			PVP.GAME.timer_consumed = false
		else PVP.GAME.timer = math.min(PVP.GAME.timer, time) end
	elseif new_cycle and p.cycle > 1 then
		PVP.GAME.timer = time
		PVP.GAME.timer_consumed = false
	end
	-- Do not subtract the frozen interval again after applying a fresh sample.
	PVP.TIMER_CLOCK = love.timer.getTime()
	if p.running and not was_running then
		PVP.dispatch_action("startAnteTimer", { time = PVP.GAME.timer, isPvP = p.isPvP, fromNemesis = from_nemesis })
	else PVP.GAME[flag] = p.running end
	s.applied[p.target] = { generation = p.generation, cycle = p.cycle }
	return true
end
function T.receive(p)
	local l = lobby(); local s = l and client(l)
	if not s or type(p) ~= "table" or type(p.id) ~= "string" or #p.id > 128
		or not integer(p.cycle) or p.cycle < 1 or not integer(p.revision) or p.revision < 1
		or not integer(p.generation) or not finite(p.time) or type(p.running) ~= "boolean"
		or (l.player_id ~= p.target and l.player_id ~= p.starter) then return end
	if p.isPvP and (type(p.phase) ~= "table" or type(p.phase.round) ~= "string"
		or not integer(p.phase.target_hands) or not integer(p.phase.starter_hands)
		or type(p.phase.target_score) ~= "string" or type(p.phase.starter_score) ~= "string") then return end
	local other = l.player_id == p.target and p.starter or p.target
	if other ~= PVP.current_target_id() or p.generation < generation(s, snapshot(l), p.target) then return end
	local previous = s.states[p.target]
	if previous and (p.generation < previous.generation
		or (p.generation == previous.generation and (p.id ~= previous.id
			or p.cycle < previous.cycle or p.revision <= previous.revision))) then return end
	local phase = type(p.phase) == "table" and { round = p.phase.round, target_hands = p.phase.target_hands,
		starter_hands = p.phase.starter_hands, target_score = p.phase.target_score, starter_score = p.phase.starter_score } or nil
	local state = { id = p.id, target = p.target, starter = p.starter, generation = p.generation,
		cycle = p.cycle, revision = p.revision, isPvP = p.isPvP == true, phase = phase, running = p.running,
		time = p.time, received_at = love.timer.getTime() }
	s.states[p.target], s.negotiated[p.target] = state, true
	s.pending_states[p.target] = not apply_state(l, s, state) and state or nil
end
function T.receive_expired(p)
	if integer(p.forgiven) then PVP.GAME.timers_forgiven = math.max(PVP.GAME.timers_forgiven or 0, p.forgiven) end
	local result = p.blind_result
	if type(result) == "table" then
		PVP.GAME.own_blind_results = PVP.GAME.own_blind_results or {}
		PVP.PendingDeath.record(PVP.GAME.own_blind_results, PVP.PendingDeath.SELF,
			PVP.PendingDeath.blind_key(result.ante, result.blind), false)
	end
end
function T.update()
	local l = lobby(); local s = l and client(l)
	if not s then return end
	for target, state in pairs(s.pending_states) do
		if apply_state(l, s, state) then s.pending_states[target] = nil end
	end
	local pending = s.pending_start
	if pending then
		if PVP.GAME.end_pvp or not PVP.is_pvp_boss() or pending.target ~= PVP.current_target_id()
			or not same_phase(pending.phase, live_phase(l, pending.target, l.player_id)) then
			s.pending_start = nil
		else T.send("start", PVP.GAME.timer) end
	end
	local expiry = s.pending_expire
	if expiry then
		local state = s.states[expiry.target]
		if PVP.GAME.end_pvp or not PVP.is_pvp_boss() or not state or not state.running
			or state.starter ~= PVP.current_target_id() or state.id ~= expiry.id or state.cycle ~= expiry.cycle
			or not same_target_phase(expiry.phase, live_phase(l, expiry.target, state.starter)) then
			s.pending_expire = nil
		else T.send("expire", expiry.time) end
	end
end
local update = Game.update
function Game:update(...)
	local result = update(self, ...)
	T.update()
	return result
end
