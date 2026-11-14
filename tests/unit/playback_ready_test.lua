-- Plain Lua test: a playback run start reports the new run as soon as it exists, and each caller
-- waits for the screen it needs. A run loaded from a Run save can come up in the shop, and the old
-- start waited for Blind Select only, so a rejoin from a shop save never went on. The replay
-- browser plays from Blind Select, so it waits for it itself (MPAPI.playback.when_screen_ready).
-- The rejoin hooks declare the shop as a Run save screen.
-- Run from the repo root: luajit tests/unit/playback_ready_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local connected
local local_lobby = {
	on = function(_, _, fn)
		connected = fn
	end,
	set_metadata = function() end,
}
MPAPI = {
	matchmaking = {
		guard_queued = function()
			return false
		end,
	},
	create_local_lobby = function()
		return local_lobby
	end,
	LobbyEvent = { CONNECTED = "connected", DISCONNECTED = "disconnected" },
	playback = {},
}
PVP = {
	id = "pvp",
	LOBBY = { config = { starting_lives = 4 } },
	GAME = { enemy = {} },
	SP = {},
	LobbyAccess = { PRACTICE = "practice" },
	playback_gamemode_of = function() end,
	reset_lobby_config = function() end,
	setup_lobby_mirror = function() end,
	apply_replay_loadout = function() end,
	pvp_lobby_metadata = function() end,
}
G = { STATES = { SHOP = 5, BLIND_SELECT = 7 }, STATE = 0, GAME = { name = "old run" }, FUNCS = {} }
Game = { update = function() end }
dofile("lib/playback_launch.lua")
local function frame()
	Game.update(G, 0.016)
end

-- 1. The new run comes up in the shop (a Run save taken there): on_ready fires.
local ready = 0
PVP._start_playback({ seed = "s" }, function()
	ready = ready + 1
end)
G.STATE = G.STATES.BLIND_SELECT
frame()
check("the old run's screen does not count", ready, 0)
G.GAME = { name = "new run" }
G.STATE = G.STATES.SHOP
frame()
check("the new run in the shop is ready", ready, 1)
frame()
check("and only once", ready, 1)

-- 2. The replay browser builds its driver only once the run shows Blind Select.
local waited_for, on_screen
MPAPI.playback.when_screen_ready = function(screen, cb)
	waited_for, on_screen = screen, cb
end
local drivers = 0
MPAPI.playback.new_driver = function()
	drivers = drivers + 1
	return { finish = function() end, play = function() end }
end
MPAPI.playback.register_launcher = function() end
MPAPI.playback.build_timeline = function()
	return {}
end
MPAPI.get_replay_player_id = function()
	return "me"
end
MPAPI.replay = {
	get = function(_, cb)
		cb(nil, { logs = {} })
	end,
	is_schema_compatible = function()
		return true
	end,
	SCHEMA_VERSION = 1,
}
PVP.replay_bootstrap = function()
	return { schema_version = 1 }
end
PVP._start_playback = function(_, on_ready)
	on_ready()
end
dofile("ui/replay/replay_browser.lua")
PVP._launch_replay("RUN1")
check("the replay waits for Blind Select", waited_for, "BLIND_SELECT")
check("no driver before Blind Select", drivers, 0)
if on_screen then on_screen() end
check("the driver is built at Blind Select", drivers, 1)

-- 3. The rejoin hooks declare the shop as a Run save screen.
local hooks
MPAPI.playback.register_rejoin_hooks = function(_, h)
	hooks = h
end
dofile("lib/rejoin.lua")
check("the rejoin hooks declare SHOP", hooks and hooks.run_save_screens and hooks.run_save_screens.SHOP, true)

if failures > 0 then error(("%d check(s) failed"):format(failures)) end
print("playback_ready_test: all checks passed")
