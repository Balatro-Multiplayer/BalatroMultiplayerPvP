-- The shared rules of one PvP round, saved in G.GAME.pvp_shared_rules:
--
--   { id, ante, rules = { key, key }, phase, disabled = { [key] = true }, retired = { [id] = true } }
--
--   resolve          activate          finish
--   -------> RESOLVED -------> ACTIVE -------> FINISHED
--               |                                 ^
--               +---------------------------------+
--
-- A round is replaced when the next one resolves; its id joins `retired`.
-- Round.starting and Round.deferred belong to this session and are not saved:
-- after a reload the server sends the start again and it has to be taken.
local R = PVP.SHARED_RULES
local Round = {
	Phase = { RESOLVED = "resolved", ACTIVE = "active", FINISHED = "finished" },
	-- Id of the round whose start this session has handed to the round sync.
	starting = nil,
	-- { from, params }: a start that arrived before this client could take it.
	deferred = nil,
}
R.Round = Round
local Phase = Round.Phase

function Round.current()
	return G.GAME and G.GAME.pvp_shared_rules
end

-- A stale id can no longer be offered or started.
function Round.stale(id)
	local round = Round.current()
	if Round.starting == id then return true end
	if not round then return false end
	return round.retired[id] == true or (round.id == id and round.phase ~= Phase.RESOLVED)
end

function Round.can_start(result)
	return G.STATE == G.STATES.BLIND_SELECT
		and G.blind_select ~= nil
		and G.GAME.round_resets.ante == result.ante
		and (not MPAPI.playback._queues_empty or MPAPI.playback._queues_empty())
end

local function valid(result)
	if type(result) ~= "table" or type(result.id) ~= "string" or type(result.rules) ~= "table" then return false end
	if type(result.ante) ~= "number" or result.ante < 3 or #result.rules ~= 2 then return false end
	if result.rules[1] == result.rules[2] then return false end
	for _, key in ipairs(result.rules) do
		local rule = R.definitions[key]
		if not rule or rule.ante > result.ante then return false end
	end
	return true
end

-- Records the server's result as the current round. False when the result is
-- malformed, for another ante, stale, or would replace an active round.
-- Resolving the current RESOLVED round again is accepted and changes nothing.
function Round.resolve(result)
	if not valid(result) then return false end
	local ante = G.GAME.round_resets and G.GAME.round_resets.ante
	if ante and result.ante ~= ante then return false end
	local round = Round.current()
	if round then
		if round.retired[result.id] then return false end
		if round.id == result.id then return round.phase == Phase.RESOLVED end
		if round.phase == Phase.ACTIVE then return false end
	end
	local retired = round and round.retired or {}
	if round then retired[round.id] = true end
	G.GAME.pvp_shared_rules = {
		id = result.id,
		ante = result.ante,
		rules = copy_table(result.rules),
		phase = Phase.RESOLVED,
		disabled = {},
		retired = retired,
	}
	return true
end

-- What to do with a pvp_start_blind that carries shared rules:
--   "drop"   malformed, stale, or for an ante this client has passed
--   "wait"   the client is not at blind select for that ante yet; Round.defer it
--   "start"  the round is now RESOLVED; begin the round sync
function Round.admit(result)
	if type(result) ~= "table" or type(result.ante) ~= "number" then return "drop" end
	if Round.stale(result.id) or G.GAME.round_resets.ante > result.ante then return "drop" end
	if not Round.can_start(result) then return "wait" end
	return Round.resolve(result) and "start" or "drop"
end

-- Keeps the whole start envelope (round id, starting hands) for Round.redeliver.
function Round.defer(from, params)
	Round.deferred = { from = from, params = copy_table(params) }
	R.offer = nil
end

-- Per frame: hands a deferred start back to its handler once it can be taken.
function Round.redeliver()
	local deferred = Round.deferred
	if not deferred then return end
	if not R.enabled(MPAPI.get_current_lobby()) then
		Round.deferred = nil
	elseif Round.can_start(deferred.params.shared_rules) then
		Round.deferred = nil
		MPAPI.ActionTypes.pvp_start_blind.on_receive(nil, deferred.from, deferred.params)
	end
end

-- The round sync took this start. Repeats of it and late offers are now stale.
function Round.start(result)
	Round.starting = result.id
	R.offer = nil
end

function Round.activate()
	local round = Round.current()
	if not round or round.phase ~= Phase.RESOLVED then return end
	round.phase = Phase.ACTIVE
	for rule in R.in_force("set_blind") do
		rule:set_blind()
	end
	R.refresh_debuffs()
end

-- Stops one rule for the rest of the round; the other stays in force.
function Round.disable_rule(key)
	if not R.has(key) then return end
	local rule = R.definitions[key]
	if rule.disable then rule:disable() end
	Round.current().disabled[key] = true
	R.refresh_debuffs()
end

function Round.finish()
	local round = Round.current()
	if not round or round.phase == Phase.FINISHED then return end
	for rule in R.in_force("disable") do
		rule:disable()
	end
	round.phase = Phase.FINISHED
	R.refresh_debuffs()
end

-- Leaving the run: finish the round and forget this session's negotiation.
function Round.reset()
	Round.finish()
	Round.starting, Round.deferred, R.offer = nil, nil, nil
end
