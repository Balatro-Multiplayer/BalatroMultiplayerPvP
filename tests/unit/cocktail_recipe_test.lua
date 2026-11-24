--[[
  Cocktail recipe test.

  A matchmade lobby (Ranked or Casual) carries a fixed Cocktail in its metadata,
  cocktail_recipe = { name, decks }. In that lobby the Cocktail deck forces the
  recipe's decks, whatever the player's own Cocktail settings say, and is named
  and described by it. Private lobbies share the host's recipe at game start.
  Without a recipe, the player's Cocktail settings apply.

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

MPAPI = { Party = { KIND = "party" }, apply_default_modifiers = noop, modifiers_serialize = noop }
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

dofile("lib/matchmaking_policy.lua")
PVP.compute_verified_lobby = function() return false end -- lib/verified_lobby.lua has its own test
dofile("pvp_api/flow.lua")
dofile("lib/_random.lua")
dofile("objects/decks/ZZ_cocktail.lua")
dofile("pvp_api/lobby_bridge.lua")
PVP.force_lobby_options = noop
PVP.SETUP = { apply_results = noop }
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
	return PVP.mirror_lobby_metadata({ get_metadata = function() return meta end })
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
local casual_recipe = PVP.pvp_lobby_metadata("pvp_nemesis", A.CASUAL).cocktail_recipe
check(
	casual_recipe.name == recipe.name and table.concat(casual_recipe.decks, ",") == table.concat(recipe.decks, ","),
	"a Casual lobby carries the same recipe"
)
check(PVP.pvp_lobby_metadata("pvp_nemesis", A.PRIVATE).cocktail_recipe == nil, "a private lobby carries none")
check(PVP.pvp_lobby_metadata("pvp_nemesis", A.PRACTICE).cocktail_recipe == nil, "practice carries none")

print()
print("-- the recipe set on the website --")
local Policy = PVP.MatchmakingPolicy
Policy._set_server_recipe({ name = "Featured", decks = { "b_red", "b_blue" } })
local featured = PVP.pvp_lobby_metadata("pvp_nemesis", A.RANKED).cocktail_recipe
check(featured.name == "Featured" and table.concat(featured.decks, ",") == "b_red,b_blue", "Ranked carries the server's recipe")
check(PVP.pvp_lobby_metadata("pvp_nemesis", A.CASUAL).cocktail_recipe.name == "Featured", "Casual carries it too")
check(PVP.pvp_lobby_metadata("pvp_nemesis", A.PRIVATE).cocktail_recipe == nil, "a private lobby still carries none")
featured.decks[1] = "b_green"
check(Policy.cocktail_recipe(A.RANKED).decks[1] == "b_red", "the stored recipe cannot be edited through a returned one")
Policy._set_server_recipe({ name = "Broken", decks = {} })
check(Policy.cocktail_recipe(A.RANKED).name == "Bean's Cocktail", "a recipe with no decks falls back to the built-in one")

-- The server's answer replaces the recipe; an error keeps it; "none set" clears it.
local answer
MPAPI.networking = { nakama_lobby = { rpc = function(name, _, callback)
	check(name == "cocktail_recipe", "asks the cocktail_recipe RPC")
	callback(answer.err, answer.data)
end } }
answer = { data = { recipe = { name = "Fetched", decks = { "b_yellow" } } } }
Policy.refresh_cocktail()
check(Policy.cocktail_recipe(A.RANKED).name == "Fetched", "an answer sets the Ranked recipe")
answer = { err = "offline" }
Policy.refresh_cocktail()
check(Policy.cocktail_recipe(A.RANKED).name == "Fetched", "an error keeps the last recipe")
answer = { data = { recipe = {} } }
Policy.refresh_cocktail()
check(Policy.cocktail_recipe(A.RANKED).name == "Bean's Cocktail", "no recipe set goes back to the built-in one")
MPAPI.networking = nil

print()
print("-- a random Cocktail --")
answer = { data = { recipe = { name = "Mystery Cocktail", random = true } } }
MPAPI.networking = { nakama_lobby = { rpc = function(_, _, callback) callback(answer.err, answer.data) end } }
Policy.refresh_cocktail()
MPAPI.networking = nil
local function valid(r)
	if not (r and r.name == "Mystery Cocktail" and #r.decks == 3) then return false end
	local seen = {}
	for _, key in ipairs(r.decks) do
		if not G.P_CENTERS[key] or seen[key] then return false end
		seen[key] = true
	end
	return true
end
local function same(a, b) return table.concat(a.decks, ",") == table.concat(b.decks, ",") end
PVP.LOBBY.code = "LOBBY1"
local first = Policy.cocktail_recipe(A.RANKED)
check(valid(first), "rolls three different decks this game knows, named by the website")
check(same(Policy.cocktail_recipe(A.RANKED), first), "stamping the lobby again keeps its roll")
check(PVP.pvp_lobby_metadata("pvp_nemesis", A.RANKED).cocktail_recipe.name == "Mystery Cocktail", "the lobby metadata carries it")
check(PVP.pvp_lobby_metadata("pvp_nemesis", A.PRIVATE).cocktail_recipe == nil, "a private lobby still carries none")
check(Policy.next_game_cocktail(A.RANKED) == nil, "the lobby's first game plays the roll it was stamped with")
check(Policy.next_game_cocktail(A.PRIVATE) == nil, "a private lobby has its own roll")
local rolls, changed = {}, false
for _ = 1, 20 do
	local r = Policy.next_game_cocktail(A.RANKED)
	check(valid(r), "every later game rolls a valid recipe")
	if not same(r, first) then changed = true end
	rolls[#rolls + 1] = r
end
check(changed, "later games roll other decks")
check(same(Policy.cocktail_recipe(A.RANKED), rolls[#rolls]), "the lobby now shows the latest roll")
PVP.LOBBY.code = "LOBBY2"
check(valid(Policy.cocktail_recipe(A.RANKED)), "a new lobby rolls its own")
check(Policy.next_game_cocktail(A.CASUAL) == nil, "and plays it in its first game")
-- The deck list the game lacks: only the decks it has are drawn.
local saved = G.P_CENTERS
G.P_CENTERS = { b_red = saved.b_red, b_blue = saved.b_blue, b_mp_cocktail = saved.b_mp_cocktail }
PVP.LOBBY.code = "LOBBY3"
local small = Policy.cocktail_recipe(A.RANKED)
check(#small.decks == 2, "with fewer decks known, it mixes the ones there are")
G.P_CENTERS = saved
Policy._set_server_recipe({ name = "Broken", random = "yes" })
check(Policy.cocktail_recipe(A.RANKED).name == "Bean's Cocktail", "random must be true, else the built-in one")
Policy._set_server_recipe(nil)
check(Policy.next_game_cocktail(A.RANKED) == nil, "a fixed recipe never rolls")
PVP.LOBBY.code = nil

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
print("-- unsupported recipes are rejected without substitution --")
local real_leave = PVP.pvp_leave_lobby
local rejected, rejection_message = 0, nil
PVP.pvp_leave_lobby = function()
	rejected = rejected + 1
	leave()
end
PVP.UI = { UTILS = {
	overlay_message = function(message)
		rejection_message = message
	end,
} }
for _, recipe in ipairs({
	{ decks = { "b_red", "b_mp_unknown" } },
	{ decks = { "b_red", "b_blue", "b_yellow", "b_green" } },
	{ decks = {} },
	{ decks = { "b_mp_cocktail" } },
	{ decks = { "b_red", "b_red" } },
	{ decks = { "j_test" } },
	{ name = {}, decks = { "b_red" } },
}) do
	check(join({ cocktail_recipe = recipe }) == false, "unsupported recipe rejects the lobby")
	check(PVP.LOBBY.code == nil, "rejection leaves the lobby")
end
check(rejected == 7 and rejection_message ~= nil, "rejections explain the incompatibility")
PVP._pvp_action_helpers = { A = noop, relay = noop }
dofile("pvp_api/actions/run_lifecycle.lua")
MPAPI.get_current_lobby = function()
	return {
		get_metadata = function()
			return { cocktail_recipe = { decks = { "b_mp_unknown" } } }
		end,
	}
end
PVP.on_game_start({ seed = "test" })
check(rejected == 8, "a late start event cannot bypass recipe validation")
PVP.pvp_leave_lobby = real_leave
join({ cocktail_recipe = { decks = { "b_red", "b_blue" } } })
check(localize({ type = "name_text", set = "Back", key = "b_mp_cocktail" }) == "Cocktail Deck", "no name keeps the usual one")
nodes = description()
check(nodes[1] == "Red Deck" and nodes[2] == "Blue Deck" and nodes[3] == "", "two decks fill two lines")

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
print("-- a private lobby plays the host's Cocktail --")
-- The host forces Checkered and Erratic and pools only Red; the guest's own
-- settings (PVP.config above) pool only Red.
local guest_cfg = PVP.config.cocktail
PVP.config.cocktail = "1000022S"
recipe = PVP.roll_cocktail_recipe()
check(
	recipe and #recipe.decks == 3 and recipe.decks[1] == "b_checkered" and recipe.decks[2] == "b_erratic" and recipe.decks[3] == "b_red",
	"the host's forced decks, then a random one from its pool"
)
PVP.config.cocktail = "0000000S"
check(PVP.roll_cocktail_recipe() == nil, "settings that pick no decks roll no recipe")
PVP.config.cocktail = "2222222S"
check(#PVP.roll_cocktail_recipe().decks == 3, "more than 3 forced decks mix only 3")

-- Start a 2-player private lobby as its host and record what goes out, in order.
local sent = {}
local host_lobby = {
	is_host = true,
	get_players = function() return { {}, {} } end,
	get_metadata = function() return {} end,
	set_metadata = function(_, patch) sent[#sent + 1] = { metadata = patch } end,
	start_game = function() sent[#sent + 1] = { start = true } end,
}
MPAPI.get_current_lobby = function() return host_lobby end
MPAPI.has_server_referee = function() return true end
MPAPI.GameModes = {}
PVP.UTILS = { version_mismatches = function() return {} end }
PVP.GamemodeKey = { PVP_NEMESIS = "pvp_nemesis" }
local function start(kind, host_cfg)
	sent = {}
	PVP._pvp_kind = kind
	PVP.config.cocktail = host_cfg
	PVP.pvp_start_match()
	PVP.config.cocktail = guest_cfg
end

start(A.PRIVATE, "1100000H")
local meta = sent[1] and sent[1].metadata
check(meta and type(meta.cocktail_recipe) == "table" and sent[2] and sent[2].start, "the host sends its Cocktail before the game starts")
local host_decks = meta and meta.cocktail_recipe.decks or {}
join(meta or {})
forced = select(2, PVP.get_cocktail_decks(true))
check(
	#forced == 2 and forced[1] == host_decks[1] and forced[2] == host_decks[2] and #host_decks == 2,
	"the guest plays the host's decks, not its own settings"
)
start(A.PRIVATE, "0000000S")
check(sent[1] and sent[1].metadata and sent[1].metadata.cocktail_recipe == false, "no decks clears the last game's recipe")
join(sent[1].metadata)
check(PVP.cocktail_recipe() == nil, "a cleared recipe falls back to the player's own settings")
start(A.RANKED, "1100000H")
check(#sent == 1 and sent[1].start, "a matchmade lobby keeps the recipe it queued with")
leave()

print()
if failures == 0 then
	print("ALL PASS")
else
	print(failures .. " FAIL")
	os.exit(1)
end
