-- Leave to the main menu from the end screen (mirrors Speed's spdrn_leave_from_game).
-- The match is already over, so no confirm; lobby:leave() fires the DISCONNECTED handler
-- which tears down the PVP-side lobby state.
function G.FUNCS.mp_pvp_leave_from_game()
	G.FUNCS.exit_overlay_menu()
	G.SETTINGS.paused = false
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		lobby:leave()
	end
	G.FUNCS.go_to_menu()
end

-- Back to the private lobby's waiting room from the end screen. Unlike the leave above, the
-- lobby stays joined: go_to_menu rebuilds the menu as the lobby view (the lobby is still
-- the current one). Each player returns on their own, so one can keep reading the end
-- screen while the others are already back; a server-refereed lobby's game has ended by
-- now, since every client reports its result when the match is decided.
function G.FUNCS.mp_pvp_return_to_lobby()
	G.FUNCS.exit_overlay_menu()
	G.SETTINGS.paused = false
	G.FUNCS.go_to_menu()
	PVP.reset_game_states()
	PVP.reset_ready_state()
end

function PVP.UI.create_UIBox_round_scores_row_nemesis()
    local label = localize({ type = "name_text", set = "Blind", key = "bl_mp_nemesis" })
    local score_tab = {}
    local label_w, score_w, h = 2.9, 1, 0.5

    local blind_name_string = (PVP.LOBBY.is_host and PVP.LOBBY.guest or PVP.LOBBY.host or {})["username"] or PVP.pvp_blind_opponent_name()

    local nemesis_blind_col = PVP.UTILS.get_nemesis_key()
    local blind_choice = {}
    blind_choice.animation = AnimatedSprite(0,0, 0.5, 0.5, G.ANIMATION_ATLAS["mp_player_blind_col"], G.P_BLINDS[nemesis_blind_col].pos)
    blind_choice.animation:define_draw_steps({
        {shader = 'dissolve', shadow_height = 0.05},
        {shader = 'dissolve'}
    })

    score_tab = {
        {n=G.UIT.C, config={align = "cm", minh = 0.7, padding = 0.1}, nodes={
            {n=G.UIT.O, config={object = DynaText({string = blind_name_string, colours = {G.C.WHITE}, shadow = true, bump = true,maxw = 2.9, scale = 0.45})}}
        }},
        {n=G.UIT.C, config={align = "cm"}, nodes={
            {n=G.UIT.O, config={object = blind_choice.animation}}
        }},
    }

    local label_scale = 0.5

    return {n=G.UIT.R, config={align = "cm", padding = 0.05, r = 0.1, colour = darken(G.C.JOKER_GREY, 0.1), emboss = 0.05, id = "mp_score_nemesis"}, nodes={
        {n=G.UIT.R, config={align = "cm", padding = 0.02, minw = label_w, maxw = label_w}, nodes={
            {n=G.UIT.T, config={text = label, scale = label_scale, colour = G.C.UI.TEXT_LIGHT, shadow = true}},
        }},
        {n=G.UIT.R, config={align = "cr"}, nodes={
            {n=G.UIT.C, config={align = "cm", minh = h, r = 0.1, minw = label_w + 0.9, colour = G.C.BLACK, emboss = 0.05}, nodes={
                {n=G.UIT.C, config={align = "cm", padding = 0.05, r = 0.1, minw = score_w}, nodes=score_tab},
            }}
        }},
    }}
end

-- Rebuilds PVP.end_game_jokers from PVP._collected_results (pvp_api/actions/
-- player_result.lua) for whichever player is currently selected -- the same
-- per-player broadcast SPDRN's own SPDRN._collected_results uses, which is
-- why MPAPI.rebuild_jokers_area (BalatroMultiplayerAPI/api/end_screen.lua)
-- can be shared between the two mods outright. Supersedes the old
-- get_end_game_jokers/load_end_game_jokers request-response pair (still
-- defined in networking/action_handlers.lua but no longer called from
-- here) -- that pair only ever tracked a single scalar payload with no
-- sender id, so in any N>2 lobby whichever response landed last would've
-- clobbered every other player's data; _collected_results is keyed by
-- sender id and already had to solve that problem for the Roster screen.
local END_GAME_JOKERS_TEXT_KEY = {
	[PVP.MATCH_PLAYERS.State.ROSTER] = "k_end_player_jokers",
	[PVP.MATCH_PLAYERS.State.LEFT] = "k_end_player_left",
	[PVP.MATCH_PLAYERS.State.PLAYING] = "k_end_player_playing",
}

local function pvp_rebuild_end_game_jokers(player_id, player_name)
	local result = player_id and PVP._collected_results and PVP._collected_results[player_id]
	local lobby = MPAPI.get_current_lobby()
	local present = PVP.MATCH_PLAYERS.present_set(lobby and lobby:get_players())
	local state = PVP.MATCH_PLAYERS.state(player_id, present, result)
	local show_jokers = state == PVP.MATCH_PLAYERS.State.ROSTER
	MPAPI.rebuild_jokers_area(PVP.end_game_jokers, show_jokers and result.jokers or nil)
	local name = player_name or "Player"
	PVP.end_game_jokers_text = localize({ type = "variable", key = END_GAME_JOKERS_TEXT_KEY[state], vars = { name } })
end

-- The players the end screen lists: everyone who started the match (a player
-- who left or forfeited stays), else the current lobby members (a rejoin has
-- no start snapshot).
local function end_screen_players(lobby)
	return PVP._match_players or (lobby and lobby:get_players()) or {}
end

G.FUNCS.pvp_end_screen_select_player = function(e)
	if not e then return end
	local lobby = MPAPI.get_current_lobby()
	local p = end_screen_players(lobby)[e.to_key]
	if not p then return end
	PVP._end_screen_selected_player_id = p.id
	PVP._end_screen_selected_player_name = p.displayName or p.id
	pvp_rebuild_end_game_jokers(p.id, PVP._end_screen_selected_player_name)
end

-- The jokers + player-selector panel embedded in end_game_body, built via
-- the shared MPAPI.end_screen_player_panel that SPDRN's own
-- SPDRN.build_end_game_extras (BalatroMultiplayerSpeed/ui/end_game_panel.lua)
-- also calls -- replaces the old binary you/nemesis toggle_players_jokers
-- ("Enemy Jokers"/"Your Jokers"). "View Deck" always opens the existing
-- nemesis-deck viewer (view_nemesis_deck below), which already tabs between
-- the nemesis's deck and your own -- PvP is 1v1, so that covers both
-- selector options without needing a per-player deck fetch.
function PVP.UI.build_end_game_extras()
	PVP.end_game_jokers = CardArea(
		0,
		0,
		5 * G.CARD_W,
		G.CARD_H,
		{ card_limit = G.GAME.starting_params.joker_slots, type = "joker", highlight_limit = 1, fixed_limit = true }
	)

	local lobby = MPAPI.get_current_lobby()
	local players, options, current_option = MPAPI.end_screen_default_selection(lobby, end_screen_players(lobby))

	local selected = players[current_option]
	PVP._end_screen_selected_player_id = selected and selected.id
	PVP._end_screen_selected_player_name = selected and (selected.displayName or selected.id)
	pvp_rebuild_end_game_jokers(PVP._end_screen_selected_player_id, PVP._end_screen_selected_player_name)

	return MPAPI.end_screen_player_panel({
		jokers_text_ref = { table = PVP, key = "end_game_jokers_text" },
		jokers_area = PVP.end_game_jokers,
		options = options,
		current_option = current_option,
		opt_callback = "pvp_end_screen_select_player",
		-- Plain "View Deck" (not localize("b_view_nemesis_deck")) to match
		-- SPDRN's identically-styled button -- the whole point of sharing
		-- this panel is that the two screens read as one system.
		view_deck_button = MPAPI.end_screen_view_deck_button("view_nemesis_deck", "View Deck"),
	})
end

-- The lobby-exit buttons on the end screen, via the shared
-- MPAPI.end_screen_buttons (matching SPDRN.end_screen_buttons's own
-- per-situation button lists in BalatroMultiplayerSpeed/ui/lose_screen.lua).
function PVP.end_screen_buttons()
	local specs = {
		{ button = "continue_in_singleplayer", label = localize("b_continue_singleplayer"), colour = G.C.BLUE },
	}
	-- A pending death is not over yet: the only way out is to leave, which is no forfeit.
	if PVP.GAME.pending_death_screen then
		return MPAPI.end_screen_buttons({
			{ button = "mp_pvp_leave_from_game", label = localize("b_leave_lobby"), colour = G.C.RED },
		})
	end
	-- Only a private lobby is a room to come back to; a matchmade one is over with the match.
	if PVP._pvp_kind == PVP.LobbyAccess.PRIVATE then
		specs[#specs + 1] =
			{ button = "mp_pvp_return_to_lobby", label = localize("b_return_lobby"), colour = G.C.GREEN }
	end
	specs[#specs + 1] = { button = "mp_pvp_leave_from_game", label = localize("b_leave_lobby"), colour = G.C.RED }
	return MPAPI.end_screen_buttons(specs)
end

-- The PvP end screen's body: the shared MPAPI.end_screen_body
-- (BalatroMultiplayerAPI/api/end_screen.lua), with the nemesis-vs-you score
-- row as PvP's one extra side row and PvP's own button set. SPDRN's
-- win_body/lose_body (BalatroMultiplayerSpeed/ui/win_screen.lua,
-- ui/lose_screen.lua) call the exact same shared body.
function PVP.UI.end_game_body(has_won)
	local side_rows = { PVP.UI.create_UIBox_round_scores_row_nemesis() }
	if PVP.GAME.contested then
		side_rows = {
			PVP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, {
				PVP.UI.UTILS.create_text_node(localize("k_pvp_contested_text_1"), { scale = 0.5, colour = G.C.UI.TEXT_LIGHT }),
			}),
			PVP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, {
				PVP.UI.UTILS.create_text_node(localize("k_pvp_contested_text_2"), { scale = 0.45, colour = G.C.UI.TEXT_LIGHT }),
			}),
		}
	end
	if PVP.GAME.pending_death_screen then
		local wait_key = PVP.GAME.pending_death and PVP.GAME.pending_death.opponent_id == nil
				and "k_pvp_pending_death_wait_many"
			or "k_pvp_pending_death_wait"
		side_rows = {}
		for _, line in ipairs({
			{ "k_pvp_pending_death_result", 0.5 },
			{ wait_key, 0.4 },
			{ "k_pvp_pending_death_leave", 0.4 },
		}) do
			side_rows[#side_rows + 1] = PVP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, {
				PVP.UI.UTILS.create_text_node(localize(line[1]), { scale = line[2], colour = G.C.UI.TEXT_LIGHT }),
			})
		end
	end
	return MPAPI.end_screen_body({
		player_panel = PVP.UI.build_end_game_extras(),
		side_rows = side_rows,
		buttons = PVP.end_screen_buttons(),
	})
end

-- Builds the PvP win / game-over screen inside the shared MPAPI.end_screen shell. The
-- nemesis-deck fetch is kicked off here (the body renders it once it arrives) --
-- jokers no longer need a fetch of their own; PVP.UI.build_end_game_extras (called
-- from end_game_body, below) reads them straight out of PVP._collected_results,
-- which is already populated synchronously before this ever runs (see
-- action_win_game/action_lose_game's PVP.report_roster_result() call in
-- networking/action_handlers.lua). PvP hooks this via the create_UIBox_win/
-- game_over overrides below rather than calling the overlay directly, so it keeps
-- its own paused handling.
function PVP.UI.prepare_nemesis_deck()
	PVP.ACTIONS.request_nemesis_stats()

	PVP.nemesis_deck = CardArea(-100, -100, G.CARD_W, G.CARD_H, { type = "deck" })
	PVP.nemesis_cards = {}
	if not PVP.nemesis_deck_received then
		PVP.ACTIONS.get_nemesis_deck()
	else
		G.FUNCS.load_nemesis_deck()
	end
end

function PVP.UI.create_UIBox_mp_game_end(has_won)
	PVP.UI.prepare_nemesis_deck()

	G.SETTINGS.paused = false

	return MPAPI.end_screen_uibox({
		won = has_won,
		draw = PVP.GAME.draw,
		title_key = PVP.GAME.contested and "k_pvp_contested_title"
			or PVP.GAME.pending_death_screen and "k_pvp_pending_death_title"
			or nil,
		id = has_won and "you_win_UI" or nil,
		body = PVP.UI.end_game_body,
	})
end

function G.UIDEF.view_nemesis_deck()
	local playing_cards_ref = G.playing_cards
	G.playing_cards = PVP.nemesis_cards
	local t = G.UIDEF.view_deck()
	G.playing_cards = playing_cards_ref
	return t
end

function G.UIDEF.create_UIBox_view_nemesis_deck()
	return create_UIBox_generic_options({
		back_func = "overlay_endgame_menu",
		contents = {
			create_tabs({
				tabs = {
					{
						label = localize("k_nemesis_deck"),
						chosen = true,
						tab_definition_function = G.UIDEF.view_nemesis_deck,
					},
					{
						label = localize("k_your_deck"),
						tab_definition_function = G.UIDEF.view_deck,
					},
				},
				tab_h = 8,
				snap_to_nav = true,
			}),
		},
	})
end

-- Contains function overrides (monkey-patches) for UI-related functionality
-- Overrides UI creation functions like create_UIBox_game_over, create_UIBox_win, etc.

local create_UIBox_game_over_ref = create_UIBox_game_over
function create_UIBox_game_over()
	if not PVP.LOBBY.code then return create_UIBox_game_over_ref() end
	return PVP.UI.create_UIBox_mp_game_end(false)
end

local create_UIBox_win_ref = create_UIBox_win
function create_UIBox_win()
	if not PVP.LOBBY.code then return create_UIBox_win_ref() end
	return PVP.UI.create_UIBox_mp_game_end(true)
end

local exit_overlay_menu_ref = G.FUNCS.exit_overlay_menu
---@diagnostic disable-next-line: duplicate-set-field
function G.FUNCS:exit_overlay_menu()
	-- Saves username if user presses ESC instead of Enter
	if G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("username_input_box") ~= nil then
		PVP.UTILS.save_username(PVP.LOBBY.username)
	end

	exit_overlay_menu_ref(self)
end

local mods_button_ref = G.FUNCS.mods_button
function G.FUNCS.mods_button(arg_736_0)
	if G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("username_input_box") ~= nil then
		PVP.UTILS.save_username(PVP.LOBBY.username)
	end

	mods_button_ref(arg_736_0)
end

function G.UIDEF.multiplayer_deck()
	return G.UIDEF.challenge_description(
		get_challenge_int_from_id(PVP.current_ruleset().challenge_deck),
		nil,
		false
	)
end
