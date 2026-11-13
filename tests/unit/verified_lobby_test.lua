-- Plain Lua test for the verified-lobby rules (lib/verified_lobby.lua), no game needed.
-- Run from the repo root: luajit tests/unit/verified_lobby_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

MPAPI = { Standing = { VERIFIED = "verified", VALID = "valid", NONE = "none" } }
function MPAPI.is_launcher_verified() return false end
PVP = { self_player_id = function() return "me" end }
dofile("lib/verified_lobby.lua")

local function config(over)
	local c = { gamemode = "gamemode_mp_attrition", deck_mode = "select" }
	for k, v in pairs(PVP.VERIFIED_DEFAULTS) do c[k] = v end
	for k, v in pairs(over or {}) do c[k] = v end
	return c
end
local both = { { id = "me", standing = "verified" }, { id = "you", standing = "verified" } }
local function ok(cfg, players) return (PVP.verified_lobby_check(cfg, players or both)) end

check("defaults + verified players", ok(config()), true)
check("draft deck mode allowed", ok(config({ deck_mode = "draft" })), true)
check("missing booleans count as false", ok(config({ normal_bosses = nil, trap_cards = nil })), true)
check("custom_seed nil counts as random", ok(config({ custom_seed = nil })), true)
check("unverified guest", ok(config(), { both[1], { id = "you", standing = "valid" } }), false)
check("no standing yet", ok(config(), { both[1], { id = "you" } }), false)
check("own launcher verdict counts", (function()
	MPAPI.is_launcher_verified = function() return true end
	local r = ok(config(), { { id = "me" }, both[2] })
	MPAPI.is_launcher_verified = function() return false end
	return r
end)(), true)
check("empty lobby", ok(config(), {}), false)
check("set seed", ok(config({ custom_seed = "ABCD1234" })), false)
check("different seeds", ok(config({ different_seeds = true })), false)
check("different decks", ok(config({ different_decks = true })), false)
check("random loadout", ok(config({ random_loadout = true })), false)
check("lives 5", ok(config({ starting_lives = 5 })), false)
check("other ruleset", ok(config({ ruleset = "ruleset_mp_balanced" })), false)
check("trap cards", ok(config({ trap_cards = true })), false)
check("timer off", ok(config({ timer = false })), false)
check("other gamemode", ok(config({ gamemode = "gamemode_mp_royale" })), false)
local _, failed = PVP.verified_lobby_check(config({ starting_lives = 3 }), both)
check("reports the failed key", failed[1], "starting_lives")

PVP.LOBBY = { config = config({ different_seeds = true, gamemode = "x", starting_lives = 1 }) }
PVP.apply_verified_defaults()
check("apply_verified_defaults restores", ok(PVP.LOBBY.config), true)

if failures > 0 then os.exit(1) end
