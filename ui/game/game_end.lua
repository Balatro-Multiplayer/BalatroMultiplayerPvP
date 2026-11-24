-- Back to the private lobby's waiting room from the end screen. Unlike the leave in leave.lua, the
-- lobby stays joined: go_to_menu rebuilds the menu as the lobby view (the lobby is still
-- the current one). Each player returns on their own, so one can keep reading the end
-- screen while the others are already back; the server has decided the match by now.
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

-- Rebuilds PVP.end_game_jokers for whichever player is currently selected: my own jokers from my
-- game, another player's from the view (PVP.finish_screen). No jokers known = no ROSTER state.
local END_GAME_JOKERS_TEXT_KEY = {
	[PVP.MATCH_PLAYERS.State.ROSTER] = "k_end_player_jokers",
	[PVP.MATCH_PLAYERS.State.LEFT] = "k_end_player_left",
	[PVP.MATCH_PLAYERS.State.PLAYING] = "k_end_player_playing",
}

-- A player's end-screen state and the line that says it ("X is still playing"). `result` is
-- { jokers } when the view carries them; View Deck passes none, since it asks about the deck.
local function end_game_player_state(player_id, player_name, result)
	local lobby = MPAPI.get_current_lobby()
	local present = PVP.MATCH_PLAYERS.present_set(lobby and lobby:get_players())
	local state = PVP.MATCH_PLAYERS.state(player_id, present, result)
	local text =
		localize({ type = "variable", key = END_GAME_JOKERS_TEXT_KEY[state], vars = { player_name or "Player" } })
	return state, result, text
end

local function pvp_rebuild_end_game_jokers(player_id, player_name)
	local jokers = player_id and PVP.finish_screen.jokers_of(player_id)
	local state, result, text = end_game_player_state(player_id, player_name, jokers and { jokers = jokers } or nil)
	local show_jokers = state == PVP.MATCH_PLAYERS.State.ROSTER
	MPAPI.rebuild_jokers_area(PVP.end_game_jokers, show_jokers and result.jokers or nil)
	PVP.end_game_jokers_text = text
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

-- The open end screen takes jokers that arrived after it was built (pvp_api/finish_screen.lua).
-- The player who lost usually sees the screen before the winner's jokers come in.
function PVP.UI.refresh_end_game_jokers()
	local id = PVP._end_screen_selected_player_id
	if id == nil or not PVP.end_game_jokers or PVP.end_game_jokers.REMOVED then return end
	pvp_rebuild_end_game_jokers(id, PVP._end_screen_selected_player_name)
end

-- The jokers + player-selector panel embedded in end_game_body, built via
-- the shared MPAPI.end_screen_player_panel that SPDRN's own
-- SPDRN.build_end_game_extras (BalatroMultiplayerSpeed/ui/end_game_panel.lua)
-- also calls -- replaces the old binary you/nemesis toggle_players_jokers
-- ("Enemy Jokers"/"Your Jokers"). It opens on your nemesis, not on you
-- (PVP.UI.end_screen_start_index). "View Deck" opens a tab per player, starting
-- on the selected player's (PVP.UI.deck_tabs below).
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
	current_option = PVP.UI.end_screen_start_index(
		players,
		lobby and lobby.player_id,
		PVP._end_screen_selected_player_id,
		PVP.current_target_id and PVP.current_target_id(),
		current_option
	)

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

-- The rank line under the nemesis row: { text, scale, padding }, or nil when the result did not say.
-- The overlay is centred, so a taller body loses its title at the top: the line a ranked screen newly
-- gets is the compact one.
function PVP.UI.end_info_line()
	local rank = PVP.GAME.end_rank
	if rank == "counts" then
		return { text = localize("k_pvp_game_counts"), scale = 0.32, padding = 0 }
	elseif rank == "not_counted" then
		return { text = localize("k_pvp_game_unrated"), scale = 0.4, padding = 0.05 }
	end
	return nil
end

-- The PvP end screen's body: the shared MPAPI.end_screen_body
-- (BalatroMultiplayerAPI/api/end_screen.lua), with the nemesis-vs-you score
-- row as PvP's one extra side row and PvP's own button set. SPDRN's
-- win_body/lose_body (BalatroMultiplayerSpeed/ui/win_screen.lua,
-- ui/lose_screen.lua) call the exact same shared body.
function PVP.UI.end_game_body(has_won)
	local side_rows = { PVP.UI.create_UIBox_round_scores_row_nemesis() }
	if PVP.GAME.end_shown == "by contest" then
		side_rows = {
			PVP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, {
				PVP.UI.UTILS.create_text_node(localize("k_pvp_contested_text_1"), { scale = 0.5, colour = G.C.UI.TEXT_LIGHT }),
			}),
			PVP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, {
				PVP.UI.UTILS.create_text_node(localize("k_pvp_contested_text_2"), { scale = 0.45, colour = G.C.UI.TEXT_LIGHT }),
			}),
		}
	end
	local info = PVP.GAME.end_shown ~= "by contest" and PVP.UI.end_info_line() or nil
	if info then
		side_rows[#side_rows + 1] = PVP.UI.UTILS.create_row({ align = "cm", padding = info.padding }, {
			PVP.UI.UTILS.create_text_node(info.text, { scale = info.scale, colour = G.C.UI.TEXT_LIGHT }),
		})
	end
	if PVP.GAME.pending_death_screen then
		local wait_key = PVP.pending_death_reader.wait_key(PVP.GAME.pending_death)
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

-- Builds the PvP win / game-over screen inside the shared MPAPI.end_screen shell. Jokers and decks
-- are read from the view when shown (PVP.finish_screen). PvP hooks this via the create_UIBox_win/
-- game_over overrides below rather than calling the overlay directly, so it keeps its own paused handling.
function PVP.UI.create_UIBox_mp_game_end(has_won)
	G.SETTINGS.paused = false

	return MPAPI.end_screen_uibox({
		won = has_won,
		draw = PVP.GAME.draw,
		title_key = PVP.GAME.end_shown == "by contest" and "k_pvp_contested_title"
			or PVP.GAME.pending_death_screen and "k_pvp_pending_death_title"
			or nil,
		id = has_won and "you_win_UI" or nil,
		body = PVP.UI.end_game_body,
	})
end

-- Pure: which deck View Deck shows for a player. { own = true } for yourself;
-- { cards = <deck string> } for a player whose end of game the view carries
-- (PVP.finish_screen.deck_of answers it); nil while they are still playing or the deck is unknown.
function PVP.UI.deck_to_show(player_id, self_id, deck_of)
	if player_id == nil then return nil end
	if player_id == self_id then return { own = true } end
	local cards = deck_of(player_id)
	if cards and cards ~= "" then return { cards = cards } end
	return nil
end

-- Pure: the index in `players` of the player the end screen opens on. The player picked
-- before, while still listed (closing View Deck rebuilds the screen); else your nemesis
-- (`target_id`); else, with two players, the one who is not you; else `fallback`.
function PVP.UI.end_screen_start_index(players, self_id, kept_id, target_id, fallback)
	local function index_of(id)
		if id == nil then return nil end
		for i, p in ipairs(players) do
			if p.id == id then return i end
		end
		return nil
	end
	local index = index_of(kept_id) or index_of(target_id)
	if index then return index end
	local self_index = index_of(self_id)
	if #players == 2 and self_index then return 3 - self_index end
	return fallback
end

-- Pure: View Deck's tabs, one per player in end-screen order, each { id, name, own,
-- chosen }. The tab of the player picked in the switcher is open first; with no pick
-- (or a pick not in the list), your own tab is.
function PVP.UI.deck_tabs(players, self_id, selected_id)
	local tabs, chosen = {}, nil
	for _, p in ipairs(players or {}) do
		local tab = { id = p.id, name = p.displayName or p.id, own = p.id == self_id }
		tabs[#tabs + 1] = tab
		if p.id == selected_id then chosen = tab end
	end
	if #tabs == 0 then tabs[1] = { id = self_id, own = true } end
	if not chosen then
		for _, tab in ipairs(tabs) do
			if tab.own then chosen = tab break end
		end
	end
	(chosen or tabs[1]).chosen = true
	return tabs
end

-- Frees the off-screen area View Deck built, so no run keeps cards from the last one.
function PVP.UI.clear_shown_deck_area()
	if PVP.UI.shown_deck_area and PVP.UI.shown_deck_area.cards then
		PVP.UI.shown_deck_area:remove()
	end
	PVP.UI.shown_deck_area = nil
end

local delete_run_ref = Game.delete_run
function Game:delete_run()
	PVP.UI.clear_shown_deck_area()
	-- The next match's end screen opens on its own opponent.
	PVP._end_screen_selected_player_id = nil
	PVP._end_screen_selected_player_name = nil
	return delete_run_ref(self)
end

-- The cards View Deck shows for a player, or nil (deck_to_show).
function PVP.UI.player_deck(player_id)
	local show = PVP.UI.deck_to_show(player_id, MPAPI.connection_state.player_id, PVP.finish_screen.deck_of)
	if not show then return nil end
	if show.own then return G.playing_cards end
	-- Build them in a fresh off-screen area, dropping the last one shown.
	PVP.UI.clear_shown_deck_area()
	PVP.UI.shown_deck_area = CardArea(-100, -100, G.CARD_W, G.CARD_H, { type = "deck" })
	local specs =
		PVP.UTILS.parse_deck_string(show.cards, { cards = G.P_CARDS, centers = G.P_CENTERS, seals = G.P_SEALS })
	return PVP.UTILS.build_cards(specs, PVP.UI.shown_deck_area)
end

-- One View Deck tab's contents; tab is an entry of PVP.UI.deck_tabs.
function G.UIDEF.view_player_deck(tab)
	if tab.own then return G.UIDEF.view_deck() end
	local cards = PVP.UI.player_deck(tab.id)
	if not cards then
		-- The same "still playing" line the jokers show.
		local _, _, text = end_game_player_state(tab.id, tab.name)
		return {
			n = G.UIT.ROOT,
			config = { align = "cm", colour = G.C.BLACK, r = 0.1, padding = 0.2, minw = 10, minh = 6 },
			nodes = {
				{
					n = G.UIT.T,
					config = { text = text or "", scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true },
				},
			},
		}
	end
	local playing_cards_ref = G.playing_cards
	G.playing_cards = cards
	local t = G.UIDEF.view_deck()
	G.playing_cards = playing_cards_ref
	return t
end

function G.UIDEF.create_UIBox_view_nemesis_deck()
	local tabs = {}
	local deck_tabs = PVP.UI.deck_tabs(
		end_screen_players(MPAPI.get_current_lobby()),
		MPAPI.connection_state.player_id,
		PVP._end_screen_selected_player_id
	)
	for _, tab in ipairs(deck_tabs) do
		tabs[#tabs + 1] = {
			label = tab.own and localize("k_your_deck")
				or localize({ type = "variable", key = "k_end_player_deck", vars = { tab.name } }),
			chosen = tab.chosen,
			tab_definition_function = G.UIDEF.view_player_deck,
			tab_definition_function_args = tab,
		}
	end
	return create_UIBox_generic_options({
		back_func = "overlay_endgame_menu",
		contents = {
			create_tabs({
				tabs = tabs,
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
