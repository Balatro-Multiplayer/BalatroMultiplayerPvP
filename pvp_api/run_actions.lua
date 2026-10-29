-- Pause-menu run actions: Forfeit + Seed-change vote + Draw vote (mirrors Speed's
-- objects/actions/forfeit.lua + objects/actions/seed_vote.lua + ui/lobby/seed_vote.lua).
-- Loaded inside MPAPI.on_loaded (pvp_api dir) so the ActionTypes are tagged to this mod.
-- prefix_config.key = false keeps the literal pvp_* keys (see actions.lua for why).

-- Random 8-char run seed (uppercase alphanumeric), matching the game's seed alphabet.
function PVP.generate_seed()
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
	local s = ""
	for _ = 1, 8 do
		local n = math.random(#chars)
		s = s .. chars:sub(n, n)
	end
	return s
end

-- ── Forfeit ──────────────────────────────────────────────────────────────────
-- Broadcast reaches every client. Only the host does anything: it runs the gamemode's
-- forfeit hook (check_single_survivor -> pvp_player_won), the exact path a mid-match
-- leave takes (pvp_api/lobby_bridge.lua). pvp_player_won then gives the forfeiter the
-- lose screen and the opponent the win -- so there is no separate/duplicate lose here.
MPAPI.ActionType({
	key = "pvp_forfeit",
	prefix_config = { key = false },
	on_receive = function(_at, from_player_id, _params)
		if G.STAGE ~= G.STAGES.RUN then
			return
		end
		local lobby = MPAPI.get_current_lobby()
		if not lobby then
			return
		end
		local instance = lobby.get_gamemode_instance and lobby:get_gamemode_instance()
		if instance and instance.on_player_forfeit and not PVP.referee_pending_death_on_player_gone(from_player_id) then
			MPAPI._handle_gamemode_result(instance, instance:on_player_forfeit(from_player_id))
		end
	end,
})

function PVP.pvp_forfeit()
	local lobby = MPAPI.get_current_lobby()
	if not lobby or not MPAPI.ActionTypes["pvp_forfeit"] then
		return
	end
	-- Roster first: the others list this player's jokers on their end screen.
	PVP.report_roster_result()
	lobby:action(MPAPI.ActionTypes["pvp_forfeit"]):broadcast({})
end

-- ── Seed-change vote ─────────────────────────────────────────────────────────
-- A unanimous vote restarts the match on a fresh seed. Each client tallies the vote
-- independently (broadcast reaches all); the host restarts on unanimity.
MPAPI.ActionType({
	key = "pvp_seed_vote",
	prefix_config = { key = false },
	on_receive = function(_at, from_player_id, _params)
		PVP.register_seed_vote(from_player_id)
	end,
})

-- Restart the run on the new seed WITHOUT re-running the deck+stake draft: reuse the
-- local start path (action_start_game) with the already-pinned deck. Broadcast by the
-- host on a unanimous vote; every client (host included via loopback) applies it.
MPAPI.ActionType({
	key = "pvp_reseed",
	prefix_config = { key = false },
	-- Host-only (pvp_api/actions/_helpers.lua): a guest can't restart the match.
	on_receive = PVP._pvp_action_helpers.host_only("pvp_reseed", function(_at, _from, params)
		PVP.on_reseed(params.seed)
	end),
})

-- Every client's restart on a new seed: off pvp_reseed, or off a restarted
-- GAME_STARTED in a server-refereed lobby (see pvp_api/lobby_bridge.lua).
function PVP.on_reseed(seed)
	local lobby = MPAPI.get_current_lobby()
	if lobby and lobby.is_host then
		PVP.referee_reset(PVP.LOBBY.config.starting_lives)
	end
	PVP.dispatch_action("startGame", { seed = seed, stake = PVP.LOBBY.deck.stake })
end

function PVP.cast_seed_vote()
	local lobby = MPAPI.get_current_lobby()
	if not lobby or not MPAPI.ActionTypes["pvp_seed_vote"] then
		return
	end
	lobby:action(MPAPI.ActionTypes["pvp_seed_vote"]):broadcast({})
end

-- Runs on every client when any vote arrives. Tallies via the lobby VoteTracker, shows
-- progress in chat, and (host only) restarts on a fresh seed once the vote is unanimous.
function PVP.register_seed_vote(voter_id)
	local lobby = MPAPI.get_current_lobby()
	if not lobby or not PVP.lobby or not PVP.lobby.seed_votes then
		return
	end
	local count, total, unanimous = PVP.lobby.seed_votes:record(voter_id)

	if MPAPI.chat and MPAPI.chat.addMessage then
		MPAPI.chat.addMessage(
			(localize("k_seed_vote") or "Vote to change seed") .. ": " .. count .. "/" .. total,
			G.C.BLUE
		)
	end

	if lobby.is_host and unanimous and MPAPI.has_server_referee(lobby) then
		-- The server finishes this game (kept as 'restarted') and starts the next
		-- on its own seed: GAME_STARTED with restarted = true.
		PVP.lobby.seed_votes:reset()
		lobby:restart_game(function(err)
			if err then
				sendWarnMessage("restart_game error: " .. tostring(err), "MULTIPLAYER")
			end
		end)
	elseif lobby.is_host and unanimous and MPAPI.ActionTypes["pvp_reseed"] then
		PVP.lobby.seed_votes:reset()
		lobby:action(MPAPI.ActionTypes["pvp_reseed"]):broadcast({ seed = PVP.generate_seed() })
	end
end

-- ── Draw vote ────────────────────────────────────────────────────────────────
-- A unanimous vote ends the match as a draw. Each client tallies the vote
-- independently (broadcast reaches all); the host declares the draw on unanimity.
MPAPI.ActionType({
	key = "pvp_draw_vote",
	prefix_config = { key = false },
	on_receive = function(_at, from_player_id, _params)
		PVP.register_draw_vote(from_player_id)
	end,
})

function PVP.cast_draw_vote()
	local lobby = MPAPI.get_current_lobby()
	if not lobby or not MPAPI.ActionTypes["pvp_draw_vote"] then
		return
	end
	lobby:action(MPAPI.ActionTypes["pvp_draw_vote"]):broadcast({})
end

-- Runs on every client when any vote arrives. Tallies via the lobby VoteTracker, shows
-- progress in chat, and (host only) declares the draw once the vote is unanimous.
--
-- Reuses the existing pvp_win action (params.draw = true) rather than a dedicated
-- resolution ActionType: pvp_win is already the one authoritative "match outcome"
-- broadcast every client reacts to (see pvp_api/actions/outcomes.lua), and
-- referee.lua's check_alive_win declares a simultaneous-elimination draw through
-- that exact same action -- reusing it here means both ways a match can end in a
-- draw converge on one on_receive handler instead of two parallel copies of the
-- same "show the draw screen, skip MMR" logic.
function PVP.register_draw_vote(voter_id)
	local lobby = MPAPI.get_current_lobby()
	if not lobby or not PVP.lobby or not PVP.lobby.draw_votes then
		return
	end
	local count, total, unanimous = PVP.lobby.draw_votes:record(voter_id)

	if MPAPI.chat and MPAPI.chat.addMessage then
		MPAPI.chat.addMessage(
			(localize("k_draw_vote") or "Vote for Draw") .. ": " .. count .. "/" .. total,
			G.C.BLUE
		)
	end

	if lobby.is_host and unanimous and MPAPI.ActionTypes["pvp_win"] then
		PVP.lobby.draw_votes:reset()
		lobby:action(MPAPI.ActionTypes["pvp_win"]):broadcast({ draw = true })
	end
end
