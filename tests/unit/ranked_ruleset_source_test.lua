-- Run from the repo root: luajit tests/unit/ranked_ruleset_source_test.lua
-- A ranked lobby's card content loads from `metadata.ruleset`, the server's pin: the metadata
-- mirror (pvp_api/lobby_bridge.lua) puts it over whatever the queue stamped locally, and a host
-- that no longer writes the ruleset leaves it alone.
local noop = function() end
MPAPI = { Party = { KIND = "party" }, apply_default_modifiers = noop, modifiers_serialize = noop }
PVP = {
	id = "MultiplayerPvP",
	config = {},
	LOBBY = { deck = {}, config = {} },
	PVP_GAMEMODES = { pvp_nemesis = { ruleset = "ruleset_mp_expanded", gamemode = "gamemode_mp_attrition" } },
}
G = { E_MANAGER = { add_event = noop }, P_CENTERS = {} }

dofile("lib/matchmaking_policy.lua")
dofile("pvp_api/flow.lua")
dofile("pvp_api/lobby_bridge.lua")
PVP.force_lobby_options = noop
PVP.SETUP = { apply_results = noop }
PVP.receive_cocktail_recipe = function() return true end

local failures = 0
local function check(cond, msg)
	if cond then
		print("PASS: " .. msg)
	else
		failures = failures + 1
		print("FAIL: " .. msg)
	end
end

local function mirror(meta)
	return PVP.mirror_lobby_metadata({ get_metadata = function() return meta end })
end

-- The queue stamped the ticket's ruleset locally.
PVP._pvp_kind = PVP.LobbyAccess.RANKED
PVP.LOBBY.config.ruleset = "ruleset_mp_balanced"
PVP.LOBBY.config.starting_lives = 4

-- The server's pin, as the matchmaker writes it into the lobby metadata at creation.
-- Exactly the key set rankedPinOf writes (ranked_pin.ts): no `kind`, which only the host's own
-- write carries, so this is also what a guest's first mirror sees before the host has written.
local pinned = {
	ruleset = "ruleset_mp_vanilla",
	queue_mode = "pvp_nemesis",
	starting_lives = 4,
	pvp_start_round = 2,
	manhunt_hunter_lives = 7,
	timer_base_seconds = 150,
	timer_forgiveness = 0,
	timer_increment_seconds = 60,
}
mirror(pinned)
check(PVP.LOBBY.config.ruleset == "ruleset_mp_vanilla", "a guest's first mirror, the pin alone, takes the pinned ruleset")
check(PVP.LOBBY.config.timer_base_seconds == 150, "the pinned timer reaches the lobby config")

-- The host's ranked write carries no pinned key, so a merge with the pin keeps it.
local host_write = PVP.pvp_lobby_metadata("pvp_nemesis", PVP.LobbyAccess.RANKED)
local merged = {}
for k, v in pairs(pinned) do merged[k] = v end
for k, v in pairs(host_write) do merged[k] = v end
mirror(merged)
check(PVP.LOBBY.config.ruleset == "ruleset_mp_vanilla", "the host's write leaves the pinned ruleset alone")
check(merged.queue_mode == "pvp_nemesis", "the host's write leaves the pinned queue mode alone")

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
