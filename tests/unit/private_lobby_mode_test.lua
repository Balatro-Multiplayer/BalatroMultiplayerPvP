-- Plain Lua test: a new private lobby opens on Expanded where its gamemode would
-- play Balanced, and the lobby banner names the gamemode and the ruleset.
-- Run from the repo root: luajit tests/unit/private_lobby_mode_test.lua
local checks = 0
local function check(condition, message)
	checks = checks + 1
	assert(condition, message)
end

local R = {
	VANILLA = "ruleset_mp_vanilla",
	BALANCED = "ruleset_mp_balanced",
	EXPANDED = "ruleset_mp_expanded",
	SMALLWORLD = "ruleset_mp_smallworld",
	EXPERIMENTAL = "ruleset_mp_experimental",
	MAJORLEAGUE = "ruleset_mp_majorleague",
}
PVP = {
	lobby = {},
	LOBBY = { config = {}, deck = {} },
	RulesetKey = R,
	-- The rulesets the real table (pvp_api/gamemodes.lua) gives each gamemode key.
	PVP_GAMEMODES = {
		pvp_nemesis = { ruleset = R.BALANCED, private_ruleset = R.EXPANDED },
		pvp_smallworld = { ruleset = R.SMALLWORLD },
		pvp_royale = { ruleset = R.BALANCED, private_ruleset = R.EXPANDED },
		pvp_manhunt = { ruleset = R.BALANCED, private_ruleset = R.EXPANDED },
		pvp_teams = { ruleset = R.BALANCED, private_ruleset = R.EXPANDED },
		pvp_experimental = { ruleset = R.EXPERIMENTAL },
	},
}
MPAPI = { Party = { KIND = "party" } }
PVP.compute_verified_lobby = function() return false end -- lib/verified_lobby.lua has its own test
dofile("pvp_api/flow.lua")
dofile("ui/lobby/mode_banner.lua")

-- Default ruleset of a new private lobby, through the one resolver.
local PRIVATE = PVP.LobbyAccess.PRIVATE
for _, key in ipairs({ "pvp_nemesis", "pvp_royale", "pvp_manhunt", "pvp_teams" }) do
	local got = PVP.default_ruleset(key, PRIVATE)
	check(got == R.EXPANDED, key .. " opens on Expanded, got " .. tostring(got))
	check(PVP.default_ruleset(key, PVP.LobbyAccess.CASUAL) == R.BALANCED, key .. " queues on Balanced")
end
check(PVP.default_ruleset("pvp_smallworld", PRIVATE) == R.SMALLWORLD, "Small World keeps its own ruleset")
check(PVP.default_ruleset("pvp_experimental", PRIVATE) == R.EXPERIMENTAL, "Experimental keeps its own ruleset")
check(PVP.default_ruleset(nil, PRIVATE) == R.EXPANDED, "no key falls back to Nemesis, on Expanded")
-- The reset stamps the same answer per kind.
PVP.reset_ruleset_to_gamemode_default("pvp_nemesis", PRIVATE)
check(PVP.LOBBY.config.ruleset == R.EXPANDED, "a private Nemesis lobby resets to Expanded")
PVP.reset_ruleset_to_gamemode_default("pvp_nemesis")
check(PVP.LOBBY.config.ruleset == R.BALANCED, "matchmade Nemesis still resets to Balanced")
-- Metadata's fallback agrees when config holds nothing yet.
PVP.MatchmakingPolicy = { cocktail_recipe = function() end }
PVP.LOBBY.config.ruleset = nil
check(PVP.pvp_lobby_metadata("pvp_teams", PRIVATE).ruleset == R.EXPANDED, "private metadata falls back to Expanded")

-- Banner contents.
local parts = PVP.lobby_mode_parts("pvp_nemesis", R.EXPANDED)
check(#parts == 2, "a Nemesis lobby names gamemode and ruleset")
check(parts[1].name_key == "k_pvp_gamemode_nemesis" and parts[1].style == "nemesis", "gamemode part first, in Nemesis style")
check(parts[2].ruleset_key == R.EXPANDED and parts[2].style == "expanded", "ruleset part second, in Expanded style")

parts = PVP.lobby_mode_parts("pvp_royale", R.VANILLA)
check(parts[1].name_key == "k_pvp_gamemode_royale" and parts[2].style == "vanilla", "a ruleset change shows the new ruleset")

parts = PVP.lobby_mode_parts("pvp_smallworld", R.SMALLWORLD)
check(#parts == 1 and parts[1].ruleset_key == R.SMALLWORLD, "Small World is named once")

parts = PVP.lobby_mode_parts(nil, R.EXPANDED)
check(#parts == 1 and parts[1].ruleset_key == R.EXPANDED, "an unknown gamemode is left out, not guessed")
check(#PVP.lobby_mode_parts(nil, nil) == 0, "nothing known, nothing shown")

parts = PVP.lobby_mode_parts("pvp_nemesis", R.EXPERIMENTAL)
check(parts[2].style == nil, "a ruleset without art gets a plain plate")

-- Hover text: the gamemode part carries its description key; the ruleset part is
-- described by the ruleset's own "_description" entry at render time.
parts = PVP.lobby_mode_parts("pvp_manhunt", R.EXPANDED)
check(parts[1].desc_key == "k_pvp_gamemode_manhunt_desc", "the gamemode part names its description")
check(parts[2].desc_key == nil, "the ruleset part has no gamemode description")

local lines = PVP.lobby_mode_tooltip_lines("Near-vanilla.\n\nJustice is banned.\n")
check(#lines == 3 and lines[1] == "Near-vanilla." and lines[2] == " " and lines[3] == "Justice is banned.", "a description splits into lines, a blank line kept as a spacer")
check(#PVP.lobby_mode_tooltip_lines("One line.") == 1, "a one-line description is one line")
check(PVP.lobby_mode_tooltip_lines(nil) == nil and PVP.lobby_mode_tooltip_lines("  ") == nil, "no description, no tooltip")

-- Every name and description the banner localizes exists in en-us.
local dictionary = dofile("localization/en-us.lua").misc.dictionary
for _, key in ipairs({
	"k_pvp_lobby_gamemode_caption", "k_pvp_lobby_ruleset_caption",
	"k_pvp_gamemode_nemesis", "k_pvp_gamemode_royale", "k_pvp_gamemode_manhunt", "k_pvp_gamemode_teams",
	"k_pvp_gamemode_nemesis_desc", "k_pvp_gamemode_royale_desc", "k_pvp_gamemode_manhunt_desc", "k_pvp_gamemode_teams_desc",
	"k_vanilla_description", "k_mp_ruleset_balanced_description", "k_mp_ruleset_expanded_description",
	"k_smallworld_description", "k_experimental_description", "k_majorleague_description",
}) do
	check(type(dictionary[key]) == "string", key .. " is in en-us")
end

print(("ok   %d checks"):format(checks))
