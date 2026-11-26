-- Plain Lua test: the host's own metadata echoes must not undo its newer writes,
-- and a server-set key that lands while a write is in flight is still mirrored.
-- Run from the repo root: luajit tests/unit/metadata_echo_test.lua
local noop = function() end
local received = {}
PVP = {
	id = "MultiplayerPvP",
	LOBBY = { config = {}, deck = {} },
	GAME = {},
	UTILS = { version_mismatches = function() return {} end },
	UI = { UTILS = {} },
	SETUP = { apply_results = noop, continue = noop },
	LobbyAccess = {},
	TRAP_ROW = { on_player_back = noop, forget = noop },
	refresh_verified_lobby = noop,
	receive_cocktail_recipe = function(recipe)
		received[#received + 1] = recipe
		return true
	end,
	force_lobby_options = noop,
	reset_game_states = noop,
	version = "1.0.3",
}
G = { STAGE = 1, STAGES = { RUN = 2 } }
local now = 0
love = { timer = { getTime = function() return now end } }
local EVENTS = setmetatable({}, { __index = function(_, k) return k end })
MPAPI = {
	LobbyEvent = EVENTS,
	matchmaking = { group = {} },
	apply_default_modifiers = noop,
	add_modifier = noop,
	modifiers_serialize = noop,
	refresh_current_view = noop,
	get_current_lobby = function() return nil end,
}

dofile("lib/version_gate.lua")
dofile("pvp_api/lobby_bridge.lua")

local lobby = { player_id = "me", is_host = true, code = "ABC", mod_id = "MultiplayerPvP", handlers = {}, meta = {} }
function lobby:on(event, fn) self.handlers[event] = fn end
function lobby:get_players() return {} end
function lobby:get_metadata() return self.meta end
function lobby:set_metadata() end
PVP.setup_lobby_mirror(lobby)

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

-- Two quick writes: the first echo is older than the second write.
lobby:set_metadata({ game_speed = 1 })
lobby:set_metadata({ game_speed = 2 })
lobby.meta = { game_speed = 1 }
lobby.handlers.METADATA_CHANGED(lobby.meta)
check("an older echo does not undo the newer write", PVP.LOBBY.config.game_speed, 2)
lobby.meta = { game_speed = 2 }
lobby.handlers.METADATA_CHANGED(lobby.meta)
check("the last echo settles on the written value", PVP.LOBBY.config.game_speed, 2)

-- A server-set key arriving while a write is in flight is mirrored.
lobby:set_metadata({ game_speed = 3 })
lobby:set_metadata({ game_speed = 4 })
lobby.meta = { game_speed = 3, cocktail_recipe = "recipe" }
lobby.handlers.METADATA_CHANGED(lobby.meta)
check("a server-set key is mirrored while a write is in flight", received[#received], "recipe")
check("the newer write still stands", PVP.LOBBY.config.game_speed, 4)

-- An echo that never comes expires.
now = 100
lobby.meta = { game_speed = 5 }
lobby.handlers.METADATA_CHANGED(lobby.meta)
check("an expired write no longer overrides", PVP.LOBBY.config.game_speed, 5)

if failures > 0 then os.exit(1) end
