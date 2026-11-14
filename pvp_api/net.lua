-- Outgoing transport bridge.
--
-- The PVP codebase emits network messages through PVP.net_route({action=..., ...}):
-- each one becomes a request to the server (PVP.RoundNet / PVP.ResultNet) or, for the
-- relay-kept keys, a pvp_* ActionType broadcast over the API lobby (see actions.lua).
-- All the per-action LOCAL work in PVP.ACTIONS.* runs in networking/action_handlers.lua;
-- only the transport lives here. The server referees: a fact here is a request, never a decision.

local pvp_lobby = PVP.NetBasics.pvp_lobby

local function broadcast(key, params)
	local l = pvp_lobby()
	if l and MPAPI.ActionTypes[key] then l:action(MPAPI.ActionTypes[key]):broadcast(params or {}) end
end

-- Runs `send(run_id, round_id)` only while a run is open: a fact about no run is dropped.
local function with_run(send)
	local run_id = PVP.current_run_id()
	if run_id then send(run_id, PVP.GAME.round_id) end
end

-- Where a legacy message goes (PVP.net_route): to the server as a
-- request (ReadyNet, RoundNet), to the other players as a pvp_* ActionType
-- broadcast (the relay-kept keys), or nowhere (a local-only action). The key is msg.action.
-- Anything not listed is sent nowhere.
local ROUTES = {
	readyBlind = function(_msg)
		PVP.ReadyNet.request_ready()
	end,
	unreadyBlind = function(_msg)
		PVP.ReadyNet.request_unready()
	end,
	failRound = function(msg)
		-- The one send that costs the guarded life (roundLost); the failure record rides with it.
		with_run(function(run_id)
			PVP.RoundNet.blind({
				runId = run_id,
				blindKey = PVP.PendingDeath.blind_key(msg.ante, msg.blind),
				beaten = false,
				roundLost = true,
			})
		end)
	end,
	blindResult = function(msg)
		with_run(function(run_id)
			PVP.RoundNet.blind({
				runId = run_id,
				blindKey = PVP.PendingDeath.blind_key(msg.ante, msg.blind),
				beaten = msg.beaten,
				roundLost = false,
			})
		end)
	end,
	handCommit = function(msg)
		-- Play was pressed in the PvP blind: tells the server before the animation, which credits the hand's
		-- time. Only a round the server still has open takes it (lib/round_facts.lua).
		with_run(function(run_id, round_id)
			if not PVP.RoundFacts.hand_counts(MPAPI.get_state("pvp.round"), run_id, round_id) then return end
			PVP.RoundNet.hand_commit({
				runId = run_id,
				roundId = round_id,
				handsLeft = msg.handsLeft,
				timerLossesApplied = PVP.RoundNet.applied_count(run_id, round_id),
			})
		end)
	end,
	setLocation = function(msg)
		broadcast("pvp_location", { location = msg.location })
	end,
	playHand = function(msg)
		-- Only a hand of the open PvP round is a fact (lib/round_facts.lua).
		with_run(function(run_id, round_id)
			if not PVP.RoundFacts.hand_counts(MPAPI.get_state("pvp.round"), run_id, round_id) then return end
			PVP.RoundNet.hand({
				runId = run_id,
				roundId = round_id,
				score = msg.score,
				handsLeft = msg.handsLeft,
				timerLossesApplied = PVP.RoundNet.applied_count(run_id, round_id),
			})
		end)
		-- Score-bearing RLOG event: this is the only point in the codebase
		-- where "my own score after playing" is already computed for the
		-- legacy broadcast, so it doubles as the carbon-log source for this
		-- hand's result. Carbon-only -- no human-line equivalent exists.
		-- Recorded BEFORE calculate_blind: calculate_blind can synchronously
		-- decide this hand ends the match (action_win_game/action_lose_game),
		-- which calls RLOG.end_run and flips RLOG._run_active to false --
		-- recording after that point drops the decisive hand's own result.
		if PVP.RLOG then
			PVP.RLOG.record(MPAPI.OPCODE.HAND_RESULT, { PVP.Score.from_game_value(msg.score), msg.handsLeft })
		end
	end,
	setAnte = function(msg)
		-- Ante 0 is the run-start reset; the server counts from the run's own id.
		if msg.ante < 1 then return end
		-- The furthest blind is reported once it is known: the server keeps the prior value until then.
		if PVP.GAME.furthest_blind == nil then return end
		with_run(function(run_id)
			PVP.RoundNet.progress({ runId = run_id, ante = msg.ante, furthestBlind = PVP.GAME.furthest_blind })
		end)
	end,
	setFurthestBlind = function(msg)
		with_run(function(run_id)
			PVP.RoundNet.progress({
				runId = run_id,
				ante = G.GAME.round_resets.ante,
				furthestBlind = msg.furthestBlind,
			})
		end)
	end,
	getEndGameJokers = function(_msg)
		broadcast("pvp_get_end_game_jokers", {})
	end,
	receiveEndGameJokers = function(msg)
		broadcast("pvp_receive_end_game_jokers", msg)
	end,
	getNemesisDeck = function(_msg)
		broadcast("pvp_get_nemesis_deck", {})
	end,
	receiveNemesisDeck = function(msg)
		broadcast("pvp_receive_nemesis_deck", msg)
	end,
	endGameStatsRequested = function(_msg)
		broadcast("pvp_end_game_stats_requested", {})
	end,
	nemesisEndGameStats = function(msg)
		broadcast("pvp_nemesis_end_game_stats", msg)
	end,
}

function PVP.net_route(msg)
	if type(msg) ~= "table" or not msg.action then return end
	local route = ROUTES[msg.action]
	if route then route(msg) end
	-- An action with no route is sent nowhere.
end
