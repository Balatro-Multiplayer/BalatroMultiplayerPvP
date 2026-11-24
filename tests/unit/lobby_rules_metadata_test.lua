-- Plain Lua test: the lobby metadata carries every rule the server's start check
-- reads (ruleset, queue_mode, starting_lives, manhunt_hunter_lives, pvp_start_ante,
-- timer_base_seconds, timer_forgiveness, timer_increment_seconds), taken from the
-- lobby's options, for every gamemode and every ruleset the mod ships.
-- Run from the repo root: luajit tests/unit/lobby_rules_metadata_test.lua
local checks = 0
local function check(condition, message)
	checks = checks + 1
	assert(condition, message)
end

PVP = {
	lobby = {},
	LOBBY = { config = {}, deck = {} },
	-- The lobby options a fresh lobby starts with (core.lua reset_lobby_config).
	PVP_GAMEMODES = {
		pvp_nemesis = { ruleset = "ruleset_mp_balanced", private_ruleset = "ruleset_mp_expanded", gamemode = "gamemode_mp_attrition" },
		pvp_smallworld = { ruleset = "ruleset_mp_smallworld", gamemode = "gamemode_mp_attrition" },
		pvp_royale = { ruleset = "ruleset_mp_balanced", private_ruleset = "ruleset_mp_expanded", gamemode = "gamemode_mp_attrition" },
		pvp_manhunt = { ruleset = "ruleset_mp_balanced", private_ruleset = "ruleset_mp_expanded", gamemode = "gamemode_mp_attrition" },
		pvp_teams = { ruleset = "ruleset_mp_balanced", private_ruleset = "ruleset_mp_expanded", gamemode = "gamemode_mp_attrition" },
		pvp_experimental = { ruleset = "ruleset_mp_experimental", gamemode = "gamemode_mp_attrition" },
	},
	MatchmakingPolicy = { cocktail_recipe = function() end },
	-- lib/verified_lobby.lua has its own test.
	compute_verified_lobby = function() return false end,
}
MPAPI = { Party = { KIND = "party" } }
dofile("pvp_api/flow.lua")

local function fresh_config()
	PVP.LOBBY.config = {
		starting_lives = 4,
		pvp_start_ante = 2,
		manhunt_hunter_lives = 7,
		timer_base_seconds = 150,
		timer_increment_seconds = 60,
		timer_forgiveness = 0,
	}
end

local function rulesets_in_folder()
	local keys = {}
	local listing = io.popen('dir /b /s "rulesets\\*.lua" 2>nul')
	for path in listing:lines() do
		local file = io.open(path, "rb")
		local text = file:read("*a")
		file:close()
		local key = text:match('PVP%.Ruleset%(%{%s*key = "([%w_]+)"')
		if key then
			keys[#keys + 1] = "ruleset_mp_" .. key
		end
	end
	listing:close()
	return keys
end

local function check_rules(meta, label)
	check(type(meta.ruleset) == "string", label .. ": ruleset is a string")
	check(type(meta.queue_mode) == "string", label .. ": queue_mode is a string")
	check(type(meta.starting_lives) == "number", label .. ": starting_lives is a number")
	check(type(meta.manhunt_hunter_lives) == "number", label .. ": manhunt_hunter_lives is a number")
	check(type(meta.pvp_start_ante) == "number", label .. ": pvp_start_ante is a number")
	check(type(meta.timer_base_seconds) == "number", label .. ": timer_base_seconds is a number")
	check(type(meta.timer_forgiveness) == "number", label .. ": timer_forgiveness is a number")
	check(type(meta.timer_increment_seconds) == "number", label .. ": timer_increment_seconds is a number")
end

local kinds = { PVP.LobbyAccess.PRIVATE, PVP.LobbyAccess.CASUAL }
for gamemode_key in pairs(PVP.PVP_GAMEMODES) do
	for _, kind in ipairs(kinds) do
		fresh_config()
		PVP.LOBBY.config.ruleset = nil
		check_rules(PVP.pvp_lobby_metadata(gamemode_key, kind), gamemode_key .. "/" .. kind)
	end
end

local rulesets = rulesets_in_folder()
check(#rulesets >= 14, "found the shipped rulesets, got " .. #rulesets)
for _, ruleset_key in ipairs(rulesets) do
	for _, kind in ipairs(kinds) do
		fresh_config()
		PVP.LOBBY.config.ruleset = ruleset_key
		local meta = PVP.pvp_lobby_metadata("pvp_nemesis", kind)
		check(meta.ruleset == ruleset_key, ruleset_key .. " is published as chosen")
		check_rules(meta, ruleset_key .. "/" .. kind)
	end
end

-- The host's chosen values are what goes out.
fresh_config()
PVP.LOBBY.config.timer_base_seconds = 210
PVP.LOBBY.config.timer_forgiveness = 1
PVP.LOBBY.config.timer_increment_seconds = 30
local meta = PVP.pvp_lobby_metadata("pvp_nemesis", PVP.LobbyAccess.PRIVATE)
check(meta.timer_base_seconds == 210, "chosen timer base is published")
check(meta.timer_forgiveness == 1, "chosen forgiveness is published")
check(meta.timer_increment_seconds == 30, "chosen skip time is published")

-- An option the lobby does not have is left out, never guessed.
fresh_config()
PVP.LOBBY.config.timer_increment_seconds = nil
meta = PVP.pvp_lobby_metadata("pvp_nemesis", PVP.LobbyAccess.PRIVATE)
check(meta.timer_increment_seconds == nil, "a missing skip time is not filled in")

print(("ok   %d checks"):format(checks))
