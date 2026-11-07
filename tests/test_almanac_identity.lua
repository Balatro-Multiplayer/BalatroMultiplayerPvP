-- The deck, atlas and save IDs all use the Almanac name.
local checks = 0
local function check(value, message)
	assert(value, message)
	checks = checks + 1
end

local back
SMODS = {
	Atlas = function() end,
	Back = function(definition) back = definition end,
}
dofile("objects/decks/03_almanac.lua")
check(back.key == "almanac" and back.atlas == "mp_almanac_back", "deck and atlas IDs use the Almanac name")
check(back.loc_txt.name == "Almanac", "deck is named Almanac")
local text = table.concat(back.loc_txt.text, " "):gsub("{[^}]*}", "")
check(text == "At Antes 2, 3, 5 and 7, choose 1 of 3 Decks. Keep their effects.", "approved deck copy")

local dictionary = dofile("localization/en-us.lua").misc.dictionary
localize = function(key)
	if type(key) == "table" then return key.key end
	return dictionary[key] or key
end
local function identity(value) return value end
HEX = identity
G = {
	FUNCS = {},
	UIT = { ROOT = "root", R = "row", C = "column", T = "text" },
	C = {
		BLUE = {}, PURPLE = {}, GREEN = {}, RED = {}, ORANGE = {}, BLACK = {}, CLEAR = {},
		WHITE = {}, L_BLACK = {}, UI = { TEXT_LIGHT = {}, TEXT_INACTIVE = {}, BACKGROUND_INACTIVE = {} },
	},
	ANIMATION_ATLAS = {},
}
PVP = {
	RulesetKey = { VANILLA = "vanilla", BALANCED = "balanced", EXPANDED = "expanded", MAJORLEAGUE = "mlba", SMALLWORLD = "smallworld" },
	ruleset_display_name = identity,
	ranked_ticket = identity,
	LobbyAccess = { RANKED = "ranked", CASUAL = "casual", RANKED_PREFIX = "ranked_" },
	_active_queue_matches = function() return false end,
	_is_queue_active = function() return false end,
}
MPAPI = {
	QueueKind = { RANKED = "ranked", CASUAL = "casual" },
	can_queue = function() return true end,
	ui_element = function(build)
		return { node = build(), update = function() end }
	end,
	ui_pillar_name_plate = identity,
	ui_pillar_description_box = identity,
	ui_embossed_box = identity,
	ui_pillar_row = function(spec)
		return { row_node = spec, dispose = function() end }
	end,
}
Sprite = function() return {} end
mix_colours = identity
UIBox_button = identity
dofile("ui/main_menu/_mode_chips.lua")
dofile("ui/main_menu/find_game.lua")
local page = PVP.build_find_game_ui("ranked")
local items = page.definition.nodes[2].items
local almanac = items[#items]
check(almanac.id == "almanac_preview", "Almanac preview appears in Ranked")
check(almanac.name_plate.lines == "Almanac", "queue is named Almanac")
check(
	table.concat(almanac.description.lines, " ")
		== "Build your Deck’s rules as you go. Before each PvP from Ante 3, both players choose a rule that affects them both.",
	"approved queue copy"
)
for _, line in ipairs(almanac.description.lines) do
	check(#line <= 21, "queue copy stays hand-wrapped for the narrow pillar")
end
local button = almanac.select.nodes[1]
check(button.config.button == nil, "preview cannot queue")
check(button.nodes[1].config.text == dictionary.k_coming_soon, "preview stays Coming Soon")
check(almanac.stat_box == nil, "preview has no live matchmaking counts")
local casual = PVP.build_find_game_ui("casual")
for _, item in ipairs(casual.definition.nodes[2].items) do
	check(item.id ~= "almanac_preview", "Almanac is not listed in Casual")
end
print("Almanac identity: " .. checks .. " checks passed")
