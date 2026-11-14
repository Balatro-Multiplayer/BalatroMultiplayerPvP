-- Pure rules for the server-owned result and votes.
--
-- The server writes the match outcome once per run into the "pvp.result" match state
-- and the open draw / seed votes into "pvp.votes" (contract: pvp.result, pvp.votes).
-- Every client reads them: it shows win, loss or draw from `result`, and the vote
-- counts from `votes`. No game state, requests or UI here: pvp_api/result_net.lua
-- feeds this module and acts on the answer.

PVP.ResultView = {}
local ResultView = PVP.ResultView

-- How many applied run ids the profile keeps.
ResultView.RECORDED_CAP = 50

local is_table = PVP.StateValue.is_table
local same_run = PVP.StateValue.same_run

-- A result is set once its kind is. The idle value has a nil run and kind.
local function is_set(value)
	return is_table(value) and value.runId ~= nil and (value.kind == "win" or value.kind == "draw")
end

-- The ids in a vote list, as a set.
local function id_set(list)
	local set = {}
	for _, id in ipairs(is_table(list) and list or {}) do
		set[id] = true
	end
	return set
end

-- This player's place in a result, or nil when not in it (a spectator).
local function place_of(value, my_id)
	for _, entry in ipairs(is_table(value.places) and value.places or {}) do
		if entry.playerId == my_id then return tonumber(entry.place) end
	end
	return nil
end

-- What to show a player: { run_id, outcome = "win" | "loss" | "draw", place }, or nil
-- while no result is set or when `my_id` is not in the match. Only a tie for first in a
-- draw result is a draw; otherwise place 1 is a win (all members of a winning team
-- share it) and any other place is a loss.
function ResultView.outcome(value, my_id)
	if not is_set(value) then return nil end
	local place = place_of(value, my_id)
	if place == nil then return nil end
	local outcome = "loss"
	if place == 1 then outcome = value.kind == "draw" and "draw" or "win" end
	return { run_id = tostring(value.runId), outcome = outcome, place = place }
end

-- Whether `run_id` is in the saved list of applied runs.
function ResultView.is_recorded(recorded, run_id)
	for _, id in ipairs(is_table(recorded) and recorded or {}) do
		if id == run_id then return true end
	end
	return false
end

-- The applied-run list with `run_id` added last, only the newest RECORDED_CAP kept.
function ResultView.remember(recorded, run_id)
	local list = {}
	for _, id in ipairs(is_table(recorded) and recorded or {}) do
		if id ~= run_id then list[#list + 1] = id end
	end
	list[#list + 1] = run_id
	while #list > ResultView.RECORDED_CAP do
		table.remove(list, 1)
	end
	return list
end

-- Records the end of run `run_id` once: the applied-run list to save with it added, or nil when
-- the run is already in the list (its end was shown, so nothing more happens). Both ways a run
-- ends for this client, the result and "you are out", ask this before they show anything.
function ResultView.record_once(recorded, run_id)
	if ResultView.is_recorded(recorded, run_id) then return nil end
	return ResultView.remember(recorded, run_id)
end

-- The run id (a string) of a set result when it is the current run's, else nil.
function ResultView.result_run(value, current_run_id)
	if not is_set(value) or not same_run(value, current_run_id) then return nil end
	return tostring(value.runId)
end

-- Once-only effects: given the state value, this player, the list of run ids already
-- applied (profile `recordedRuns`) and the run the result must be of, returns the
-- outcome to apply now or nil, with `recorded`: the applied-run list to save (record_once).
-- A result of another run, a repeat of the same result in a later snapshot, or one for a
-- run already applied does nothing.
function ResultView.pending_outcome(value, my_id, recorded, run_id)
	local shown = ResultView.outcome(value, my_id)
	if shown == nil or run_id == nil or shown.run_id ~= tostring(run_id) then return nil end
	shown.recorded = ResultView.record_once(recorded, shown.run_id)
	if shown.recorded == nil then return nil end
	return shown
end

-- Whether to show this client's result now, and what to record with it: the pending outcome
-- (`recorded` as in pending_outcome), or nil. Input:
--   result_value:   the "pvp.result" state value
--   my_id:          this player's id
--   recorded:       the profile's applied-run list
--   latched_run:    the run the result arrived for (the lobby clears its run with the result)
--   current_run_id: the run the lobby says is current; nil is the normal ending, because the lobby
--                   clears its run in the same step as the result (GAME_ENDED), so `latched_run` decides
--   game:           { result_handled, contested, won, draw } of this run
-- A latch from an earlier run is stale. A run already decided here, or a contested match (a
-- moderator decides), has nothing to apply.
function ResultView.to_apply(input)
	if input.current_run_id ~= nil and input.latched_run ~= input.current_run_id then return nil end
	local game = input.game
	if game.result_handled or game.contested or game.won or game.draw then return nil end
	return ResultView.pending_outcome(input.result_value, input.my_id, input.recorded, input.latched_run)
end

-- The vote counts for the current run: { draw = n, seed = n, i_draw, i_seed }. Votes
-- of another run than `run_id` are stale and count as none.
function ResultView.tally(votes, my_id, run_id)
	local live = is_table(votes) and votes.runId ~= nil and (run_id == nil or same_run(votes, run_id))
	local draw = live and id_set(votes.draw) or {}
	local seed = live and id_set(votes.seed) or {}
	local function count(set)
		local n = 0
		for _ in pairs(set) do
			n = n + 1
		end
		return n
	end
	return { draw = count(draw), seed = count(seed), i_draw = draw[my_id] == true, i_seed = seed[my_id] == true }
end

-- The vote request payload. `kind` is "draw" or "seed"; `yes` is a boolean.
function ResultView.vote_payload(run_id, kind, yes)
	return { runId = run_id ~= nil and tostring(run_id) or nil, kind = kind, yes = yes == true }
end

function ResultView.forfeit_payload(run_id)
	return { runId = run_id ~= nil and tostring(run_id) or nil }
end
