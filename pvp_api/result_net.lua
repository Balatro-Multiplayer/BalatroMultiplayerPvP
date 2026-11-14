-- The match result and votes over the server's "pvp.result" and "pvp.votes" match state.
--
-- A forfeit and a vote are requests (MPAPI.request); the result and the vote counts
-- come back as state (MPAPI.on_state), never from a request's result. When the result
-- names this player's outcome for the current run, the game-over, match-history and
-- roster-result effects run once per run: the profile keeps `recordedRuns` and the run
-- keeps PVP.GAME.result_handled, so a snapshot that carries the same result again (a
-- rejoin) does nothing. The effects wait until the run is loaded (as lives_net.lua
-- does). lib/result_view.lua decides; this file acts.

local RESULT_KEY = "pvp.result"
local VOTES_KEY = "pvp.votes"

PVP.ResultNet = PVP.ResultNet or {}
local N = PVP.ResultNet

local apply_pending = false
-- The run id of a result that arrived for the current run. GAME_ENDED clears the lobby's
-- started run in the same step as the result, so it is latched here, not read at apply time.
local pending_run = nil

-- The existing local handler that applies each outcome (win and loss record the match,
-- a draw does not; all three report the roster result).
local HANDLER_OF = { win = "winGame", loss = "loseGame", draw = "drawGame" }

local pvp_lobby = PVP.NetBasics.pvp_lobby

function N.forfeit()
	if not pvp_lobby() then return end
	MPAPI.request(
		"pvp.forfeit",
		PVP.ResultView.forfeit_payload(PVP.current_run_id()),
		PVP.NetBasics.refusal_logger("pvp.forfeit")
	)
end

-- args = { runId?, kind = "draw" | "seed", yes }
function N.vote(args)
	if not pvp_lobby() then return end
	local payload = PVP.ResultView.vote_payload(args.runId or PVP.current_run_id(), args.kind, args.yes)
	MPAPI.request("pvp.vote", payload, PVP.NetBasics.refusal_logger("pvp.vote"))
end

-- Applies this player's outcome if it was not applied for the current run yet, once the
-- run is loaded; until then the work stays pending.
function N.apply_result()
	local lobby = pvp_lobby()
	if not lobby or not PVP.RunGate.loaded() then return end
	apply_pending = false
	local game = PVP.GAME
	local shown = PVP.ResultView.to_apply({
		result_value = MPAPI.get_state(RESULT_KEY),
		my_id = lobby.player_id,
		recorded = PVP.config.recordedRuns,
		latched_run = pending_run,
		current_run_id = PVP.current_run_id(),
		game = { result_handled = game.result_handled, contested = game.contested, won = game.won, draw = game.draw },
	})
	pending_run = nil
	if not shown then return end
	-- Marked before the handler runs: a handler that errors must not run twice.
	game.result_handled = true
	PVP.config.recordedRuns = shown.recorded
	PVP.end_pending_death()
	game.team_pending = nil
	PVP.HANDLERS[HANDLER_OF[shown.outcome]]()
	-- recordedRuns is saved by PVP.STATS.record_match (win and loss); a draw records no match, so save here.
	if shown.outcome == "draw" then SMODS.save_mod_config(PVP) end
end

function N.evaluate_result()
	if not pvp_lobby() then return end
	-- Only a result of the current run replaces the latch: a read that finds none (the lobby run is
	-- already cleared by GAME_ENDED) leaves a latched result alone until it is applied or found stale.
	local run = PVP.ResultView.result_run(MPAPI.get_state(RESULT_KEY), PVP.current_run_id())
	if run ~= nil then pending_run = run end
	apply_pending = true
	N.apply_result()
end

-- Reads the votes: keeps the counts the vote UI shows, and prints a chat line when one changed.
function N.evaluate_votes()
	local lobby = pvp_lobby()
	if not lobby then return end
	local run_id = PVP.current_run_id()
	local tally = PVP.ResultView.tally(MPAPI.get_state(VOTES_KEY), lobby.player_id, run_id)
	PVP.GAME.vote_tally = tally
	PVP.show_vote_counts(tally, run_id)
end

-- CONNECTED: reads both states again, the run may have gone live (a crash rejoin's lobby attach)
-- after the last push.
function N.on_connected()
	N.evaluate_result()
	N.evaluate_votes()
end

-- Per frame (pvp_api/frame.lua): applies what the run not being loaded yet left pending.
function N.update()
	if apply_pending then N.apply_result() end
end

if MPAPI.on_state then
	MPAPI.on_state(RESULT_KEY, N.evaluate_result)
	MPAPI.on_state(VOTES_KEY, N.evaluate_votes)
end
