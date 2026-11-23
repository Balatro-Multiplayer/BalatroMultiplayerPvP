-- Plain Lua test: an opponent's brief drop shows no overlay; one that outlasts the
-- grace period does, and their return closes it.
-- Run from the repo root: luajit tests/unit/disconnect_grace_test.lua
local noop = function() end
local events, overlays, exits = {}, {}, 0
PVP = {
	id = "MultiplayerPvP",
	LOBBY = { config = {}, deck = {} },
	GAME = {},
	UTILS = { version_mismatches = function() return {} end },
	UI = { UTILS = {} },
	SETUP = { apply_results = noop },
	LobbyAccess = {},
	TRAP_ROW = { on_player_back = noop, forget = noop },
	AnteTimer = { on_opponent_back = noop },
	reconcile_round = noop,
	referee_on_player_reconnected = noop,
	reset_game_states = noop,
	force_lobby_options = noop,
	version = "1.0.3",
}
G = {
	STAGE = 1,
	STAGES = { RUN = 2 },
	E_MANAGER = { add_event = function(_, e) events[#events + 1] = e end },
	FUNCS = { exit_overlay_menu = function() exits = exits + 1; G.OVERLAY_MENU = nil end },
}
Event = function(t) return t end
PVP.UI.UTILS.overlay_message = function(text)
	overlays[#overlays + 1] = text
	G.OVERLAY_MENU = {}
end
local EVENTS = setmetatable({}, { __index = function(_, k) return k end })
MPAPI = {
	LobbyEvent = EVENTS,
	matchmaking = { group = {} },
	apply_default_modifiers = noop,
	add_modifier = noop,
	modifiers_serialize = noop,
	refresh_current_view = noop,
	create_lobby_ui = noop,
	get_current_lobby = function() return nil end,
}

dofile("lib/version_gate.lua")
dofile("pvp_api/lobby_bridge.lua")

local lobby = { player_id = "me", is_host = false, code = "ABC", mod_id = "MultiplayerPvP", handlers = {} }
function lobby:on(event, fn) self.handlers[event] = fn end
function lobby:get_players() return {} end
function lobby:get_metadata() return {} end
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
local function run_events()
	local due = events
	events = {}
	for _, e in ipairs(due) do e.func() end
end

lobby.handlers.PLAYER_DISCONNECTED("opp")
check("a drop waits out the grace period", #overlays, 0)
check("the wait is on the real-time clock", events[1].timer, "REAL")
lobby.handlers.PLAYER_RECONNECTED("opp")
run_events()
check("a quick return shows no overlay", #overlays, 0)

lobby.handlers.PLAYER_DISCONNECTED("opp")
run_events()
check("a lasting drop shows the overlay", #overlays, 1)
lobby.handlers.PLAYER_RECONNECTED("opp")
check("the return closes it", exits, 1)

lobby.handlers.PLAYER_DISCONNECTED("opp")
run_events()
G.OVERLAY_MENU = {} -- the player moved on to another menu
lobby.handlers.PLAYER_RECONNECTED("opp")
check("an unrelated overlay is left open", exits, 1)

if failures > 0 then os.exit(1) end
