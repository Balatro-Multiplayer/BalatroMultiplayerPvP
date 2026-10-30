--[[
  Bean's Cocktail test.

  In matchmade games (the ranked Draft) the Cocktail deck is always Bean's
  Cocktail: Abandoned, Erratic and Checkered, all three forced, whatever the
  player's own Cocktail settings say. Its name and description say so. Outside
  matchmaking the player's Cocktail settings still apply.

  Run from the repo root:
    luajit tests/unit/bean_cocktail_test.lua
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
	b_mp_cocktail_bean = { name = "Bean's Cocktail", text = { "Abandoned: no Face Cards", "Erratic: random Ranks and Suits", "Checkered: only Spades and Hearts" } },
	b_red = { name = "Red Deck" },
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

local matchmaking = false
PVP = {
	id = "MultiplayerPvP",
	is_matchmaking = function()
		return matchmaking
	end,
	-- The player's own Cocktail: only Red in the pool, nothing forced, shown.
	config = { cocktail = "1000S" },
	LOBBY = { deck = {} },
}
G = {
	E_MANAGER = { add_event = noop },
	P_CENTERS = {
		b_red = { set = "Back", order = 1 },
		b_blue = { set = "Back", order = 2 },
		b_yellow = { set = "Back", order = 3 },
		b_green = { set = "Back", order = 4 },
	},
}

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

print("-- matchmade game --")
matchmaking = true
local decks, forced = PVP.get_cocktail_decks(true)
check(#decks == 0, "no random pool")
check(
	#forced == 3 and forced[1] == "b_abandoned" and forced[2] == "b_erratic" and forced[3] == "b_checkered",
	"Abandoned, Erratic and Checkered are all forced"
)
forced[1] = "b_red"
check(select(2, PVP.get_cocktail_decks(true))[1] == "b_abandoned", "the recipe cannot be edited through the returned list")
local all = PVP.get_cocktail_decks(false)
check(#all == 4, "the full deck list (for the settings screen) is unchanged")
check(localize({ type = "name_text", set = "Back", key = "b_mp_cocktail" }) == "Bean's Cocktail", "name is Bean's Cocktail")
local nodes = {}
localize({ type = "descriptions", set = "Back", key = "b_mp_cocktail", nodes = nodes, vars = {} })
check(#nodes == 3, "description has only Bean's Cocktail lines, got " .. #nodes)
check(
	nodes[1]:find("^Abandoned") and nodes[2]:find("^Erratic") and nodes[3]:find("^Checkered"),
	"description has a line per deck"
)
check(localize({ type = "name_text", set = "Back", key = "b_red" }) == "Red Deck", "other decks are untouched")

print()
print("-- any other game --")
matchmaking = false
decks, forced = PVP.get_cocktail_decks(true)
check(#decks == 1 and decks[1] == "b_red" and #forced == 0, "the player's own Cocktail settings apply")
check(localize({ type = "name_text", set = "Back", key = "b_mp_cocktail" }) == "Cocktail Deck*", "the usual name, marked edited")
nodes = {}
localize({ type = "descriptions", set = "Back", key = "b_mp_cocktail", nodes = nodes, vars = {} })
check(#nodes == 2 and nodes[1] == "Copies the effects", "the usual description")

print()
if failures == 0 then
	print("ALL PASS")
else
	print(failures .. " FAIL")
	os.exit(1)
end
