-- Run from the repo root: luajit tests/unit/spectate_feed_test.lua
-- A spectator loads the watched player's Run save and the events after it, then follows the
-- live feed; a switch does the same for the new player.
local checks = 0
local function check(condition, message)
	checks = checks + 1
	assert(condition, message)
end

local feed_handlers, requests, seeks, drivers, started_with = nil, {}, {}, {}, {}
local decode_ok = true
local fail_load_with = nil
local stopped_spectating = false
local saved_state = { T2 = { lives = 2 } }

PVP = { id = "MultiplayerPvP", GAME = {} }
-- The fresh-match defaults (core.lua's PVP.reset_game_states), cut down to a few keys.
function PVP.reset_game_states()
	PVP.GAME = { lives = 0, timer = 120 }
end
function PVP.in_session() return true end
local run_save_hooks
function PVP._start_playback(manifest, on_ready)
	started_with[#started_with + 1] = manifest
	on_ready()
end

local function new_driver_stub()
	local driver = { events = {}, played = false }
	function driver:push_event(entry) self.events[#self.events + 1] = entry end
	function driver:play() self.played = true end
	function driver:stop() self.stopped = true end
	return driver
end

MPAPI = {
	sendWarnMessage = function() end,
	OPCODE = { SET_ANTE_KEY = "ante", HAND_RESULT = "hand" },
	replay = {
		spectate_lobby = function(_, callback, handlers)
			feed_handlers = handlers
			callback(nil, {
				snapshot = {
					{ playerId = "a", manifest = { seed = "S", deck = "d", ruleset = "r", gamemode = "g" } },
					{ playerId = "b", manifest = { seed = "S", deck = "d", ruleset = "r", gamemode = "g" } },
				},
			})
		end,
		stop_spectating = function() stopped_spectating = true end,
		request_spectate_run = function(player_id, from_start)
			requests[#requests + 1] = { player = player_id, from_start = from_start }
			return true
		end,
	},
	run_save = {
		register_state = function(_, hooks) run_save_hooks = hooks end,
		decode = function(text)
			if decode_ok then return { text = text, mods = { MultiplayerPvP = saved_state[text] } } end
			return nil, "unreadable"
		end,
	},
	playback = {
		dispatch = function() end,
		restart_session_and_seek = function(session, target, on_ready, opts)
			seeks[#seeks + 1] = { session = session, target = target, opts = opts }
			opts.start_run(session.bootstrap, function()
				local driver = new_driver_stub()
				drivers[#drivers + 1] = driver
				if opts.run_save then
					run_save_hooks.load(opts.run_save.envelope.mods.MultiplayerPvP or {})
				end
				if fail_load_with and opts.run_save then
					opts.on_load_failed(fail_load_with)
					return
				end
				on_ready(driver)
			end)
		end,
	},
}
dofile("lib/run_save.lua")
dofile("pvp_api/spectate_feed.lua")
local S = PVP.SPECTATE

local function answer(player, extra)
	local data = { playerId = player, pos = 0, events = {} }
	for k, v in pairs(extra or {}) do data[k] = v end
	feed_handlers.run(data)
end
local function event(player, opcode) return { t = 1, player_id = player, opcode = opcode, args = {} } end

-- Joining: the first player is in view and their run is requested.
S.start("CODE", function() end)
check(#requests == 1 and requests[1].player == "a" and not requests[1].from_start, "the player in view is requested")
check(#seeks == 0, "nothing starts before the answer")

-- Live events that arrive before the answer are in the answer already.
feed_handlers.event(event("a", "early"))
check(#drivers == 0, "an early live event starts nothing")

-- An answer with a Run save: the run starts from it, with only the later events in the timeline.
answer("a", {
	runSave = { id = "s", pos = 40, hash = "h", data = "TEXT" },
	pos = 40,
	events = { { t = 5, opcode = "play", args = {} }, { t = 6, opcode = "buy", args = {} } },
})
local seek = seeks[1]
check(seek.opts.run_save and seek.opts.run_save.envelope.text == "TEXT", "the Run save is loaded")
check(seek.opts.run_save.pos == 40 and seek.opts.run_save.events_follow, "its events follow it")
check(seek.opts.live, "the driver stays open for the live feed")
check(#seek.session.timeline == 2 and seek.session.timeline[1].player_id == "a", "the later events are the timeline")
check(seek.target == 3, "the seek covers all of them")
check(#started_with == 1 and started_with[1].seed == "S", "the local run starts from the manifest")
check(drivers[1].played and S._driver == drivers[1], "the driver plays")
feed_handlers.event(event("a", "after"))
check(drivers[1].events[1] and drivers[1].events[1].opcode == "after", "later live events go to the driver")
check(drivers[1].events[2] == nil and #drivers[1].events == 1, "and the early one did not")

-- Switching: the other player's run is requested and loaded the same way; the old driver stops.
S.switch_to("b")
check(requests[2].player == "b", "a switch requests the new player")
feed_handlers.event(event("b", "dropped"))
answer("a", { events = {} })
check(#seeks == 1, "an answer for the old player is ignored")
PVP.GAME.watched_a_only = "a's value"
PVP.GAME.timer = 7
answer("b", { runSave = { id = "s2", pos = 10, hash = "h", data = "T2" }, pos = 10 })
check(PVP.GAME.lives == 2 and PVP.GAME.watched_a_only == nil and PVP.GAME.timer == 120, "the switch shows the new player's match state and none of the earlier player's")
check(drivers[1].stopped, "the old driver stopped")
check(#seeks == 2 and seeks[2].opts.run_save.envelope.text == "T2" and seeks[2].session.my_id == "b", "the new player's save is loaded")

-- No Run save: the events from the start play on a fresh run.
S.switch_to("a")
answer("a", { events = { { t = 1, opcode = "run_info", args = {} } } })
check(seeks[3].opts.run_save == nil and seeks[3].opts.live, "no save: a plain playback of the log")

-- A Run save that does not read: ask again for the whole log.
decode_ok = false
S.switch_to("b")
answer("b", { runSave = { id = "s3", pos = 5, hash = "h", data = "BAD" }, pos = 5 })
check(requests[#requests].from_start and requests[#requests].player == "b", "an unreadable save asks for the whole log")
check(#seeks == 3, "and starts nothing yet")
decode_ok = true
answer("b", { events = { { t = 1, opcode = "run_info", args = {} } } })
check(#seeks == 4 and seeks[4].opts.run_save == nil, "the whole log then plays")

-- A Run save that fails to load: the same.
fail_load_with = "bad state"
S.switch_to("a")
local before = #requests
answer("a", { runSave = { id = "s4", pos = 5, hash = "h", data = "X" }, pos = 5 })
check(requests[before + 1].from_start and requests[before + 1].player == "a", "a failed load asks for the whole log")
fail_load_with = nil

-- Stopping ends the feed and the driver.
S.stop()
check(stopped_spectating and not S.is_active() and S._driver == nil, "stop ends watching")
feed_handlers.event(event("a", "late"))

print(string.format("spectate_feed_test: %d checks passed", checks))
