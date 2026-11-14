-- Pause-menu run actions: Forfeit + Seed-change vote + Draw vote (mirrors Speed's
-- objects/actions/forfeit.lua + objects/actions/seed_vote.lua + ui/lobby/seed_vote.lua).
-- Each is a request to the server (PVP.ResultNet), which tallies and decides.

-- ── Forfeit ──────────────────────────────────────────────────────────────────
function PVP.pvp_forfeit()
	local lobby = MPAPI.get_current_lobby()
	if not lobby then return end
	-- Roster first: the others list this player's jokers on their end screen.
	PVP.report_roster_result()
	PVP.ResultNet.forfeit()
end

-- ── Seed-change vote ─────────────────────────────────────────────────────────
-- A unanimous vote restarts the match on a fresh seed: the server finishes this game
-- (kept as 'restarted') and starts the next on its own seed (GAME_STARTED with
-- restarted = true, see pvp_api/lobby_bridge.lua).

-- Every client's restart on a new seed, off a restarted GAME_STARTED
-- (see pvp_api/lobby_bridge.lua). Restarts WITHOUT re-running the
-- deck+stake draft: reuse the local start path (action_start_game) with the already-pinned deck.
function PVP.on_reseed(seed)
	PVP.dispatch_action("startGame", { seed = seed, stake = PVP.LOBBY.deck.stake })
end

function PVP.cast_seed_vote()
	local run_id = PVP.current_run_id()
	if run_id then PVP.ResultNet.vote({ runId = run_id, kind = "seed", yes = true }) end
end

-- ── Draw vote ────────────────────────────────────────────────────────────────
-- A unanimous vote ends the match as a draw; the server declares it (pvp.result).
function PVP.cast_draw_vote()
	local run_id = PVP.current_run_id()
	if run_id then PVP.ResultNet.vote({ runId = run_id, kind = "draw", yes = true }) end
end

-- ── Vote feedback ────────────────────────────────────────────────────────────
-- The server's vote counts (PVP.GAME.vote_tally, pvp_api/result_net.lua) show as a chat
-- line on every client whenever a count changes. ResultNet calls this with each new tally.
-- The counts shown last belong to one run: a new run starts again from 0. No run id (the game
-- ended and the lobby cleared it) is not a new run, so it keeps what was shown.
local shown_votes = { run_id = nil, draw = 0, seed = 0 }

function PVP.show_vote_counts(tally, run_id)
	local lobby = MPAPI.get_current_lobby()
	if not tally or not lobby or not (MPAPI.chat and MPAPI.chat.addMessage) then return end
	if run_id ~= nil and run_id ~= shown_votes.run_id then shown_votes = { run_id = run_id, draw = 0, seed = 0 } end
	local total = #lobby:get_players()
	for _, vote in ipairs({
		{ "draw", localize("k_draw_vote") or "Vote for Draw" },
		{ "seed", localize("k_seed_vote") or "Vote to change seed" },
	}) do
		local kind, label = vote[1], vote[2]
		local count = tally[kind] or 0
		if count ~= shown_votes[kind] then
			shown_votes[kind] = count
			-- A count back at 0 is a reset, not a vote.
			if count > 0 then MPAPI.chat.addMessage(label .. ": " .. count .. "/" .. total, G.C.BLUE) end
		end
	end
end
