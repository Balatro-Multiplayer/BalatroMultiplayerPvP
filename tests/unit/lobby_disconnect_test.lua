-- Plain Lua test: an old lobby's DISCONNECTED must not clear the state of a
-- newer PvP lobby the player has already moved into.
-- Run from the repo root: luajit tests/unit/lobby_disconnect_test.lua
local noop = function() end
local left = 0
PVP = {
	id = "MultiplayerPvP",
	LOBBY = { config = {}, deck = {} },
	GAME = {},
	UTILS = {},
	UI = { UTILS = {} },
	SETUP = { apply_results = noop },
	LobbyAccess = {},
	reset_game_states = noop,
	force_lobby_options = noop,
	version = "1.0.3",
	current_target_id = noop,
}
G = { STAGE = 1, STAGES = { RUN = 2 } }
local EVENTS = setmetatable({}, { __index = function(_, k) return k end })
local current
MPAPI = {
	register_player_status_provider = function() end,
	LobbyEvent = EVENTS,
	matchmaking = { group = {} },
	apply_default_modifiers = noop,
	add_modifier = noop,
	modifiers_serialize = noop,
	refresh_current_view = noop,
	create_lobby_ui = noop,
	get_current_lobby = function()
		return current
	end,
}

dofile("lib/version_gate.lua")
dofile("pvp_api/reconnect_screen.lua")
dofile("pvp_api/lobby_bridge.lua")

local function new_lobby()
	local lobby = { player_id = "me", is_host = false, code = "ABC", mod_id = "MultiplayerPvP", handlers = {} }
	function lobby:on(event, fn)
		self.handlers[event] = fn
	end
	function lobby:get_players()
		return {}
	end
	function lobby:get_metadata()
		return {}
	end
	return lobby
end

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local old, new = new_lobby(), new_lobby()
PVP.setup_lobby_mirror(old)
PVP.setup_lobby_mirror(new)
local handle = { leave = function() left = left + 1 end }
PVP._match_handle = handle
PVP._pvp_kind = "ranked"

current = new
old.handlers.DISCONNECTED()
check("a stale lobby's disconnect keeps the match handle", PVP._match_handle, handle)
check("a stale lobby's disconnect keeps the kind", PVP._pvp_kind, "ranked")
check("a stale lobby's disconnect does not leave the match", left, 0)
check("a stale lobby's disconnect keeps the newer lobby's reconnect line", PVP.reconnect_screen.on_frame ~= nil, true)

new.handlers.DISCONNECTED()
check("the current lobby's disconnect drops the handle", PVP._match_handle, nil)
check("the current lobby's disconnect leaves the match", left, 1)
check("the current lobby's disconnect clears the kind", PVP._pvp_kind, nil)
check("the current lobby's disconnect ends the reconnect line", PVP.reconnect_screen.on_frame, nil)

-- A lobby that takes the screen starts it clean: the older lobby's away line and reconnected
-- message do not stay.
PVP.away_screen = { in_run = function() return false end }
function localize(arg)
	return type(arg) == "table" and arg.key or arg
end
local stale, fresh = new_lobby(), new_lobby()
PVP.setup_lobby_mirror(stale)
PVP.reconnect_screen.sync({ bea = { who = "other", name = "Bea" } }, true)
PVP.reconnect_screen.add_back("Cy", 0)
check("the older lobby's line shows", PVP.reconnect_screen.shown_text(1), "k_pvp_player_reconnecting")
PVP.setup_lobby_mirror(fresh)
check("a newer lobby starts with no line", PVP.reconnect_screen.shown_text(1), nil)

if failures > 0 then os.exit(1) end
