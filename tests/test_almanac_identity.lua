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
local ready_localize = localize
localize = function() error("queue copy must not localize before mod localization loads") end
dofile("ui/main_menu/find_game.lua")
localize = ready_localize
local page = PVP.build_find_game_ui("ranked")
local items = page.definition.nodes[2].items
local almanac = items[#items]
check(almanac.id == "almanac_preview", "Almanac preview appears in Ranked")
check(almanac.name_plate.lines == "Almanac", "queue is named Almanac")
check(
	table.concat(almanac.description.lines, " ")
		== "Your deck grows. The rules get worse.",
	"approved queue copy"
)
check(#almanac.description.lines == 2, "queue blurb stays two lines")
for _, line in ipairs(almanac.description.lines) do
	check(#line <= 22, "queue copy stays hand-wrapped for the narrow pillar")
end
local button = almanac.select.nodes[1]
check(button.config.button == nil, "preview cannot queue")
check(button.nodes[1].config.text == dictionary.k_coming_soon, "preview stays Coming Soon")
check(almanac.stat_box == nil, "preview has no live matchmaking counts")
local explanation = almanac.extra.nodes[1].nodes[1]
check(explanation.config.button == "pvp_almanac_explanation", "preview opens Almanac rules")
check(not explanation.config.one_press, "Almanac explanation can be reopened without rebuilding the page")
check(explanation.nodes[1].nodes[1].config.text == dictionary.k_almanac_how_to_play, "explanation is labelled How to play")
check(items[2].extra.nodes[1].nodes[1].config.button == "the_order_open", "The Order still opens its own explanation")
local overlay, sprite
G.ASSET_ATLAS = { mp_almanac_back = {} }
G.UIT.O = "object"
Sprite = function(x, y, w, h, atlas, pos)
	sprite = { width = w, height = h, atlas = atlas, pos = pos }
	return sprite
end
create_UIBox_generic_options = identity
G.FUNCS.overlay_menu = function(args) overlay = args.definition end
local base_localize = localize
local localized = {}
localize = function(args)
	if type(args) ~= "table" then return base_localize(args) end
	localized[#localized + 1] = args.key
	check(args.default_col == G.C.UI.TEXT_LIGHT, "explanation text uses the overlay's light text")
	for _, line in ipairs(dofile("localization/en-us.lua").descriptions.Other[args.key].text) do
		args.nodes[#args.nodes + 1] = { { n = G.UIT.T, config = { text = line } } }
	end
end
G.FUNCS.pvp_almanac_explanation()
check(overlay.snap_back == true, "overlay uses the standard Back / Escape navigation")
check(sprite.atlas == G.ASSET_ATLAS.mp_almanac_back, "overlay uses the Almanac art")
check(math.abs(sprite.width / sprite.height - 71 / 95) < 0.001, "deck art keeps its aspect ratio")
check(table.concat(localized, ",") == "mp_almanac_deck_rules,mp_almanac_boss_rules", "overlay explains both deck and boss choices")
check(overlay.contents[1].nodes[1].config.text == "Almanac", "overlay is titled Almanac")
localize = base_localize
local casual = PVP.build_find_game_ui("casual")
for _, item in ipairs(casual.definition.nodes[2].items) do
	check(item.id ~= "almanac_preview", "Almanac is not listed in Casual")
end
print("Almanac identity: " .. checks .. " checks passed")
