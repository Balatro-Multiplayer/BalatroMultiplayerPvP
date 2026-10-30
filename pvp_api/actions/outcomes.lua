local A = PVP._pvp_action_helpers.A
local A_host = PVP._pvp_action_helpers.A_host
local self_id = PVP._pvp_action_helpers.self_id

-- Authoritative outcomes (host -> all).
A_host("pvp_end_pvp", function(_at, _from, params)
	-- An eliminated player's run is over; the rounds the others play on aren't its.
	if PVP.GAME.eliminated then
		return
	end
	local sid = self_id()
	local lost = params.loser_id ~= nil and params.loser_id ~= "" and params.loser_id == sid
	PVP.dispatch_action("endPvP", { lost = lost, pvpTimerLost = params.pvp_timer_lost and true or false })
end)

-- A client that saw a player drop to 0 lives and has heard no result after this
-- long asks the host to send it again (the host also repeats it unasked).
local RESULT_WAIT = 5

local function watch_for_result()
	if not (G and G.E_MANAGER) then
		return
	end
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = RESULT_WAIT,
		timer = "REAL",
		blocking = false,
		blockable = false,
		func = function()
			local lobby = MPAPI.get_current_lobby()
			if
				lobby
				and G.STAGE == G.STAGES.RUN
				and not PVP.GAME.result_handled
				and not PVP.GAME.eliminated
				and G.STATE ~= G.STATES.GAME_OVER
			then
				sendDebugMessage("[pvp] no pvp_win after a player hit 0 lives; asking the host", "MULTIPLAYER")
				lobby:action(MPAPI.ActionTypes["pvp_result_request"]):broadcast({})
			end
			return true
		end,
	}))
end

A_host("pvp_player_lives", function(_at, _from, params)
	local sid = self_id()
	local lives = tonumber(params.lives)

	-- Every client hears every player's lives (the host broadcasts to the whole
	-- lobby), so Lobby Info reads any player from this cache. The host itself
	-- reads PVP.REF.
	local lobby = MPAPI.get_current_lobby()
	local player_ids = {}
	for _, p in ipairs(lobby and lobby:get_players() or {}) do
		player_ids[#player_ids + 1] = p.id
	end
	PVP._player_lives_cache = PVP.lives_cache_after(PVP._player_lives_cache, params, player_ids)

	if lives == 0 and params.player_id ~= "*all*" then
		watch_for_result()
	end

	if params.player_id == "*all*" then
		PVP.GAME.lives = lives
		if PVP.GAME.enemy then
			PVP.GAME.enemy.lives = lives
		end
		PVP.dispatch_action("playerInfo", { lives = lives })
	elseif params.player_id == sid then
		-- Only a broadcast that marks a loss counts (an older host never marks
		-- one, so nothing is logged): Teams logs it for each teammate, since
		-- each of them lost a life from the shared pool.
		local lost = tonumber(params.lost)
		if lost and lost > 0 and PVP.RLOG then
			PVP.RLOG.record(MPAPI.OPCODE.LIFE_LOST, { lost = lost, lives = lives })
		end
		PVP.dispatch_action("playerInfo", { lives = lives })
	elseif params.player_id == PVP.current_target_id() then
		if PVP.GAME.enemy then
			if PVP.OPPONENT_SIGNALS.lives_dropped(PVP.GAME.enemy.lives, lives) then
				PVP.OPPONENT_SIGNALS.play_life_lost()
			end
			PVP.GAME.enemy.lives = lives
			if PVP.UI and PVP.UI.juice_up_pvp_hud then
				pcall(PVP.UI.juice_up_pvp_hud)
			end
		end
	end
end)

-- The referee's "you are out" for a match that goes on without this player
-- (Royale and N-player Nemesis/Manhunt; see announce_eliminations in
-- referee.lua): the player gets its lose screen now instead of playing on.
-- The match's own pvp_win still arrives later, and is then only reported.
A_host("pvp_eliminated", function(_at, _from, params)
	if params.player_id ~= self_id() or PVP.GAME.eliminated or PVP.GAME.contested then
		return
	end
	PVP.GAME.eliminated = true
	PVP.end_pending_death()
	PVP.dispatch_action("loseGame")
end)

-- A player lost their last life on a non-PvP blind in a 2-player match (or a whole
-- Manhunt/Teams side did: params.team_id). The
-- referee waits for the opponent to beat the same blind before it decides.
A_host("pvp_death_pending", function(_at, _from, params)
	if PVP.GAME.won or PVP.GAME.draw then
		return
	end
	if params.team_id then
		-- Manhunt or Teams: a whole side is pending. Every client keeps it; the dead
		-- side's players wait on the screen.
		PVP.GAME.team_pending = { team_id = params.team_id, blind_key = params.blind_key }
		local roster = PVP.LOBBY.roster
		if not (roster and roster[self_id()] == params.team_id) then
			PVP.UI.show_pending_death_notice()
			return
		end
		PVP.GAME.pending_death = { player_id = self_id(), blind_key = params.blind_key }
		PVP.UI.show_pending_death_screen()
		return
	end
	if params.opponent_id == nil then
		-- A match of 3 or more players: every client keeps who is pending, only the
		-- dead player waits on the screen.
		PVP.GAME.pending_deaths = PVP.GAME.pending_deaths or {}
		PVP.GAME.pending_deaths[params.player_id] = params.blind_key
		if params.player_id ~= self_id() then
			PVP.UI.show_pending_death_notice()
			return
		end
	end
	PVP.GAME.pending_death = {
		player_id = params.player_id,
		opponent_id = params.opponent_id,
		blind_key = params.blind_key,
	}
	if params.player_id == self_id() then
		PVP.UI.show_pending_death_screen()
	else
		PVP.UI.show_pending_death_notice()
	end
end)

A("pvp_result_request", function(_at, from, _params)
	PVP.referee_on_result_request(from)
end)

A_host("pvp_win", function(_at, _from, params)
	-- The host repeats pvp_win, so this can arrive more than once, and late: act
	-- on it once, and never outside a run (a player who already left the end
	-- screen must not be dropped into win_game()).
	if PVP.GAME.result_handled or G.STAGE ~= G.STAGES.RUN then
		sendDebugMessage("[pvp] pvp_win ignored (already handled or not in a run)", "MULTIPLAYER")
		return
	end
	PVP.GAME.result_handled = true
	sendDebugMessage("[pvp] pvp_win received", "MULTIPLAYER")
	local lobby = MPAPI.get_current_lobby()
	-- A contested match has no result for this client to report: a moderator decides.
	if PVP.GAME.contested then
		return
	end
	PVP.end_pending_death()
	PVP.GAME.team_pending = nil
	-- A draw (a unanimous vote, or referee.lua's check_alive_win seeing everyone
	-- eliminated at once) has no winner to resolve against -- both routes here
	-- converge on the same drawGame dispatch/MMR-skip, see pvp_api/run_actions.lua's
	-- PVP.register_draw_vote for why this reuses pvp_win instead of a separate action.
	local refereed = MPAPI.has_server_referee(lobby)
	if params.places then
		-- A match of 3 or more players with pending deaths: the referee sent every
		-- player's place, tied players share one.
		local mine = params.places[self_id()]
		local tied_first = params.draw == true
		if not PVP.GAME.eliminated or mine == 1 then
			PVP.dispatch_action((mine == 1 and (tied_first and "drawGame" or "winGame")) or "loseGame")
		end
		if refereed then
			PVP.report_server_result(lobby, nil, { places = params.places })
		end
		PVP.release_held_result(lobby)
		return
	end
	if params.draw then
		PVP.dispatch_action("drawGame")
		if refereed then
			PVP.report_server_result(lobby, nil, { draw = true })
		end
		PVP.release_held_result(lobby)
		return
	end

	local sid = self_id()
	local i_won
	if params.winner_team_id then
		-- Manhunt/Teams: the referee declares a TEAM the winner (winner_id is left
		-- empty, see referee.lua) -- resolve against my own roster assignment
		-- instead of comparing player ids.
		i_won = PVP.LOBBY.roster and PVP.LOBBY.roster[sid] == params.winner_team_id
	else
		i_won = params.winner_id == sid
	end
	-- An eliminated player already has its lose screen (pvp_eliminated).
	if not PVP.GAME.eliminated then
		PVP.dispatch_action(i_won and "winGame" or "loseGame")
	end
	-- A server-refereed lobby: everyone reports (the server rates it). An
	-- offline lobby has nothing to report to.
	if refereed then
		PVP.report_server_result(lobby, params.winner_team_id or params.winner_id, { team = params.winner_team_id ~= nil })
	end
	PVP.release_held_result(lobby)
end)

-- Opponent-forfeit win (broadcast from the gamemode's on_player_forfeit).
-- A server-refereed lobby: whoever is still in reports it (the forfeiter has
-- left, so the server settles the run as partial).
A_host("pvp_player_won", function(_at, _from, params)
	if PVP.GAME.contested then
		return
	end
	local sid = self_id()
	if params.player_id == sid then
		PVP.dispatch_action("winGame")
	elseif not PVP.GAME.eliminated then
		PVP.dispatch_action("loseGame")
	end
	local lobby = MPAPI.get_current_lobby()
	if MPAPI.has_server_referee(lobby) then
		PVP.report_server_result(lobby, params.player_id)
	end
end)
