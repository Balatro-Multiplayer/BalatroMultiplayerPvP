-- Plain Lua test: when the lobby bridge shows the version mismatch overlay.
-- A fake lobby records the bridge's event handlers; the test fires the events
-- the way MPAPI does and counts overlays.
-- Run from the repo root: luajit tests/unit/version_overlay_test.lua
local noop = function() end
PVP = {
	NET = {}, READ = { pvp_blind = {}, target = {} },
	LOBBY = { config = {}, deck = {}, reset_game = noop, Access = {} },
	GAME = {},
	UTILS = {},
	UI = { UTILS = {}, queue = {}, lobby = { reset = noop } },
	QUEUE = {},
	SETUP = { apply_results = noop },
	RULES = { force_lobby_options = noop },
	VERIFIED = {},
	version = "1.0.3",
}
-- The 1v1 opponent, as pvp_api/read/target.lua picks it.
PVP.READ.target.current_id = function()
		local lobby = MPAPI.get_current_lobby()
		for _, p in ipairs(lobby:get_players()) do
			if p.id ~= lobby.player_id then return p.id end
		end
end
-- The notice waits on a REAL-timer event: wait() runs the queued ones, as 3 s passing would.
local queued = {}
G = { STAGE = 1, STAGES = { RUN = 2 }, E_MANAGER = {
	add_event = function(_, e)
		queued[#queued + 1] = e
	end,
} }
Event = function(e)
	return e
end
local function wait(n)
	local run = {}
	for i = 1, math.min(n or #queued, #queued) do
		run[i] = table.remove(queued, 1)
	end
	for _, e in ipairs(run) do
		e.func()
	end
end
local EVENTS = {}
for _, name in ipairs({
	"CONNECTED", "PLAYER_JOINED", "PLAYER_INFO", "PLAYER_LEFT", "DISCONNECTED", "ERROR",
	"PLAYER_CATCHING_UP", "PLAYER_DISCONNECTED", "PLAYER_RECONNECTED", "REPLAY_TAIL",
	"METADATA_CHANGED", "PLAYER_STANDING_CHANGED", "HOST_CHANGED", "SETUP_CHANGED",
	"PLAYER_READY_CHANGED", "GAME_STARTED", "CONTESTED", "GAME_ENDED", "SNAPSHOT_APPLIED",
	"CONNECTION_DROPPED", "CONNECTION_RESTORED",
}) do
	EVENTS[name] = name
end
MPAPI = {
	LobbyEvent = EVENTS,
	register_player_status_provider = noop,
	matchmaking = { group = {} },
	apply_default_modifiers = noop,
	add_modifier = noop,
	modifiers_serialize = noop,
	refresh_current_view = noop,
	create_lobby_ui = noop,
}

local clock = 1000
local in_run = false
PVP.UI.away = { in_run = function() return in_run end }
love = { timer = { getTime = function() return clock end } }
dofile("lib/version_gate.lua")
dofile("pvp_api/ui/reconnect.lua")
PVP.VERIFIED.refresh = function() end -- lib/verified_lobby.lua has its own test
dofile("pvp_api/lobby_bridge.lua")

local overlays = {}
local no_back = {}
PVP.UI.UTILS.overlay_message = function(text, without_back)
	overlays[#overlays + 1] = text
	no_back[#overlays] = without_back == true
	G.OVERLAY_MENU = { text = text }
end
local closed = 0
G.FUNCS = {
	exit_overlay_menu = function()
		closed = closed + 1
		G.OVERLAY_MENU = nil
	end,
}
function localize(key)
	if type(key) == "table" then
		return key.key .. ":" .. table.concat(key.vars, "|")
	end
	if key == "k_mp_reconnecting" or key == "k_mp_reconnecting_line" then
		return key
	end
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
-- The API roster changes first, then the event fires (api/lobby/events.lua, apply_snapshot).
local function seat(id)
	for _, p in ipairs(players) do
		if p.id == id then return p end
	end
	players[#players + 1] = { id = id }
	return players[#players]
end
local function drop(id, forfeits_at)
	local p = seat(id)
	p.is_away, p.forfeits_at_local = true, forfeits_at
	fire("PLAYER_DISCONNECTED", id, forfeits_at)
end
local function back(id)
	local p = seat(id)
	p.is_away, p.forfeits_at_local = false, nil
	fire("PLAYER_RECONNECTED", id)
end
local function gone(id)
	for i, p in ipairs(players) do
		if p.id == id then table.remove(players, i) break end
	end
	fire("PLAYER_LEFT", id)
end

PVP.UTILS.version_mismatches = function()
	return PVP.NET.version_gate.mismatches(PVP.version, lobby:get_players(), lobby.player_id)
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

PVP.LOBBY.mirror(lobby)

-- A joiner gets the host in the first snapshot: only CONNECTED fires.
players = {
	{ id = "me", mods = { "MultiplayerPvP-1.0.3" } },
	{ id = "host", mods = { "MultiplayerPvP-1.0.4" } },
}
fire("CONNECTED")
check("joiner sees the overlay once the snapshot arrives", #overlays, 1)
fire("PLAYER_INFO", "host")
check("a second check of the same mismatch stays quiet", #overlays, 1)

-- A disconnect identifies the player and tells the opponent it is waiting.
drop("host")
check("a fresh drop shows nothing yet", #overlays, 1)
wait()
check("disconnect identifies the player", overlays[#overlays], "k_pvp_player_waiting:host")
check("the waiting notice has a Back button", no_back[#overlays], false)

-- A later leave is the expired reconnect grace period, and re-arms the mismatch overlay.
players = { { id = "me", mods = { "MultiplayerPvP-1.0.3" } } }
gone("host")
check("expired reconnect identifies the player", overlays[#overlays], "host did not reconnect.")
check("leaving re-arms the overlay", PVP.LOBBY.version_warning_shown, false)
players = {
	{ id = "me", mods = { "MultiplayerPvP-1.0.3" } },
	{ id = "other", mods = { "MultiplayerPvP-1.0.5" } },
}
fire("PLAYER_JOINED", "other")
check("a later mismatch shows again", #overlays, 4)

-- Leaving the lobby re-arms too.
fire("DISCONNECTED")
check("disconnect re-arms the overlay", PVP.LOBBY.version_warning_shown, false)

-- Coming back closes the "waiting for reconnection" notice: it pauses the game.
PVP.reconcile_round = noop
PVP.referee_on_player_reconnected = noop
PVP.AnteTimer = { on_opponent_back = noop }
drop("other")
wait()
back("other")
check("reconnect closes the notice", G.OVERLAY_MENU, nil)
check("reconnect closes it once", closed, 1)

-- With two players away the notice stays until both are back.
drop("other")
drop("host")
wait()
back("other")
check("one of two back keeps the notice", closed, 1)
back("host")
check("both back closes the notice", closed, 2)

-- A menu the player opened over the notice stays open.
drop("other")
wait()
local own_menu = { text = "options" }
G.OVERLAY_MENU = own_menu
back("other")
check("another menu stays open", G.OVERLAY_MENU, own_menu)
check("another menu is not closed", closed, 2)

-- Our own drop pauses our game too, until the rejoin is done.
G.OVERLAY_MENU = nil
fire("CONNECTION_DROPPED")
wait()
check("own drop shows the notice", overlays[#overlays], "k_mp_reconnecting")
check("the reconnecting notice has a Back button", no_back[#overlays], false)
fire("CONNECTION_RESTORED")
check("own rejoin closes the notice", G.OVERLAY_MENU, nil)
check("own rejoin closes it once", closed, 3)

-- Back ourselves while the opponent is still away: their notice stays.
drop("other")
wait()
fire("CONNECTION_DROPPED")
fire("CONNECTION_RESTORED")
check("own rejoin keeps the opponent's notice", closed, 3)
back("other")
check("opponent back closes it", closed, 4)

-- An opponent past its grace is gone: our rejoin after that doesn't bring its notice back.
drop("other")
wait()
players = { { id = "me", mods = { "MultiplayerPvP-1.0.3" } } }
gone("other")
local shown = #overlays
G.OVERLAY_MENU = nil
fire("CONNECTION_DROPPED")
wait()
fire("CONNECTION_RESTORED")
check("a gone player's notice does not come back", overlays[#overlays], "k_mp_reconnecting")
check("only our own notice was shown", #overlays, shown + 1)

-- Leaving the lobby while dropped closes our notice.
fire("CONNECTION_DROPPED")
wait()
fire("DISCONNECTED")
check("leaving closes the notice", closed, 6)

-- A drop shorter than the wait shows nothing and doesn't pause.
local before, closed_before = #overlays, closed
fire("CONNECTION_DROPPED")
fire("CONNECTION_RESTORED")
wait()
check("a quick blip shows no notice", #overlays, before)
check("a quick blip closes nothing", closed, closed_before)
drop("other")
back("other")
wait()
check("an opponent's quick blip shows no notice", #overlays, before)

-- A second drop gets its own full wait: the first drop's ending doesn't cut it short.
fire("CONNECTION_DROPPED")
fire("CONNECTION_RESTORED")
fire("CONNECTION_DROPPED")
wait(1)
check("the old wait shows nothing", #overlays, before)
wait()
check("the new wait shows the notice", overlays[#overlays], "k_mp_reconnecting")
fire("CONNECTION_RESTORED")
check("the rejoin closes it", G.OVERLAY_MENU, nil)

-- A later drop waits again, also after a player left while away.
drop("other")
wait()
gone("other")
before = #overlays
G.OVERLAY_MENU = nil
fire("CONNECTION_DROPPED")
check("a drop after a leave waits too", #overlays, before)
wait()
fire("CONNECTION_RESTORED")

-- Back or Esc hides the big notice; a small line counts down to the forfeit the server named.
PVP.LOBBY.mirror(lobby)
clock = clock + 100 -- earlier sections' reconnected messages are over
local screen = PVP.UI.reconnect
G.OVERLAY_MENU = nil
players = {
	{ id = "me", displayName = "Me", mods = { "MultiplayerPvP-1.0.3" } },
	{ id = "other", displayName = "Bea", mods = { "MultiplayerPvP-1.0.3" } },
}
fire("PLAYER_JOINED", "other")
local forfeit_at = clock + 102
drop("other", forfeit_at)
check("a fresh drop shows no line", screen.shown_text(clock), nil)
wait()
check("the notice is up after the wait", overlays[#overlays], "k_pvp_player_waiting:Bea")
check("the big notice hides the small line", screen.shown_text(clock), nil)
local shown_before = #overlays
G.OVERLAY_MENU = nil -- Back or Esc
screen.on_frame()
check("Esc leaves a countdown line", screen.shown_text(clock), "k_pvp_player_reconnecting_timed:Bea|1:42")
check("the line counts down", screen.shown_text(clock + 42), "k_pvp_player_reconnecting_timed:Bea|1:00")
check("the line stops at zero", screen.shown_text(clock + 500), "k_pvp_player_reconnecting_timed:Bea|0:00")
wait()
check("the hidden notice does not come back by itself", #overlays, shown_before)
back("other")
check("back: the line says so", screen.shown_text(clock), "k_pvp_player_reconnected:Bea")
check("the message is gone after a few seconds", screen.shown_text(clock + 5), nil)

-- A drop without a server time still shows the line, with no clock.
drop("other")
wait()
G.OVERLAY_MENU = nil
screen.on_frame()
check("no server time: no countdown", screen.shown_text(clock), "k_pvp_player_reconnecting:Bea")
gone("other")
check("a player who is gone takes the line with them", screen.shown_text(clock), nil)

-- A quick blip never shows the line or the message.
drop("other", clock + 100)
back("other")
check("a quick blip says nothing when back", screen.shown_text(clock), nil)
wait()

-- A new drop after dismissing shows the big notice again.
G.OVERLAY_MENU = nil
drop("other", clock + 100)
wait()
G.OVERLAY_MENU = nil
screen.on_frame()
local count = #overlays
back("other")
drop("other", clock + 100)
wait()
check("a second drop shows the big notice again", #overlays, count + 1)
back("other")

-- Our own drop is hideable too, and leaves a line with no countdown.
clock = clock + 100
G.OVERLAY_MENU = nil
fire("CONNECTION_DROPPED")
wait()
check("own drop shows the notice", overlays[#overlays], "k_mp_reconnecting")
check("own drop notice can be dismissed", no_back[#overlays], false)
G.OVERLAY_MENU = nil
screen.on_frame()
check("dismissed own drop leaves a line", screen.shown_text(clock), "k_mp_reconnecting_line")
fire("CONNECTION_RESTORED")
check("own rejoin clears the line", screen.shown_text(clock), nil)

-- Leaving the lobby clears the line.
drop("other", clock + 100)
wait()
G.OVERLAY_MENU = nil
screen.on_frame()
fire("DISCONNECTED")
check("leaving the lobby clears the line", screen.shown_text(clock), nil)

-- Who is away and when they forfeit come from the roster: a snapshot that holds an away player
-- shows the countdown, and one that holds them back clears it, with no event between.
clock = clock + 100
players = {
	{ id = "me", displayName = "Me", mods = { "MultiplayerPvP-1.0.3" } },
	{ id = "other", displayName = "Bea", mods = { "MultiplayerPvP-1.0.3" }, is_away = true, forfeits_at_local = clock + 62 },
}
PVP.LOBBY.mirror(lobby)
fire("CONNECTED")
wait()
check("joining a lobby with someone away shows the notice", overlays[#overlays], "k_pvp_player_waiting:Bea")
G.OVERLAY_MENU = nil
screen.on_frame()
check("the line counts down to the roster's forfeit time", screen.shown_text(clock), "k_pvp_player_reconnecting_timed:Bea|1:02")
players[2].is_away, players[2].forfeits_at_local = false, nil
fire("SNAPSHOT_APPLIED")
check("a snapshot with them back clears the line", screen.shown_text(clock), nil)
players[2].is_away, players[2].forfeits_at_local = true, clock + 30
fire("SNAPSHOT_APPLIED")
wait()
G.OVERLAY_MENU = nil
screen.on_frame()
check("a snapshot that moves the forfeit time moves the line", screen.shown_text(clock), "k_pvp_player_reconnecting_timed:Bea|0:30")
back("other")

clock = clock + 100
-- In a run pvp_api/ui/away.lua owns the line for others; mine and the reconnected message stay here.
drop("other", clock + 100)
wait()
G.OVERLAY_MENU = nil
screen.on_frame()
in_run = true
check("in a run the other player's line is the banner's", screen.shown_text(clock), nil)
fire("CONNECTION_DROPPED")
wait()
G.OVERLAY_MENU = nil
screen.on_frame()
check("in a run my own drop still shows here", screen.shown_text(clock), "k_mp_reconnecting_line")
fire("CONNECTION_RESTORED")
back("other")
check("in a run the reconnected message still shows here", screen.shown_text(clock), "k_pvp_player_reconnected:Bea")
in_run = false
clock = clock + 100

if failures > 0 then os.exit(1) end
