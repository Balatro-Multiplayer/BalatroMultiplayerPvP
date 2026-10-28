-- The Practice and Create Lobby pillar pages (MPAPI page pvp_game_select), on the same
-- MPAPI pillar-row layout as Find Game (ui/main_menu/find_game.lua) and SPDRN's gamemode
-- select (BalatroMultiplayerSpeed/ui/main_menu/game_select.lua). self.params.intent picks
-- which list is built: 'practice' (one pillar per ruleset, solo) or 'create_lobby' (one
-- pillar per gamemode, private lobby). Each pillar's button routes to the existing per-mode
-- handlers in ui/pvp_main_menu.lua, unchanged.

local PLACEHOLDER_CHIP_ROW = 0

-- Practice: one pillar per ruleset; key is the ruleset key and the name is its display name.
local PRACTICE_MODES = {
	{ key = PVP.RulesetKey.BALANCED,
		desc = { "Minor balance", "changes for MP" }, button = "mp_pvp_practice_balanced", colour = G.C.BLUE },
	{ key = PVP.RulesetKey.EXPANDED,
		desc = { "Standardized and", "balanced for MP" }, button = "mp_pvp_practice_expanded", colour = G.C.PURPLE },
	{ key = PVP.RulesetKey.VANILLA,
		desc = { "Normal Balatro", "with PvP blinds" }, button = "mp_pvp_practice_vanilla", colour = G.C.GREEN },
	{ key = PVP.RulesetKey.SMALLWORLD,
		desc = { "75% of cards are", "banned at random" }, button = "mp_pvp_practice_smallworld", colour = G.C.RED },
}

-- key is the gamemode key PVP.pvp_create_private_lobby takes (pvp_api/flow.lua). The Party
-- pillar's key is PVP.LobbyAccess.PARTY: it has no gamemode (pvp_api/party_lobby.lua). A
-- function because pvp_api (PVP.LobbyAccess) loads after the ui files.
local function lobby_modes()
	return {
		{ key = "pvp_nemesis", name = "Nemesis",
			desc = { "Face a different", "Nemesis every ante" }, button = "mp_pvp_create_lobby_nemesis", colour = G.C.BLUE },
		{ key = "pvp_royale", name = { "Battle", "Royale" },
			desc = { "Free for all;", "bottom half lose" }, button = "mp_pvp_create_lobby_royale", colour = G.C.PURPLE },
		{ key = "pvp_manhunt", name = "Manhunt",
			desc = { "Hunters team up", "to stop a Runner" }, button = "mp_pvp_create_lobby_manhunt", colour = G.C.RED },
		{ key = "pvp_teams", name = "Teams",
			desc = { "Team vs team;", "best score wins" }, button = "mp_pvp_create_lobby_teams", colour = G.C.GREEN },
		{ key = PVP.LobbyAccess.PARTY, name_key = "k_party",
			desc_keys = { "k_party_desc_1", "k_party_desc_2" }, button = "mp_pvp_create_lobby_party", colour = G.C.ORANGE },
	}
end

-- Plain Sprite, same placeholder chip as find_game.lua.
local function build_chip_sprite()
	return Sprite(0, 0, 1.1, 1.1, G.ANIMATION_ATLAS["mp_player_blind_chip"], { x = PLACEHOLDER_CHIP_ROW, y = 0 })
end

local function stat_box_for(mode, intent)
	if intent == "create_lobby" and mode.key == PVP.LobbyAccess.PARTY then
		local Group = MPAPI.matchmaking.group
		return MPAPI.ui_pillar_stat_box({ label = localize("b_players"), value = Group.MIN_SIZE .. "-" .. Group.MAX_SIZE, value_colour = G.C.MONEY })
	end
	if intent == "create_lobby" then
		local gm = MPAPI.GameModes[mode.key]
		local players = gm and (tostring(gm:get_min_players(MPAPI.LobbyType.PRIVATE)) .. "-" .. tostring(gm:get_max_players(MPAPI.LobbyType.PRIVATE))) or "?"
		return MPAPI.ui_pillar_stat_box({ label = localize("b_players"), value = players, value_colour = G.C.MONEY })
	end
	-- Practice is always solo.
	return MPAPI.ui_pillar_stat_box({ label = localize("b_players"), value = "1", value_colour = G.C.MONEY })
end

local function pillar_name(mode, intent)
	if intent ~= "create_lobby" then
		return PVP.ruleset_display_name(mode.key)
	end
	return mode.name_key and localize(mode.name_key) or mode.name
end

local function pillar_description(mode)
	if not mode.desc_keys then
		return mode.desc
	end
	local lines = {}
	for i, key in ipairs(mode.desc_keys) do
		lines[i] = localize(key)
	end
	return lines
end

local function build_items(intent)
	local modes = intent == "create_lobby" and lobby_modes() or PRACTICE_MODES
	local items = {}
	for _, mode in ipairs(modes) do
		items[#items + 1] = {
			id = mode.key,
			icon = build_chip_sprite(),
			select = MPAPI.ui_pillar_select_button({
				label = intent == "create_lobby" and "CREATE" or "START",
				button = mode.button,
			}),
			name_plate = MPAPI.ui_pillar_name_plate({
				lines = pillar_name(mode, intent),
				bg_colour = mix_colours(mode.colour, G.C.BLACK, 0.3),
				outline_colour = mode.colour,
			}),
			description = MPAPI.ui_pillar_description_box({ lines = pillar_description(mode), minh = 1.3 }),
			stat_box = stat_box_for(mode, intent),
		}
	end
	return items
end

-- Builds the page for `intent` ('practice' or 'create_lobby', default 'practice'). The
-- caller (pvp_game_select's MPAPI.Page registration, core.lua) disposes the returned
-- pillar row with the page, so the chip icons get removed.
function PVP.build_game_select_ui(intent)
	intent = intent == "create_lobby" and "create_lobby" or "practice"
	local pillar_row = MPAPI.ui_pillar_row({ items = build_items(intent) })
	local definition = {
		n = G.UIT.ROOT,
		config = { align = "tm", colour = G.C.CLEAR },
		nodes = { pillar_row.row_node },
	}
	return { definition = definition, dispose = function(self)
		pillar_row:dispose()
	end }
end
