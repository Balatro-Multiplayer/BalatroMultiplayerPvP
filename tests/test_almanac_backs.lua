local checks, created, removed, draws = 0, 0, 0, 0
local function check(value, message)
	assert(value, message)
	checks = checks + 1
end
local function object()
	created = created + 1
	return {
		states = { collide = {}, hover = {}, drag = {} },
		role = {},
		remove = function()
			removed = removed + 1
		end,
		draw = function()
			draws = draws + 1
		end,
		draw_shader = function()
			draws = draws + 1
		end,
	}
end
Sprite = function()
	return object()
end
UIBox = function()
	return object()
end
UIBox_button = function(args)
	return args
end
localize = function(args)
	if type(args) == "string" then return args end
	return args.key
end
create_tabs = function(args)
	return args
end
Game = { update = function() end }
CardArea = {
	remove = function()
		return "removed"
	end,
}
PVP = { ALMANAC_DRAFT = { definitions = {} } }
local step
SMODS = {
	DrawStep = function(definition)
		step = definition
	end,
}
G = {
	STAGE = 1,
	STAGES = { RUN = 1 },
	SETTINGS = {},
	GAME = { almanac_draft = { acquired = {} } },
	P_CENTERS = {},
	CARD_W = 2,
	CARD_H = 3,
	ASSET_ATLAS = { centers = {} },
	UIT = { ROOT = "root", R = "row", C = "column", T = "text", O = "object" },
	C = { BLACK = {}, WHITE = {}, CLEAR = {} },
	CONTROLLER = { focused = {} },
	UIDEF = { view_deck = function() end },
	FUNCS = {},
}
G.deck = { cards = {}, states = { hover = {} } }
local top = { area = G.deck, states = { hover = {} }, T = { w = 2, h = 3, x = 7 }, children = { back = {} } }
G.deck.cards = { top, { area = G.deck } }
for i = 1, 9 do
	local key = "deck" .. i
	G.P_CENTERS[key] = { pos = { x = i, y = 0 } }
	PVP.ALMANAC_DRAFT.definitions[key] = { lines = { "Rule " .. i } }
end
dofile("ui/almanac_backs.lua")
local V = PVP.ALMANAC_DRAFT.visuals
V.update(0.1)
check(#V.sprites == 0, "zero-deck start has no cosmetic layers")
G.GAME.almanac_draft.acquired = { "deck1", "deck2", "deck3", "deck4" }
V.update(0)
check(#V.sprites == 4 and V.badge == nil, "four decks are all visible without a badge")
check(V.arrival == 0, "new acquisition starts arrival")
local cached = created
V.update(0.1)
check(created == cached, "no per-frame sprite allocation")
check(top.T.x == 7 and G.deck.cards[1] == top, "card transforms and order untouched")
step.func(G.deck.cards[2])
check(draws == 0, "do not draw layers on buried cards")
step.func(top)
check(draws == 8, "four shadows and four backs")
local x = V.offset(1, 3, 2, 3)
top.states.hover.is = true
V.update(0.1)
check(V.fan > 0 and V.offset(1, 3, 2, 3) < x, "hover fans inward")
G.SETTINGS.reduced_motion = true
V.update(0.1)
check(V.fan == 0 and V.arrival == 1, "reduced motion is static")
G.VIEWING_DECK = true
local before = draws
step.func(top)
check(draws == before, "no layers behind deck viewer")
G.VIEWING_DECK = nil
G.deck.cards = {}
step.func(top)
check(draws == before, "empty pile draws no phantom cards")
G.deck.cards = { top }
local args = { tabs = { { chosen = true, label = "Full", tab_definition_function = G.UIDEF.view_deck } } }
local extended = create_tabs(args)
check(
	#extended.tabs == 2 and extended.tabs[2].tab_definition_function == V.collection,
	"native viewer gains collection tab"
)
check(extended.tabs[2].label == "k_almanac_decks", "collection tab uses the localized Almanac name")
check(#args.tabs == 1 and args.tabs[1].chosen, "caller-owned tabs untouched")
check(#create_tabs(extended).tabs == 2, "no duplicate tab")
local other = { tabs = { { label = "Settings" } } }
check(create_tabs(other) == other, "unrelated tabs unchanged")
for i = 5, 8 do
	G.GAME.almanac_draft.acquired[i] = "deck" .. i
end
V.update(0)
check(#V.sprites == 8 and V.badge == nil, "eight decks all visible without overflow")
V.fan = 1
local fan_x, fan_y, fan_r = V.offset(1, 8, 2, 3)
check(math.abs(fan_x) <= 2 and math.abs(fan_y) <= 0.75 and math.abs(fan_r) <= 0.3, "eight-deck fan has bounded spread")
G.GAME.almanac_draft.acquired[9] = "deck9"
V.update(0)
check(#V.sprites == 8 and V.badge ~= nil, "ninth acquisition creates overflow badge")
V.page = 1
local page1 = V.collection()
check(#page1.nodes == 4, "first page has title, two rows, pagination")
V.page = 2
local page2 = V.collection()
check(#page2.nodes[2].nodes == 3, "second page contains remaining three")
G.FUNCS.deck_info = function()
	local result = create_tabs(args)
	check(not result.tabs[1].chosen and result.tabs[2].chosen, "pagination keeps collection selected")
	V.collection()
end
G.FUNCS.pvp_almanac_next_page()
check(V.page == 2 and not V.choose_collection, "page bounds and ephemeral selection flag")
local previous = removed
check(CardArea.remove(G.deck) == "removed", "original area cleanup preserved")
check(removed == previous + 9 and V.deck == nil, "cached sprites and badge released")
V.update(0)
check(V.arrival == 1, "restored cache does not replay acquisition animation")
G.GAME.almanac_draft = nil
V.update(0)
check(#V.sprites == 0 and not V.badge, "ordinary run clears visuals")
check(create_tabs(args) == args, "ordinary deck viewer untouched")
print("Almanac backs: " .. checks .. " checks passed")
