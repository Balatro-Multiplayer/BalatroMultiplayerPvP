-- Pure view of the server's "pvp.lives" match state (contract: pvp.lives).
--
-- Every client reads each player's lives from that state. The HUD, card info, lobby and
-- Contest readers keep reading `PVP._player_lives_cache`, a plain table of lives by player id;
-- this module builds it. The once-only effects on this player's own lives are decided in
-- lib/applied_effects.lua. pvp_api/lives_net.lua feeds both and acts on the answers.

PVP.LivesView = {}
local LivesView = PVP.LivesView

local is_table = PVP.StateValue.is_table
local same_run = PVP.StateValue.same_run
local unmatched_run = PVP.StateValue.unmatched_run

-- Lives by player id from the state value, or nil when there is nothing to show: no value, or
-- a value of another run than the lobby's current one (`current_run_id` may be nil).
function LivesView.cache(value, current_run_id)
	if not is_table(value) or not is_table(value.players) then return nil end
	if unmatched_run(value, current_run_id) then return nil end
	local lives = {}
	for id, player in pairs(value.players) do
		local n = is_table(player) and tonumber(player.lives) or nil
		if n ~= nil then lives[id] = n end
	end
	return lives
end

-- The lives total to put in PVP.GAME.lives for `my_id`: the server's number from `cache` (the
-- table `LivesView.cache` built), or nil when there is none. Only a state of the lobby's current
-- run says so: a stale cache must not overwrite a fresh run.
function LivesView.total_to_show(value, cache, run_id, my_id)
	local mine = cache and cache[my_id]
	if mine ~= nil and run_id ~= nil and same_run(value, run_id) then return mine end
	return nil
end

-- How many players the run started with ("pvp.rules".startedCount), or nil when the value is
-- missing, idle or of another run than `run_id`.
function LivesView.started_count(rules_value, run_id)
	if not same_run(rules_value, run_id) then return nil end
	return tonumber(rules_value.startedCount)
end

-- Whether I still have an entry in "pvp.lives".pending. It lists only deaths that still wait,
-- so no entry plus no lives left means the death is final.
local function waits_pending(lives_value, my_id)
	for _, entry in ipairs(is_table(lives_value.pending) and lives_value.pending or {}) do
		if is_table(entry) and entry.playerId == my_id then return true end
	end
	return false
end

-- Whether to tell this client it is out of a match that goes on without it (R31). Only a game
-- that started with 3 or more players: a duel keeps its own end flow. A pending death still
-- waits, and a run already latched (`latched_run`) is not told twice.
--   lives_value / rules_value: the "pvp.lives" and "pvp.rules" state values of run `run_id`
--   result_over: a "pvp.result" of this run is set, or this client already handled its end. The
--   server clears my pending entry and writes the result in one push, so the result (a loss, or a
--   draw or win) decides what I see, not this.
function LivesView.should_eliminate(lives_value, rules_value, run_id, my_id, latched_run, result_over)
	if run_id == nil or my_id == nil or result_over then return false end
	if latched_run ~= nil and tostring(latched_run) == tostring(run_id) then return false end
	local started = LivesView.started_count(rules_value, run_id)
	if started == nil or started <= 2 then return false end
	if not same_run(lives_value, run_id) then return false end
	local mine = is_table(lives_value.players) and lives_value.players[my_id] or nil
	if not is_table(mine) then return false end
	local out = mine.eliminated == true or (tonumber(mine.lives) ~= nil and tonumber(mine.lives) <= 0)
	return out and not waits_pending(lives_value, my_id)
end
