-- Plain Lua test for state.lua's lobby settings: the defaults, what a reset keeps,
-- and which lobby metadata keys reach PVP.LOBBY.config.
-- Run from the repo root: luajit tests/unit/lobby_settings_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local warnings = {}
function sendWarnMessage(msg)
	warnings[#warnings + 1] = msg
end
PVP = { match_log = function() end }
dofile("state.lua")

PVP.reset_lobby_config()
local config = PVP.LOBBY.config
check("default ruleset", config.ruleset, "ruleset_mp_expanded")
check("default starting lives", config.starting_lives, 4)
check("default the_order", config.the_order, true)

config.ruleset = "ruleset_mp_balanced"
config.gamemode = "gamemode_mp_survival"
config.starting_lives = 2
PVP.reset_lobby_config(true)
check("a keeping reset keeps the ruleset", PVP.LOBBY.config.ruleset, "ruleset_mp_balanced")
check("a keeping reset keeps the gamemode", PVP.LOBBY.config.gamemode, "gamemode_mp_survival")
check("a keeping reset restores lives", PVP.LOBBY.config.starting_lives, 4)
PVP.reset_lobby_config()
check("a full reset restores the ruleset", PVP.LOBBY.config.ruleset, "ruleset_mp_expanded")

PVP.apply_lobby_setting("starting_lives", "6")
check("a number setting arrives as a number", PVP.LOBBY.config.starting_lives, 6)
PVP.apply_lobby_setting("stake", "3")
check("the host's stake arrives as a number", PVP.LOBBY.config.stake, 3)
PVP.apply_lobby_setting("trap_cards", "true")
check("a boolean setting sent as text arrives as a boolean", PVP.LOBBY.config.trap_cards, true)
PVP.apply_lobby_setting("trap_cards", false)
check("a boolean setting arrives as it is", PVP.LOBBY.config.trap_cards, false)

for _, key in ipairs({ "deck", "kind", "queue_mode", "cocktail_recipe", "_pvp_ref", "_mp_pending_seed" }) do
	PVP.apply_lobby_setting(key, "x")
	check("metadata key " .. key .. " stays out of config", PVP.LOBBY.config[key], nil)
end
check("metadata keys that aren't settings don't warn", #warnings, 0)

PVP.apply_lobby_setting("mystery", "x")
PVP.apply_lobby_setting("mystery", "y")
check("an unknown key is still copied", PVP.LOBBY.config.mystery, "y")
check("an unknown key warns once", #warnings, 1)

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
