-- The Forfeit or Contest modal of a matchmade match, and the screen the players
-- get once a Contest went through: both players in a match of 2, only the
-- contester in a larger one (who also picks the opponent to contest). The
-- decision to show the modal is lib/contest.lua. Contest is not a forfeit and
-- not a result: it leaves the pending flag alone and reports nothing, the
-- server holds the run unrated for a moderator.

local function text_row(text, scale, colour)
	return PVP.UI.UTILS.create_row({ align = "cm", padding = 0.04 }, {
		PVP.UI.UTILS.create_text_node(text, { scale = scale, colour = colour or G.C.UI.TEXT_LIGHT }),
	})
end

local function button_row(button, label_key, colour)
	return PVP.UI.UTILS.create_row({ align = "cm", padding = 0.06 }, {
		UIBox_button({ button = button, label = { localize(label_key) }, minw = 5, colour = colour }),
	})
end

-- error_key: the short message of a refused Contest, shown above the buttons.
function G.UIDEF.contest_modal(error_key)
	local rows = {
		text_row(localize("k_pvp_contest_title"), 0.7),
		text_row(localize("k_pvp_contest_warn_1"), 0.4),
		text_row(localize("k_pvp_contest_warn_2"), 0.4),
		text_row(localize("k_pvp_contest_warn_3"), 0.4, G.C.RED),
	}
	if error_key then
		rows[#rows + 1] = text_row(localize(error_key), 0.45, G.C.RED)
	end
	rows[#rows + 1] = button_row("mp_pvp_contest_forfeit", "b_pvp_forfeit", G.C.RED)
	rows[#rows + 1] = button_row("mp_pvp_contest_send", "b_pvp_contest", G.C.ORANGE)
	rows[#rows + 1] = button_row("mp_pvp_contest_cancel", "b_pvp_contest_cancel", G.C.GREY)
	return create_UIBox_generic_options({
		no_back = true,
		contents = { { n = G.UIT.C, config = { align = "cm", padding = 0.1 }, nodes = rows } },
	})
end

-- The contester names one of the other players still in the match.
function G.UIDEF.contest_opponent_picker(opponents)
	local rows = {
		text_row(localize("k_pvp_contest_pick_title"), 0.6),
		text_row(localize("k_pvp_contest_pick_text"), 0.4),
	}
	for _, opponent in ipairs(opponents) do
		rows[#rows + 1] = PVP.UI.UTILS.create_row({ align = "cm", padding = 0.06 }, {
			UIBox_button({
				button = "mp_pvp_contest_pick",
				label = { opponent.displayName },
				minw = 5,
				colour = G.C.ORANGE,
				ref_table = { id = opponent.id },
			}),
		})
	end
	rows[#rows + 1] = button_row("mp_pvp_contest_cancel", "b_pvp_contest_cancel", G.C.GREY)
	return create_UIBox_generic_options({
		no_back = true,
		contents = { { n = G.UIT.C, config = { align = "cm", padding = 0.1 }, nodes = rows } },
	})
end

function PVP.UI.show_contest_modal(error_key)
	G.SETTINGS.paused = true
	G.FUNCS.overlay_menu({ definition = G.UIDEF.contest_modal(error_key) })
end

-- True when the Forfeit button should open the modal instead of forfeiting.
function PVP.contest_offered()
	local lobby = MPAPI.get_current_lobby()
	if not lobby or PVP.is_practice_mode() then
		return false
	end
	return PVP.Contest.should_offer(PVP._pvp_kind, #lobby:get_players(), MPAPI.has_server_referee(lobby))
end

function G.FUNCS.mp_pvp_contest_forfeit()
	G.FUNCS.exit_overlay_menu()
	PVP.pvp_forfeit()
end

function G.FUNCS.mp_pvp_contest_cancel()
	G.FUNCS.exit_overlay_menu()
end

-- Players who started the match, else the current lobby members.
local function match_players(lobby)
	return PVP._match_players or lobby:get_players()
end

local function send_contest(opponent_id)
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return
	end
	-- Not on the pending flag: it stays as it is until a moderator decides.
	lobby:contest(opponent_id, function(err)
		if err then
			sendWarnMessage("contest error: " .. tostring(err.message or err.kind or err), "MULTIPLAYER")
			PVP.UI.show_contest_modal(PVP.Contest.error_key(err))
			return
		end
		-- This client is the contester: it names the scope of its own contest.
		local me = PVP.self_player_id()
		if PVP.Contest.scope(#match_players(lobby), me, me) == PVP.Contest.Scope.CONTESTER then
			PVP.show_contester_contested_screen()
		else
			PVP.show_contested_screen()
		end
	end)
end

function G.FUNCS.mp_pvp_contest_send()
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return
	end
	if #match_players(lobby) <= 2 then
		send_contest(nil)
		return
	end
	local opponents = PVP.Contest.opponents(lobby:get_players(), PVP.self_player_id(), PVP._player_lives_cache)
	if #opponents == 0 then
		PVP.UI.show_contest_modal(PVP.Contest.error_key("not_in_game"))
	elseif #opponents == 1 then
		send_contest(opponents[1].id)
	else
		G.FUNCS.exit_overlay_menu()
		G.FUNCS.overlay_menu({ definition = G.UIDEF.contest_opponent_picker(opponents) })
	end
end

function G.FUNCS.mp_pvp_contest_pick(e)
	local opponent = e and e.config and e.config.ref_table
	G.FUNCS.exit_overlay_menu()
	if opponent and opponent.id then
		send_contest(opponent.id)
	end
end

-- Ends the match on this client with the contested screen. The contester and
-- the opponent both land here (MPAPI.LobbyEvent.CONTESTED, or GAME_ENDED with
-- status contested), so it runs once. It is the draw screen with another title,
-- and it reports no result.
function PVP.show_contested_screen()
	if PVP.GAME.contested or PVP.GAME.won or PVP.GAME.draw or G.STAGE ~= G.STAGES.RUN then
		return
	end
	PVP.GAME.contested = true
	PVP.end_pending_death()
	G.FUNCS.exit_overlay_menu()
	PVP.dispatch_action("drawGame")
end

-- A match of 3 or more players: only the contester leaves. They get the same
-- contested screen, and the others are told nothing but a chat line. The
-- contester's leave goes through pvp_forfeit, the same path as leaving the
-- lobby, so the referee drops their hands and ends the match for nobody else
-- unless one player is left (a pending death of theirs is handled there
-- instead of as a forfeit).
function PVP.show_contester_contested_screen()
	if PVP.GAME.contested or G.STAGE ~= G.STAGES.RUN then
		return
	end
	PVP.GAME.contested = true
	PVP.pvp_forfeit()
	PVP.end_pending_death()
	G.FUNCS.exit_overlay_menu()
	PVP.dispatch_action("drawGame")
end

-- The others in a match of 3 or more players: a chat line, no screen.
function PVP.note_contest_by(player_id)
	if not (MPAPI.chat and MPAPI.chat.addMessage) then
		return
	end
	local name = player_id
	for _, p in ipairs(match_players(MPAPI.get_current_lobby())) do
		if p.id == player_id then
			name = p.displayName or player_id
		end
	end
	MPAPI.chat.addMessage(
		localize({ type = "variable", key = "k_pvp_contest_by", vars = { name } }),
		G.C.ORANGE
	)
end
