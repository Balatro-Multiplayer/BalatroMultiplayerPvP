-- Run from the repo root: luajit tests/unit/timer_net_test.lua
-- pvp_api/timer_net.lua with a fake MPAPI and a fake clock, over the real lib/timer_view.lua
-- and the real pvp_api/round_net.lua. Pressing the button is a request; the server's deadline
-- (pvp.round) drives the timer box and the server makes every run-out; nothing here decides
-- who is timed. Rows are named by rule.
local requests, logs, sounds, state, now, config

-- The deadline the server would send; `own = true` leaves out remainingMs (the timed client counts).
local function deadline(fields)
	local d = { kind = "ante", by = "opp", against = { "me" }, remainingMs = 90000, n = 1 }
	for name, value in pairs(fields or {}) do
		d[name] = value
	end
	if d.own then
		d.remainingMs = nil
		d.own = nil
	end
	return d
end

local function setup(opts)
	opts = opts or {}
	requests, logs, sounds, now, state = {}, {}, 0, 0, {}
	config = { timersfx = 3 }
	local lobby = { mod_id = "pvp", player_id = "me", _game = { started = { run_id = "run1" } } }
	if opts.no_run then lobby._game.started = nil end
	PVP = {
		id = "pvp",
		config = config,
		GAME = {
			timer_started = false,
			nemesis_timer_started = false,
			round_id = 3,
		},
		LOBBY = { config = { timer_forgiveness = 2 } },
		UTILS = {
			timer_display_threshold = function()
				return opts.threshold or 0
			end,
		},
		ACTIONS = {},
		UI = {
			restore_timer = function() end,
		},
		match_log = function(level, text)
			logs[#logs + 1] = level .. " " .. text
		end,
		current_ruleset = function()
			return {}
		end,
		is_pvp_boss = function()
			return false
		end,
		RunGate = {
			loaded = function()
				return true
			end,
		},
		Score = {
			from_game_value = function()
				return "0"
			end,
		},
	}
	SMODS = {
		save_mod_config = function() end,
	}
	G = {
		GAME = { round_resets = { ante = 1 }, current_round = { hands_left = 4 } },
		SETTINGS = { GAMESPEED = 1 },
		FUNCS = {},
	}
	Game = {
		update = function() end,
	}
	MPAPI = {
		get_current_lobby = function()
			if opts.no_lobby then return nil end
			return lobby
		end,
		get_state = function(key)
			return state[key]
		end,
		on_state = function() end,
		request = function(kind, payload, on_result)
			requests[#requests + 1] = { kind = kind, payload = payload, on_result = on_result }
		end,
	}
	-- The API's transport state: a held match and whether its connection is up. `opts.transport`
	-- is read on every call, so a test flips it mid-run; no field means a local lobby.
	if opts.transport then
		MPAPI.networking = {
			nakama_lobby = {
				in_match = function()
					return opts.transport.held
				end,
				is_live = function()
					return opts.transport.live
				end,
			},
		}
	end
	dofile("lib/pending_death.lua")
	dofile("lib/_state_value.lua")
	dofile("lib/round_facts.lua")
	dofile("lib/timer_view.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/round_net.lua")
	dofile("pvp_api/timer_net.lua")
	PVP.TimerNet.clock = function()
		return now
	end
	PVP.TimerNet.start_sound = function()
		sounds = sounds + 1
	end
end

-- A state with this deadline arrives (nil: none runs).
local function push(d, run_id, losses)
	state["pvp.round"] = {
		runId = run_id or "run1",
		roundId = 3,
		phase = "playing",
		deadline = d,
		players = { me = { timerLosses = losses or 0, canTime = false } },
	}
	PVP.TimerNet.evaluate()
end

-- `seconds` pass, a frame later.
local function advance(seconds)
	now = now + seconds
	PVP.TimerNet.update()
end

local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

local function near(got, want)
	assert(got ~= nil and math.abs(got - want) < 0.001, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

local function kinds()
	local out = {}
	for _, request in ipairs(requests) do
		out[#out + 1] = request.kind
	end
	return table.concat(out, ",")
end

local failures = 0
local function test(name, fn, opts)
	setup(opts)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

-- The button.

test("start: an Ante timer is one pvp.timer_start with no clock and no bank", function()
	PVP.TimerNet.start("ante")
	equal(kinds(), "pvp.timer_start")
	equal(requests[1].payload.runId, "run1")
	equal(requests[1].payload.kind, "ante")
	equal(requests[1].payload.clock, nil)
	equal(requests[1].payload.ms, nil)
	equal(requests[1].payload.roundId, nil)
end)

test("start: the bank is never sent, whatever the box shows", function()
	PVP.TimerNet.start("ante")
	equal(requests[1].payload.ms, nil)
end)

test("start: a PvP timer names the round and sends no bank or clock", function()
	PVP.TimerNet.start("pvp")
	equal(requests[1].payload.kind, "pvp")
	equal(requests[1].payload.roundId, 3)
	equal(requests[1].payload.ms, nil)
	equal(requests[1].payload.clock, nil)
end)

test("pause: one request naming the run", function()
	PVP.TimerNet.pause()
	equal(kinds(), "pvp.timer_pause")
	equal(requests[1].payload.runId, "run1")
end)

test("no run open: nothing is sent", function()
	PVP.TimerNet.start("ante")
	PVP.TimerNet.start("pvp")
	PVP.TimerNet.pause()
	equal(#requests, 0)
end, { no_run = true })

test("not in PvP's lobby: nothing is sent", function()
	PVP.TimerNet.start("ante")
	PVP.TimerNet.pause()
	equal(#requests, 0)
end, { no_lobby = true })

test("a refusal is logged with its reason and changes nothing", function()
	PVP.TimerNet.start("ante")
	requests[1].on_result(false, { reason = "not_ready" })
	equal(#logs, 1)
	assert(logs[1]:find("pvp.timer_start refused: not_ready", 1, true))
	equal(PVP.GAME.timer_started, false)
	requests[1].on_result(true, {})
	equal(#logs, 1)
end)

-- The un-Ready button: it used to tell the opponent's client the timer was paused.
test("un-Ready sends no timer message", function()
	local file = assert(io.open("ui/game/functions.lua", "r"))
	local text = file:read("*a")
	file:close()
	local header = "function G.FUNCS.mp_toggle_ready(e)"
	local start = assert(text:find(header, 1, true), "function not found")
	local _, finish = text:find("\nend\r?\n", start)
	local calls = {}
	PVP.ACTIONS = setmetatable({}, {
		__index = function(_, name)
			return function()
				calls[#calls + 1] = name
			end
		end,
	})
	PVP.GAME.ready_intent = true
	assert((loadstring or load)(text:sub(start, finish)))()
	G.FUNCS.mp_toggle_ready({})
	equal(PVP.GAME.ready_intent, false)
	local timer_calls = {}
	for _, name in ipairs(calls) do
		if name:find("timer", 1, true) then timer_calls[#timer_calls + 1] = name end
	end
	equal(table.concat(timer_calls, ","), "")
	equal(#requests, 0)
	assert(table.concat(calls, ","):find("unready_blind", 1, true), "un-Ready itself still goes out")
end)

-- The server's deadline.

test("a new n, I started it: the timer box runs from the server's bank, with the start sound", function()
	push(deadline({ by = "me", against = { "opp" }, n = 1 }))
	equal(PVP.GAME.timer_started, true)
	equal(PVP.GAME.nemesis_timer_started, false)
	near(PVP.TimerNet.shown_seconds(), 90)
	equal(sounds, 1)
end)

test("a new n, I am timed: the box runs and the start sound plays", function()
	push(deadline({ n = 1 }))
	equal(PVP.GAME.timer_started, false)
	equal(PVP.GAME.nemesis_timer_started, true)
	near(PVP.TimerNet.shown_seconds(), 90)
	equal(sounds, 1)
end)

test("a third player is not involved: nothing runs, no sound", function()
	push(deadline({ by = "x", against = { "y" } }))
	equal(PVP.GAME.timer_started, false)
	equal(PVP.GAME.nemesis_timer_started, false)
	equal(sounds, 0)
	equal(PVP.TimerNet.shown_seconds(), nil)
end)

test("the display counts down with the time since the state arrived", function()
	push(deadline({ n = 1 }))
	advance(10)
	near(PVP.TimerNet.shown_seconds(), 80)
	advance(25)
	near(PVP.TimerNet.shown_seconds(), 55)
end)

test("the same n again does not reset the countdown, and does not play the sound again", function()
	push(deadline({ n = 1 }))
	advance(10)
	push(deadline({ n = 1 }))
	near(PVP.TimerNet.shown_seconds(), 80)
	equal(sounds, 1)
end)

test("a new n restarts the countdown from the server's time, with no sound", function()
	push(deadline({ n = 1 }))
	advance(30)
	push(deadline({ n = 2, remainingMs = 60000 }))
	near(PVP.TimerNet.shown_seconds(), 60)
	equal(sounds, 1)
end)

test("a snapshot starts the countdown again from its own time left, with no sound", function()
	push(deadline({ n = 1 }))
	advance(10)
	PVP.TimerNet.on_snapshot()
	push(deadline({ n = 1, remainingMs = 50000 }))
	advance(0)
	near(PVP.TimerNet.shown_seconds(), 50)
	advance(5)
	near(PVP.TimerNet.shown_seconds(), 45)
	equal(sounds, 1)
end)

test("a snapshot into a fresh client plays no sound and shows the time left", function()
	PVP.TimerNet.on_snapshot()
	push(deadline({ n = 4, remainingMs = 33000 }))
	advance(0)
	near(PVP.TimerNet.shown_seconds(), 33)
	equal(PVP.GAME.nemesis_timer_started, true)
	equal(sounds, 0)
end)

-- The server's pushes carry the time frozen at the n's start; only a snapshot carries the live time.
test("a push of the snapshot's n carries the frozen time: the countdown keeps the live one", function()
	PVP.TimerNet.on_snapshot()
	push(deadline({ n = 4, remainingMs = 33000 }))
	advance(0)
	advance(3)
	push(deadline({ n = 4, remainingMs = 150000 }))
	near(PVP.TimerNet.shown_seconds(), 30)
	advance(2)
	near(PVP.TimerNet.shown_seconds(), 28)
end)

test("a push in the snapshot's own frame is a push: the snapshot is the first value read", function()
	PVP.TimerNet.on_snapshot()
	push(deadline({ n = 4, remainingMs = 33000 }))
	push(deadline({ n = 4, remainingMs = 150000 }))
	near(PVP.TimerNet.shown_seconds(), 33)
	advance(0)
	near(PVP.TimerNet.shown_seconds(), 33)
	equal(sounds, 0)
end)

test("a push of the same n still refreshes who is timed", function()
	push(deadline({ n = 1 }))
	push(deadline({ n = 1, by = "me", against = { "opp" } }))
	equal(PVP.GAME.timer_started, true)
	equal(PVP.GAME.nemesis_timer_started, false)
	near(PVP.TimerNet.shown_seconds(), 90)
end)

test("a snapshot that notifies nothing is read on the next frame", function()
	push(deadline({ n = 4, remainingMs = 33000 }))
	advance(10)
	PVP.TimerNet.on_snapshot()
	state["pvp.round"] =
		{ runId = "run1", roundId = 3, phase = "playing", deadline = deadline({ n = 4, remainingMs = 20000 }) }
	advance(0)
	near(PVP.TimerNet.shown_seconds(), 20)
	advance(5)
	near(PVP.TimerNet.shown_seconds(), 15)
end)

-- A crash rejoin: the lobby is attached after its first snapshot, which fired no event.
test("a crash rejoin: the first value is the snapshot's, no sound, and the replayed push keeps the time", function()
	state["pvp.round"] =
		{ runId = "run1", roundId = 3, phase = "playing", deadline = deadline({ n = 5, remainingMs = 20000 }) }
	PVP.TimerNet.on_connected()
	near(PVP.TimerNet.shown_seconds(), 20)
	equal(PVP.GAME.nemesis_timer_started, true)
	equal(sounds, 0)
	advance(2)
	push(deadline({ n = 5, remainingMs = 150000 }))
	near(PVP.TimerNet.shown_seconds(), 18)
	equal(sounds, 0)
end)

-- The run's rejoin hooks (lib/rejoin.lua), as MPAPI's rejoin flow calls them.
local function rejoin_hooks()
	local hooks
	MPAPI.playback = {
		register_rejoin_hooks = function(_, registered)
			hooks = registered
		end,
	}
	dofile("lib/rejoin.lua")
	return hooks
end

test("resumed with a server-counted countdown still shown: it keeps its time and its run-out", function()
	local hooks = rejoin_hooks()
	PVP.TimerNet.on_snapshot()
	push(deadline({ n = 4, remainingMs = 2000 }))
	advance(0)
	advance(3)
	push(deadline({ n = 4, remainingMs = 150000 }))
	hooks.resumed()
	near(PVP.TimerNet.shown_seconds(), 0)
end)

test("a crash rejoin whose lobby is set up anew: a server-counted deadline times me again", function()
	local hooks = rejoin_hooks()
	state["pvp.round"] = {
		runId = "run1",
		roundId = 3,
		phase = "playing",
		deadline = deadline({ kind = "pvp", n = 1, remainingMs = 40000 }),
	}
	PVP.TimerNet.on_connected()
	-- The lobby set up anew resets the game's timer fields; the box's deadline stays shown.
	PVP.GAME.timer_started = false
	PVP.GAME.nemesis_timer_started = false
	PVP.TimerNet.on_connected()
	hooks.resumed()
	equal(PVP.GAME.nemesis_timer_started, true)
	near(PVP.TimerNet.shown_seconds(), 40)
	equal(sounds, 0)
end)

test("a crash rejoin whose lobby is set up anew: a server-counted deadline I started shows it started", function()
	local hooks = rejoin_hooks()
	state["pvp.round"] = {
		runId = "run1",
		roundId = 3,
		phase = "playing",
		deadline = deadline({ kind = "pvp", n = 1, by = "me", against = { "opp" }, remainingMs = 40000 }),
	}
	PVP.TimerNet.on_connected()
	PVP.GAME.timer_started = false
	PVP.GAME.nemesis_timer_started = false
	PVP.TimerNet.on_connected()
	hooks.resumed()
	equal(PVP.GAME.timer_started, true)
	equal(PVP.GAME.nemesis_timer_started, false)
end)

test("connecting while a deadline is already shown catches up on nothing", function()
	push(deadline({ n = 1 }))
	advance(10)
	PVP.TimerNet.on_connected()
	near(PVP.TimerNet.shown_seconds(), 80)
	equal(sounds, 1)
end)

test("connecting with no deadline leaves the box without a deadline time", function()
	PVP.TimerNet.on_connected()
	equal(PVP.TimerNet.shown_seconds(), nil)
	equal(PVP.GAME.nemesis_timer_started, false)
	push(deadline({ n = 1 }))
	equal(sounds, 1)
end)

test("the lobby bridge reads the deadline's snapshot at CONNECTED, before the replay", function()
	local file = assert(io.open("pvp_api/lobby_bridge.lua", "r"))
	local text = file:read("*a")
	file:close()
	local connected = assert(text:find("lobby:on(MPAPI.LobbyEvent.CONNECTED", 1, true))
	local next_handler = text:find("lobby:on(", connected + 10, true) or #text
	local loop = assert(text:find("PVP.CONNECTED_ORDER", connected, true), "CONNECTED must run the declared order")
	assert(loop < next_handler, "the loop belongs to the CONNECTED handler")
	assert(text:find('PVP.CONNECTED_ORDER = { "ReadyNet", "TimerNet",', 1, true), "TimerNet reads right after ReadyNet")
end)

test("the deadline gone clears both flags and the box has no deadline time", function()
	push(deadline({ by = "me", against = { "opp" } }))
	advance(10)
	push(nil)
	equal(PVP.GAME.timer_started, false)
	equal(PVP.GAME.nemesis_timer_started, false)
	equal(PVP.TimerNet.shown_seconds(), nil)
	advance(20)
	equal(PVP.TimerNet.shown_seconds(), nil)
end)

test("no value for pvp.round at all clears both flags", function()
	PVP.GAME.timer_started = true
	PVP.GAME.nemesis_timer_started = true
	state["pvp.round"] = nil
	PVP.TimerNet.evaluate()
	equal(PVP.GAME.timer_started, false)
	equal(PVP.GAME.nemesis_timer_started, false)
end)

test("a deadline of another run is not mine", function()
	push(deadline({ n = 1 }), "run0")
	equal(PVP.GAME.nemesis_timer_started, false)
	equal(sounds, 0)
end)

test("after a deadline was dropped, the same n starts again", function()
	push(deadline({ n = 1 }))
	push(nil)
	push(deadline({ n = 1, remainingMs = 40000 }))
	near(PVP.TimerNet.shown_seconds(), 40)
	equal(PVP.GAME.nemesis_timer_started, true)
end)

test("stop: the flags clear, the box has no deadline time, and only a new n shows a deadline again", function()
	push(deadline({ n = 1 }))
	PVP.TimerNet.stop()
	equal(PVP.GAME.nemesis_timer_started, false)
	equal(PVP.TimerNet.shown_seconds(), nil)
	advance(5)
	push(deadline({ n = 1 }))
	equal(PVP.GAME.nemesis_timer_started, false)
	equal(PVP.TimerNet.shown_seconds(), nil)
	push(deadline({ n = 2, remainingMs = 20000 }))
	equal(PVP.GAME.nemesis_timer_started, true)
	near(PVP.TimerNet.shown_seconds(), 20)
end)

-- A server-counted countdown reaches 0.

test("a server-counted countdown reaching 0 sends nothing: the server makes the run-out", function()
	push(deadline({ n = 1, remainingMs = 5000 }))
	advance(100)
	equal(PVP.TimerNet.shown_seconds(), 0)
	advance(5)
	equal(#requests, 0)
	push(deadline({ n = 2, remainingMs = 5000 }))
	near(PVP.TimerNet.shown_seconds(), 5)
end)

test("the display never goes below 0", function()
	push(deadline({ by = "me", against = { "opp" }, remainingMs = 1000 }))
	advance(50)
	equal(PVP.TimerNet.shown_seconds(), 0)
end)

-- A paused server deadline: a timed player is disconnected, the server holds the time.

test("paused: the box shows the frozen time and stands still, with no run-out", function()
	push(deadline({ n = 1, remainingMs = 90000 }))
	advance(10)
	near(PVP.TimerNet.shown_seconds(), 80)
	push(deadline({ n = 1, remainingMs = 90000, paused = true }))
	near(PVP.TimerNet.shown_seconds(), 90)
	advance(500)
	near(PVP.TimerNet.shown_seconds(), 90)
	equal(PVP.GAME.nemesis_timer_started, true)
	equal(#requests, 0)
end)

test("paused: a frozen 0 is not a run-out", function()
	push(deadline({ n = 1, remainingMs = 0, paused = true }))
	advance(5)
	equal(PVP.TimerNet.shown_seconds(), 0)
end)

test("paused: the next state without it resumes from the frozen time", function()
	push(deadline({ n = 1, remainingMs = 90000 }))
	advance(30)
	push(deadline({ n = 1, remainingMs = 60000, paused = true }))
	advance(100)
	near(PVP.TimerNet.shown_seconds(), 60)
	push(deadline({ n = 1, remainingMs = 90000 }))
	near(PVP.TimerNet.shown_seconds(), 60)
	advance(10)
	near(PVP.TimerNet.shown_seconds(), 50)
	advance(2)
	push(deadline({ n = 1, remainingMs = 90000 }))
	near(PVP.TimerNet.shown_seconds(), 48)
end)

test("paused: a snapshot of a paused deadline shows it frozen, with no sound", function()
	PVP.TimerNet.on_snapshot()
	push(deadline({ n = 4, remainingMs = 33000, paused = true }))
	advance(0)
	advance(60)
	near(PVP.TimerNet.shown_seconds(), 33)
	equal(sounds, 0)
end)

-- My own disconnect: the API holds the lobby (in_match) while its connection is down (not is_live).

-- MLBa's display threshold.

test("threshold: the timed player's box is idle while the server's time is above it", function()
	push(deadline({ remainingMs = 300000 }))
	equal(PVP.GAME.nemesis_timer_started, false)
	equal(sounds, 0)
	advance(100)
	equal(PVP.GAME.nemesis_timer_started, false)
end, { threshold = 180 })

-- A timed player's box shows their own bank while the server's time is above the threshold.
test("threshold: above it the deadline gives the box no time, at it the box has the server's time", function()
	push(deadline({ remainingMs = 300000 }))
	equal(PVP.TimerNet.shown_seconds(), nil)
	advance(119)
	equal(PVP.TimerNet.shown_seconds(), nil)
	advance(2)
	near(PVP.TimerNet.shown_seconds(), 179)
end, { threshold = 180 })

test("threshold: at the threshold the box runs and the start sound plays", function()
	push(deadline({ remainingMs = 300000 }))
	advance(119)
	equal(PVP.GAME.nemesis_timer_started, false)
	equal(sounds, 0)
	advance(1)
	equal(PVP.GAME.nemesis_timer_started, true)
	equal(sounds, 1)
	advance(30)
	near(PVP.TimerNet.shown_seconds(), 150)
	equal(sounds, 1)
end, { threshold = 180 })

test("threshold: the starter sees the whole bank, running, with the sound at once", function()
	push(deadline({ by = "me", against = { "opp" }, remainingMs = 300000 }))
	near(PVP.TimerNet.shown_seconds(), 300)
	equal(PVP.GAME.timer_started, true)
	equal(sounds, 1)
end, { threshold = 180 })

test("threshold: a snapshot above it keeps the box idle and quiet", function()
	PVP.TimerNet.on_snapshot()
	push(deadline({ n = 3, remainingMs = 250000 }))
	advance(0)
	equal(PVP.TimerNet.shown_seconds(), nil)
	equal(PVP.GAME.nemesis_timer_started, false)
	advance(70)
	equal(PVP.GAME.nemesis_timer_started, true)
	near(PVP.TimerNet.shown_seconds(), 180)
	equal(sounds, 0)
end, { threshold = 180 })

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
