--[[
  Cocktail recipe test.

  A matchmade lobby (Ranked or Casual) carries a fixed Cocktail in its metadata,
  cocktail_recipe = { name, decks }. In that lobby the Cocktail deck forces the
  recipe's decks, whatever the player's own Cocktail settings say, and is named
  and described by it. Without one (no lobby, a private lobby) the player's
  Cocktail settings still apply.

  Run from the repo root:
    luajit tests/unit/cocktail_recipe_test.lua
]]

local noop = function() end
local stub = setmetatable({}, {
	__index = function()
		return noop
	end,
})
SMODS = stub
Back, Card, CardArea, Controller = {}, {}, {}, {}
generate_card_ui = noop
Event = noop

-- Loc text the way the game stores it, and a localize that fills args.nodes
-- for descriptions and returns the name for name_text.
local LOC = {
	b_mp_cocktail = { name = "Cocktail Deck", text = { "Copies the effects", "of 3 other decks" } },
	b_mp_cocktail_recipe = { name = "Cocktail Deck", text = { "#1#", "#2#", "#3#" } },
	b_red = { name = "Red Deck" },
	b_blue = { name = "Blue Deck" },
	b_abandoned = { name = "Abandoned Deck" },
	b_erratic = { name = "Erratic Deck" },
	b_checkered = { name = "Checkered Deck" },
}
function localize(args)
	local entry = LOC[args.key]
	if args.type == "name_text" then
		return entry.name
	end
	for _, line in ipairs(entry.text) do
		args.nodes[#args.nodes + 1] = (line:gsub("#(%d)#", function(n)
			return args.vars[tonumber(n)]
		end))
	end
end

MPAPI = { Party = { KIND = "party" } }
PVP = {
	id = "MultiplayerPvP",
	-- The player's own Cocktail: only Red in the pool, nothing forced, shown.
	config = { cocktail = "1000000S" },
	LOBBY = { deck = {}, config = {} },
	PVP_GAMEMODES = { pvp_nemesis = { ruleset = "ruleset_mp_expanded", gamemode = "gamemode_mp_attrition" } },
}
G = {
	E_MANAGER = { add_event = noop },
	P_CENTERS = {
		b_red = { set = "Back", order = 1 },
		b_blue = { set = "Back", order = 2 },
		b_yellow = { set = "Back", order = 3 },
		b_green = { set = "Back", order = 4 },
		b_abandoned = { set = "Back", order = 9 },
		b_checkered = { set = "Back", order = 10 },
		b_erratic = { set = "Back", order = 15 },
	},
}

dofile("pvp_api/flow.lua")
dofile("objects/decks/ZZ_cocktail.lua")
G.P_CENTERS.b_mp_cocktail = { set = "Back", order = 99, deck_blacklist = { b_mp_cocktail = true }, mod_whitelist = {} }

local failures = 0
local function check(cond, msg)
	if cond then
		print("PASS: " .. msg)
	else
		failures = failures + 1
		print("FAIL: " .. msg)
	end
end

-- Joins a lobby whose metadata is `meta`, as the metadata mirror does.
local function join(meta)
	PVP.LOBBY.code = "ABCDE"
	PVP.LOBBY.deck.cocktail = ""
	PVP.LOBBY.deck.cocktail_recipe = meta.cocktail_recipe
end
local function leave()
	PVP.LOBBY.code = nil
	PVP.LOBBY.deck.cocktail = nil
end
local function description()
	local nodes = {}
	localize({ type = "descriptions", set = "Back", key = "b_mp_cocktail", nodes = nodes, vars = {} })
	return nodes
end

print("-- the lobby metadata --")
local A = PVP.LobbyAccess
local recipe = PVP.pvp_lobby_metadata("pvp_nemesis", A.RANKED).cocktail_recipe
check(recipe and recipe.name == "Bean's Cocktail", "a Ranked lobby carries Bean's Cocktail")
check(
	recipe and #recipe.decks == 3 and recipe.decks[1] == "b_abandoned" and recipe.decks[2] == "b_erratic" and recipe.decks[3] == "b_checkered",
	"Bean's Cocktail is Abandoned, Erratic and Checkered"
)
check(PVP.pvp_lobby_metadata("pvp_nemesis", A.CASUAL).cocktail_recipe == recipe, "a Casual lobby carries it too")
check(PVP.pvp_lobby_metadata("pvp_nemesis", A.PRIVATE).cocktail_recipe == nil, "a private lobby carries none")
check(PVP.pvp_lobby_metadata("pvp_nemesis", A.PRACTICE).cocktail_recipe == nil, "practice carries none")

print()
print("-- a lobby with a recipe --")
join(PVP.pvp_lobby_metadata("pvp_nemesis", A.RANKED))
local decks, forced = PVP.get_cocktail_decks(true)
check(#decks == 0, "no random pool")
check(
	#forced == 3 and forced[1] == "b_abandoned" and forced[2] == "b_erratic" and forced[3] == "b_checkered",
	"the recipe's decks are all forced"
)
forced[1] = "b_red"
check(select(2, PVP.get_cocktail_decks(true))[1] == "b_abandoned", "the recipe cannot be edited through the returned list")
check(#PVP.get_cocktail_decks(false) == 7, "the full deck list (for the settings screen) is unchanged")
check(localize({ type = "name_text", set = "Back", key = "b_mp_cocktail" }) == "Bean's Cocktail", "named by the recipe")
local nodes = description()
check(
	#nodes == 3 and nodes[1] == "Abandoned Deck" and nodes[2] == "Erratic Deck" and nodes[3] == "Checkered Deck",
	"described by its decks' names"
)
check(localize({ type = "name_text", set = "Back", key = "b_red" }) == "Red Deck", "other decks are untouched")

print()
print("-- a recipe from a newer server --")
join({ cocktail_recipe = { name = "Weekly", decks = { "b_mp_unknown", "b_red", "b_blue", "b_yellow", "b_green" } } })
forced = select(2, PVP.get_cocktail_decks(true))
check(#forced == 3 and forced[1] == "b_red", "unknown decks are dropped and at most 3 mixed")
join({ cocktail_recipe = { decks = { "b_red", "b_blue" } } })
check(localize({ type = "name_text", set = "Back", key = "b_mp_cocktail" }) == "Cocktail Deck", "no name keeps the usual one")
nodes = description()
check(nodes[1] == "Red Deck" and nodes[2] == "Blue Deck" and nodes[3] == "", "two decks fill two lines")
join({ cocktail_recipe = { name = "Empty", decks = { "b_mp_unknown" } } })
check(PVP.cocktail_recipe() == nil, "a recipe with no known decks is ignored")

print()
print("-- no recipe --")
join(PVP.pvp_lobby_metadata("pvp_nemesis", A.PRIVATE))
check(PVP.cocktail_recipe() == nil, "a private lobby plays the player's own Cocktail")
join(PVP.pvp_lobby_metadata("pvp_nemesis", A.RANKED))
leave()
decks, forced = PVP.get_cocktail_decks(true)
check(#decks == 1 and decks[1] == "b_red" and #forced == 0, "after leaving, the player's own settings apply")
check(localize({ type = "name_text", set = "Back", key = "b_mp_cocktail" }) == "Cocktail Deck*", "the usual name, marked edited")
nodes = description()
check(#nodes == 2 and nodes[1] == "Copies the effects", "the usual description")

print()
if failures == 0 then
	print("ALL PASS")
else
	print(failures .. " FAIL")
	os.exit(1)
end
