-- Round facts over the server's match.
--
-- A hand played, a hand about to be played (Play pressed), a blind beaten or failed, the ante reached
-- and a voucher redeemed are requests (MPAPI.request): the server decides what they mean.
-- lib/round_facts.lua holds the rules this file acts on.
--
-- This file never writes PVP.GAME.enemy.*. The opponent's score and hands are pvp_api/enemy_score_net.lua's
-- (the server's "pvp.round"); the Teams score is teams_net.lua's. This file reads the match state to know
-- whether its PvP round is open and how many PvP-timer run-outs the server took for this player.

PVP.RoundNet = PVP.RoundNet or {}
local N = PVP.RoundNet

local KEY = "pvp.round"

local function request(kind, args, on_result)
	MPAPI.request(kind, args, on_result or PVP.NetBasics.refusal_logger(kind))
end

-- A hand states how many server timer losses the client had already taken off when it counted
-- (`timerLossesApplied`): the server derives the hands left from it. The record lives in G.GAME.
function N.applied_count(run_id, round_id)
	return PVP.RoundFacts.applied_count(G.GAME and G.GAME.pvp_timer_losses_applied, run_id, round_id)
end

-- The newest hand request whose answer has not come back: { args, timed_out }. A request that ended in
-- `timeout` may have gone into a silent link and never reached the server (the drop is only noticed after
-- the request layer gave up), so it is kept and sent again once the rejoin snapshot is in. One slot, the
-- newest hand: a hand states the cumulative score and hands left, so a hand the server did not get is
-- carried by a newer one. That holds only when no earlier hand_commit is still bound to the older hand;
-- the server clears such a commit when a hand with fewer hands left than the committed count arrives
-- (a server rule, not a client one: this file does not resend older hands). An answer of any kind ends
-- the wait, so a hand the server got is not sent again.
local last_hand = nil
-- A rejoin snapshot came; the next loaded frame sends last_hand again if it is still owed.
local resend_pending = false

function N.hand(args)
	local sent = { args = args }
	last_hand = sent
	local log = PVP.NetBasics.refusal_logger("pvp.hand")
	request("pvp.hand", args, function(ok, result)
		if not ok and type(result) == "table" and result.reason == "timeout" then
			sent.timed_out = true
		elseif last_hand == sent then
			last_hand = nil
		end
		log(ok, result)
	end)
end

-- Sends the kept hand again (once per rejoin), when its round is still the server's open round of this run.
-- The server accepts a repeat as a no-op and refuses a stale one (pvp.hand: the count only goes down and
-- the score only up within a round), so a hand it already holds does no harm.
local function resend_hand()
	local sent = last_hand
	if not sent or not sent.timed_out then return end
	last_hand = nil
	local args = sent.args
	if tostring(args.runId) ~= PVP.current_run_id() then return end
	if not PVP.RoundFacts.hand_counts(MPAPI.get_state(KEY), args.runId, args.roundId) then return end
	N.hand(args)
end

-- A rejoin snapshot (pvp_api/lobby_bridge.lua SNAPSHOT_APPLIED): sets a flag, the frame acts.
function N.on_snapshot()
	resend_pending = true
end

function N.blind(args)
	request("pvp.blind", args)
end

function N.progress(args)
	request("pvp.progress", args)
end

function N.voucher(args)
	request("pvp.voucher", args)
end

-- Play was pressed in the PvP blind: `args.handsLeft` is the hands left once this hand is played. The server
-- checks it against its own count and credits the hand's time before the scoring animation.
function N.hand_commit(args)
	request("pvp.hand_commit", args)
end

-- The player started or stopped animating: the server freezes the clocks it counts while it is true
-- (lib/animating.lua decides when this is sent). Only while a run is open.
function N.animating(animating)
	local run_id = PVP.current_run_id()
	if not run_id then return end
	request("pvp.animating", { runId = run_id, animating = animating })
end

-- Set when a "pvp.round" state or a rejoin wanted the run-outs taken off and the run was not loaded yet.
local timer_losses_pending = false

-- Takes off the hands the server says this round's PvP-timer run-outs cost, once each: the server's
-- `timerLosses` minus what was already taken. Run on every "pvp.round" state and after a crash rejoin
-- (a rejoin brings the run back without these run-outs, so a crash never gives a lost hand back).
-- Only while that round is still open: PVP.GAME.round_id stays set after it ends.
function N.apply_timer_losses()
	local lobby = PVP.NetBasics.pvp_lobby()
	if not lobby then
		timer_losses_pending = false
		return
	end
	-- Only in the live run: during a crash rejoin G.GAME is the catch-up playback, which the attach
	-- replaces, and before the save is loaded it is not the run that is kept. The frame tries again.
	if not PVP.RunGate.loaded() then
		timer_losses_pending = true
		return
	end
	timer_losses_pending = false
	local round = G.GAME and G.GAME.current_round
	if not round or type(round.hands_left) ~= "number" then return end
	local delta, kept = PVP.RoundFacts.timer_losses_to_apply(
		MPAPI.get_state(KEY),
		PVP.current_run_id(),
		PVP.GAME.round_id,
		lobby.player_id,
		G.GAME.pvp_timer_losses_applied
	)
	G.GAME.pvp_timer_losses_applied = kept
	if delta > 0 then round.hands_left = math.max(0, round.hands_left - delta) end
end

-- After a crash rejoin into the open round: the hands and score the server counted replace the client's
-- (a hand logged here whose request was lost is not counted there). A server entry without a usable
-- handsLeft or handsSpent changes nothing and is logged. A player the server has out of hands without
-- spending them (handsLeft 0) runs the hands-spent effect once; one it has spent them for is left to
-- RoundEndNet, which applies that once.
local function apply_resume_counts()
	local lobby = PVP.NetBasics.pvp_lobby()
	local round = G.GAME and G.GAME.current_round
	if not lobby or not round then return end
	local state = MPAPI.get_state(KEY)
	if not PVP.RoundFacts.hand_counts(state, PVP.current_run_id(), PVP.GAME.round_id) then return end
	-- Only inside the PvP blind (at blind select the rejoin has nothing to correct yet).
	if not (PVP.is_pvp_boss() and G.GAME.blind and G.GAME.blind.in_blind) then return end
	local entry = type(state.players) == "table" and state.players[lobby.player_id] or nil
	local plan, reason = PVP.RoundFacts.resume_counts({
		hands_left = round.hands_left,
		score = PVP.Score.from_game_value(G.GAME.chips),
	}, entry)
	if not plan then
		PVP.match_log("debug", "pvp.round resume: counts kept, " .. reason)
		return
	end
	if plan.score then
		local chips, why = PVP.Score.to_game_value(plan.score)
		if chips == nil then
			PVP.match_log("debug", "pvp.round resume: score kept, " .. tostring(why))
		else
			G.GAME.chips = chips
		end
	end
	if plan.run_hands_spent then
		PVP.HANDLERS.handsSpent()
	elseif plan.hands_left ~= nil then
		round.hands_left = plan.hands_left
	end
end

-- Per frame (pvp_api/frame.lua): what the run not being loaded yet left pending.
function N.update()
	if timer_losses_pending then N.apply_timer_losses() end
	if resend_pending and PVP.RunGate.loaded() then
		local sent = last_hand
		-- A hand still waiting for its answer may yet time out after the snapshot (its deadline counts
		-- the time before the drop): keep the flag so the timeout is followed by a resend.
		if not (sent and not sent.timed_out) then
			resend_pending = false
			resend_hand()
		end
	end
end

function N.after_rejoin()
	N.apply_timer_losses()
	apply_resume_counts()
end

MPAPI.on_state(KEY, N.apply_timer_losses)
