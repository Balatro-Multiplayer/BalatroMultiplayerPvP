-- The lobby's options screen (previously a no-op placeholder, see ui/lobby/code.lua):
-- a host-only ruleset picker (private lobbies only -- ranked/casual matchmaking
-- already commits to a specific ruleset by which queue option was picked, see
-- pvp_api/queue.lua), plus Manhunt's Hunter/Runner or Teams' A/B role picker when
-- applicable (any lobby kind -- a casual matchmaking-formed Manhunt/Teams match
-- still needs its players to pick a role before the match can start).

local RULESET_KEYS = {
	PVP.RulesetKey.VANILLA,
	PVP.RulesetKey.BALANCED,
	PVP.RulesetKey.EXPANDED,
	PVP.RulesetKey.SMALLWORLD,
}
local DEFAULT_RULESET_KEY = PVP.RulesetKey.BALANCED -- what every gamemode key creates a lobby on.

local function ruleset_labels()
	local labels = {}
	for i, key in ipairs(RULESET_KEYS) do
		labels[i] = PVP.ruleset_display_name(key)
	end
	return labels
end

local function ruleset_option(ruleset_key)
	for i, key in ipairs(RULESET_KEYS) do
		if key == ruleset_key then
			return i
		end
	end
end

local function current_ruleset_option()
	return ruleset_option(PVP.LOBBY.config.ruleset) or ruleset_option(DEFAULT_RULESET_KEY)
end

local function publish_options()
	local lobby = MPAPI.get_current_lobby()
	if lobby and lobby.is_host then
		lobby:set_metadata(PVP.pvp_lobby_metadata(PVP._pvp_gamemode, PVP._pvp_kind))
	end
end

local function is_host()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.is_host
end

local function option_row(node)
	return { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = { node } }
end

local function toggle_row(id, label_key, key)
	return option_row(MPAPI.disableable_toggle({
		id = id,
		label = localize(label_key),
		ref_table = PVP.LOBBY.config,
		ref_value = key,
		callback = publish_options,
		enabled = is_host,
	}).node)
end

-- Number-valued options: key -> { values = { ... }, suffix }. Each gets a G.FUNCS callback.
local NUMBER_OPTIONS = {
	starting_lives = { values = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 } },
	pvp_start_round = { values = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 } },
	timer_base_seconds = { values = { 30, 60, 90, 120, 150, 180, 210, 240 }, suffix = "s" },
	timer_increment_seconds = { values = { 0, 30, 60, 90, 120, 150, 180 }, suffix = "s" },
	pvp_countdown_seconds = { values = { 0, 3, 5, 10 }, suffix = "s" },
}

for key, def in pairs(NUMBER_OPTIONS) do
	G.FUNCS["mp_pvp_change_" .. key] = function(e)
		PVP.LOBBY.config[key] = def.values[e.to_key]
		publish_options()
	end
end

local function number_row(key, label_key)
	local def = NUMBER_OPTIONS[key]
	local labels, current = {}, 1
	for i, v in ipairs(def.values) do
		labels[i] = tostring(v) .. (def.suffix or "")
		if v == PVP.LOBBY.config[key] then
			current = i
		end
	end
	return option_row(MPAPI.disableable_option_cycle({
		id = "mp_pvp_opt_" .. key,
		label = localize(label_key),
		options = labels,
		current_option = current,
		opt_callback = "mp_pvp_change_" .. key,
		w = 4,
		scale = 0.6,
		enabled = is_host,
	}).node)
end

local DECK_MODES = { PVP.DeckMode.SELECT, PVP.DeckMode.DRAFT }

local function deck_mode_row()
	local current = (PVP.LOBBY.config.deck_mode == PVP.DeckMode.DRAFT) and 2 or 1
	return option_row(MPAPI.disableable_option_cycle({
		id = "mp_pvp_deck_mode",
		label = "Deck Mode",
		options = { "Select", "Draft" },
		current_option = current,
		opt_callback = "mp_pvp_change_deck_mode",
		w = 4,
		scale = 0.6,
		-- The Draft runs on the server, so it needs a server-refereed lobby.
		enabled = function()
			local lobby = MPAPI.get_current_lobby()
			return lobby and lobby.is_host and MPAPI.has_server_referee(lobby)
		end,
	}).node)
end

local function tab_root(rows)
	return {
		n = G.UIT.ROOT,
		config = { emboss = 0.05, minh = 6, r = 0.1, minw = 8, align = "tm", padding = 0.2, colour = G.C.BLACK },
		nodes = rows,
	}
end

local function ruleset_row(lobby)
	return option_row(MPAPI.disableable_option_cycle({
		id = "mp_pvp_ruleset_pick",
		label = "Ruleset",
		options = ruleset_labels(),
		current_option = current_ruleset_option(),
		opt_callback = "mp_pvp_change_ruleset",
		w = 4,
		scale = 0.6,
		enabled = function()
			return lobby and lobby.is_host
		end,
	}).node)
end

local function lobby_tab(lobby)
	local rows = {}
	if PVP._pvp_kind == PVP.LobbyAccess.PRIVATE then
		rows[#rows + 1] = ruleset_row(lobby)
		rows[#rows + 1] = deck_mode_row()
		rows[#rows + 1] = toggle_row("mp_pvp_trap_cards", "k_pvp_lobby_trap_cards", "trap_cards")
		rows[#rows + 1] = number_row("starting_lives", "b_opts_lives")
		rows[#rows + 1] = toggle_row("mp_pvp_multiplayer_jokers", "b_opts_multiplayer_jokers", "multiplayer_jokers")
		rows[#rows + 1] = toggle_row("mp_pvp_normal_bosses", "b_opts_normal_bosses", "normal_bosses")
		rows[#rows + 1] = toggle_row("mp_pvp_hide_score", "b_opts_hide_score", "hide_score_until_played")
	end
	return rows
end

local function gameplay_tab()
	return {
		toggle_row("mp_pvp_gold_on_life_loss", "b_opts_cb_money", "gold_on_life_loss"),
		toggle_row("mp_pvp_no_gold_on_round_loss", "b_opts_no_gold_on_loss", "no_gold_on_round_loss"),
		toggle_row("mp_pvp_death_on_round_loss", "b_opts_death_on_loss", "death_on_round_loss"),
		toggle_row("mp_pvp_the_order", "b_opts_the_order", "the_order"),
		toggle_row("mp_pvp_preview_disabled", "b_opts_disable_preview", "preview_disabled"),
		PVP.is_layer_active("smallworld")
				and toggle_row("mp_pvp_smallerworld", "b_opts_smallerworld", "smallerworld")
			or nil,
	}
end

local function timer_tab()
	return {
		toggle_row("mp_pvp_timer", "b_opts_timer", "timer"),
		number_row("timer_base_seconds", "k_opts_pvp_timer"),
		number_row("timer_increment_seconds", "k_opts_pvp_timer_increment"),
		number_row("pvp_start_round", "k_opts_pvp_start_round"),
		number_row("pvp_countdown_seconds", "k_opts_pvp_countdown_seconds"),
	}
end

local function player_rows()
	local rows = {}
	local lobby = MPAPI.get_current_lobby()
	if PVP.LOBBY.config.manhunt then
		rows[#rows + 1] = option_row(MPAPI.disableable_option_cycle({
			id = "mp_pvp_manhunt_role",
			label = "Role",
			options = { "Hunter", "Runner" },
			current_option = (PVP.LOBBY.team_id == "RUNNER") and 2 or 1,
			opt_callback = "mp_pvp_change_manhunt_role",
			w = 4,
			scale = 0.6,
			enabled = function()
				return PVP.LOBBY.team_id == "RUNNER" or not PVP.is_runner_taken()
			end,
		}).node)
		if lobby and lobby.is_host then
			rows[#rows + 1] = option_row(create_option_cycle({
				id = "mp_pvp_manhunt_hunter_lives",
				label = "Hunter Lives",
				options = { "7", "8", "9", "10", "11", "12", "13", "14", "15", "16" },
				current_option = (PVP.LOBBY.config.manhunt_hunter_lives or 7) - 6,
				opt_callback = "mp_pvp_change_manhunt_hunter_lives",
				w = 4,
				scale = 0.6,
			}))
		end
	elseif PVP.LOBBY.config.team_based then
		rows[#rows + 1] = option_row(create_option_cycle({
			id = "mp_pvp_team_pick",
			label = "My Team",
			options = { "Team A", "Team B" },
			current_option = (PVP.LOBBY.team_id == "B") and 2 or 1,
			opt_callback = "mp_pvp_change_team",
			w = 4,
			scale = 0.6,
		}))
	end
	return rows
end

function PVP.build_lobby_options()
	local lobby = MPAPI.get_current_lobby()
	local tabs = {}
	local function add_tab(label, rows_fn)
		tabs[#tabs + 1] = {
			label = label,
			chosen = #tabs == 0,
			tab_definition_function = function()
				return tab_root(rows_fn())
			end,
		}
	end

	if PVP._pvp_kind == PVP.LobbyAccess.PRIVATE then
		add_tab("Lobby", function()
			local rows = lobby_tab(lobby)
			for _, r in ipairs(player_rows()) do
				rows[#rows + 1] = r
			end
			return rows
		end)
		add_tab("Gameplay", gameplay_tab)
		add_tab("Timers", timer_tab)
	else
		-- Matchmade lobbies: only each player's own role/team pick.
		add_tab("Lobby", player_rows)
	end

	return create_UIBox_generic_options({
		contents = { create_tabs({ tabs = tabs, snap_to_nav = true }) },
	})
end

G.FUNCS.mp_pvp_change_deck_mode = function(e)
	PVP.LOBBY.config.deck_mode = DECK_MODES[e.to_key]
	publish_options()
	MPAPI.refresh_current_view()
end

G.FUNCS.mp_pvp_change_ruleset = function(e)
	PVP.LOBBY.config.ruleset = RULESET_KEYS[e.to_key]
	local lobby = MPAPI.get_current_lobby()
	if lobby and lobby.is_host then
		lobby:set_metadata(PVP.pvp_lobby_metadata(PVP._pvp_gamemode, PVP._pvp_kind))
	end
end

G.FUNCS.mp_pvp_change_manhunt_role = function(e)
	PVP.pvp_set_team((e.to_key == 2) and "RUNNER" or "HUNTER")
end

G.FUNCS.mp_pvp_change_team = function(e)
	PVP.pvp_set_team((e.to_key == 2) and "B" or "A")
end

G.FUNCS.mp_pvp_change_manhunt_hunter_lives = function(e)
	PVP.LOBBY.config.manhunt_hunter_lives = e.to_key + 6
	local lobby = MPAPI.get_current_lobby()
	if lobby and lobby.is_host then
		lobby:set_metadata(PVP.pvp_lobby_metadata(PVP._pvp_gamemode, PVP._pvp_kind))
	end
end
