-- Plain Lua test: when the lobby bridge shows the version mismatch overlay.
-- A fake lobby records the bridge's event handlers; the test fires the events
-- the way MPAPI does and counts overlays.
-- Run from the repo root: luajit tests/unit/version_overlay_test.lua
local noop = function() end
PVP = {
	CLIENT = {},
	LOBBY = { config = {}, deck = {} },
	GAME = {},
	UTILS = {},
	UI = { UTILS = {} },
	SETUP = { apply_results = noop },
	LobbyAccess = {},
	TRAP_ROW = { on_player_back = noop, forget = noop },
	reset_game_states = noop,
	version = "1.0.3",
}
G = { STAGE = 1, STAGES = { RUN = 2 } }
local EVENTS = {}
for _, name in ipairs({
	"CONNECTED", "PLAYER_JOINED", "PLAYER_INFO", "PLAYER_LEFT", "DISCONNECTED", "ERROR",
	"PLAYER_CATCHING_UP", "PLAYER_DISCONNECTED", "PLAYER_RECONNECTED", "REPLAY_TAIL",
	"METADATA_CHANGED", "PLAYER_STANDING_CHANGED", "HOST_CHANGED", "SETUP_CHANGED",
	"PLAYER_READY_CHANGED", "GAME_STARTED", "CONTESTED", "GAME_ENDED", "SNAPSHOT_APPLIED",
}) do
	EVENTS[name] = name
end
MPAPI = {
	LobbyEvent = EVENTS,
	matchmaking = { group = {} },
	apply_default_modifiers = noop,
	add_modifier = noop,
	modifiers_serialize = noop,
	refresh_current_view = noop,
	create_lobby_ui = noop,
}

dofile("lib/version_gate.lua")
dofile("pvp_api/lobby_bridge.lua")

local overlays = {}
PVP.UI.UTILS.overlay_message = function(text)
	overlays[#overlays + 1] = text
end
function localize()
	return "mismatch line"
end

local players = {}
local lobby = { player_id = "me", is_host = false, code = "ABC", handlers = {} }
function lobby:on(event, fn)
	self.handlers[event] = fn
end
function lobby:get_players()
	return players
end
function lobby:get_metadata()
	return {}
end
MPAPI.get_current_lobby = function()
	return lobby
end
local function fire(event, ...)
	lobby.handlers[event](...)
end

PVP.UTILS.version_mismatches = function()
	return PVP.VersionGate.mismatches(PVP.version, lobby:get_players(), lobby.player_id)
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

PVP.setup_lobby_mirror(lobby)

-- A joiner gets the host in the first snapshot: only CONNECTED fires.
players = {
	{ id = "me", mods = { "MultiplayerPvP-1.0.3" } },
	{ id = "host", mods = { "MultiplayerPvP-1.0.4" } },
}
fire("CONNECTED")
check("joiner sees the overlay once the snapshot arrives", #overlays, 1)
fire("PLAYER_INFO", "host")
check("a second check of the same mismatch stays quiet", #overlays, 1)

-- The other player leaves: the flag re-arms, and a new mismatch shows again.
players = { { id = "me", mods = { "MultiplayerPvP-1.0.3" } } }
fire("PLAYER_LEFT", "host")
check("leaving shows nothing", #overlays, 1)
check("leaving re-arms the overlay", PVP._version_mismatch_shown, false)
players = {
	{ id = "me", mods = { "MultiplayerPvP-1.0.3" } },
	{ id = "other", mods = { "MultiplayerPvP-1.0.5" } },
}
fire("PLAYER_JOINED", "other")
check("a later mismatch shows again", #overlays, 2)

-- A start held back over versions is retried when the versions it lacked arrive.
PVP.UTILS.versions_known = function()
	return PVP.VersionGate.versions_known(lobby:get_players(), lobby.player_id)
end
local starts = 0
PVP.maybe_autostart = function()
	starts = starts + 1
end
local function hold_start()
	PVP.lobby.start_broadcasted = true
	PVP._start_held = PVP.UTILS.versions_known()
end
PVP.lobby = {}
local before = #overlays

-- Steph's case: the server refuses before the guest's mod list arrives, so this
-- client never saw a mismatch.
players = {
	{ id = "me", mods = { "MultiplayerPvP-1.0.3" } },
	{ id = "guest" },
}
fire("PLAYER_JOINED", "guest")
-- Clears the earlier mismatch (and with it any retry it set off).
starts = 0
hold_start()
players[2].mods = { "MultiplayerPvP-1.0.3" }
fire("PLAYER_INFO", "guest")
check("matching versions arriving retry the start", starts, 1)
check("the retry can broadcast again", PVP.lobby.start_broadcasted, false)
check("the held start is used up", PVP._start_held, false)
check("no overlay for matching versions", #overlays, before)

-- Refused again on the same versions: no new info, no retry.
hold_start()
fire("PLAYER_INFO", "guest")
check("the same versions don't retry again", starts, 1)
check("the start stays held", PVP._start_held, "guest=1.0.3")

-- Still unknown: no retry until the version is known.
players[2] = { id = "guest2" }
fire("PLAYER_JOINED", "guest2")
check("an unknown version doesn't retry", starts, 1)

-- A shown mismatch that clears retries, as before.
players[2] = { id = "guest2", mods = { "MultiplayerPvP-1.0.4" } }
fire("PLAYER_INFO", "guest2")
hold_start()
check("a mismatch shows the overlay", #overlays, before + 1)
players[2] = { id = "guest2", mods = { "MultiplayerPvP-1.0.3" } }
fire("PLAYER_INFO", "guest2")
check("a cleared mismatch retries the start", starts, 2)

-- Leaving the lobby re-arms too.
fire("DISCONNECTED")
check("disconnect re-arms the overlay", PVP._version_mismatch_shown, false)

if failures > 0 then os.exit(1) end
