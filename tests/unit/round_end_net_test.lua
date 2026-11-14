-- Run from the repo root: luajit tests/unit/round_end_net_test.lua
-- The shell around lib/round_end_view.lua with stubbed MPAPI, handlers and run gate: a
-- round end and a pending death each apply once per run, only in a loaded run of the
-- current run id.
local calls, states, listeners, lobby, gate_open, in_blind

local passed, failed = 0, 0
local function check(name, got, want)
	if got == want then
		passed = passed + 1
		print("ok   " .. name)
	else
		failed = failed + 1
		print(("FAIL %s: got %s, wanted %s"):format(name, tostring(got), tostring(want)))
	end
end

local function setup(game)
	calls, states, listeners, gate_open, in_blind = {}, {}, {}, true, true
	lobby = { mod_id = "pvp", player_id = "a", _game = { started = { run_id = "r1" } } }
	-- Rows are in round 1's PvP blind unless they say otherwise (PVP.GAME.round_id, in_blind).
	game = game or {}
	game.round_id = game.round_id or 1
	G = {
		STAGE = "run",
		STAGES = { RUN = "run" },
		GAME = { blind = { in_blind = true }, current_round = { hands_left = 3 } },
	}
	PVP = {
		id = "pvp",
		GAME = game,
		is_pvp_boss = function()
			return in_blind
		end,
		end_pending_death = function()
			calls[#calls + 1] = "end_pending_death"
		end,
		HANDLERS = {
			handsSpent = function()
				calls[#calls + 1] = "handsSpent"
			end,
			endPvP = function()
				calls[#calls + 1] = "endPvP"
			end,
			deathPending = function(args)
				calls[#calls + 1] = ("deathPending %s %s %s"):format(
					tostring(args.player_id),
					tostring(args.opponent_id),
					tostring(args.blind_key)
				) .. (args.team_id and (" team=" .. args.team_id) or "")
			end,
		},
		RunGate = {
			-- The real gate is closed while the lobby attach holds the run (lobby._holding).
			loaded = function()
				return gate_open and not lobby._holding
			end,
		},
	}
	MPAPI = {
		get_current_lobby = function()
			return lobby
		end,
		get_state = function(key)
			return states[key]
		end,
		on_state = function(key, fn)
			listeners[key] = fn
		end,
	}
	dofile("lib/_state_value.lua")
	dofile("lib/result_view.lua")
	dofile("lib/lives_view.lua")
	dofile("lib/round_end_view.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/round_end_net.lua")
end

local function tick()
	PVP.RoundEndNet.update()
end

local function round_state(roundId, losers, runId)
	return {
		runId = runId or "r1",
		roundId = roundId,
		phase = "resolved",
		lastResult = { roundId = roundId, losers = losers },
	}
end
local MINE = { playerId = "a", blindKey = "2:Big", waitsOn = { "b" } }

setup()
check("subscribes to the round", type(listeners["pvp.round"]), "function")
check("subscribes to the lives", type(listeners["pvp.lives"]), "function")

-- I lost round 1.
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
check("5: a lost round calls endPvP once", #calls, 1)
check("5: lost", calls[1], "endPvP")
listeners["pvp.round"]()
listeners["pvp.round"]()
states["pvp.lives"] = { runId = "r1", players = {}, pending = {} }
listeners["pvp.lives"]()
tick()
check("5: the same STATE three times, a SNAPSHOT and a tick: still once", #calls, 1)

setup()
states["pvp.round"] = round_state(1, { "b" })
listeners["pvp.round"]()
check("5: I won -> lost=false", calls[1], "endPvP")

-- Gate closed.
setup()
gate_open = false
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
tick()
check("gate closed: nothing applies", #calls, 0)
gate_open = true
tick()
check("gate opens: applied on the next tick", #calls, 1)
tick()
listeners["pvp.round"]()
check("gate opens: and only once", #calls, 1)

setup()
gate_open = false
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
gate_open = true
listeners["pvp.round"]()
check("gate opens: or on the next STATE", #calls, 1)

-- Eliminated.
setup({ eliminated = true })
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
check("7: an eliminated player gets no endPvP", #calls, 0)

-- Another run.
setup()
states["pvp.round"] = round_state(1, { "a" }, "r0")
listeners["pvp.round"]()
tick()
check("another run's round applies nothing", #calls, 0)
lobby._game.started = nil
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
tick()
check("no current run applies nothing", #calls, 0)

setup()
lobby.mod_id = "other"
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
check("another mod's lobby applies nothing", #calls, 0)

-- A new run applies its own round 1 again.
setup()
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
lobby._game.started.run_id = "r2"
states["pvp.round"] = round_state(1, { "b" }, "r2")
listeners["pvp.round"]()
check("a new run's round 1 applies again", #calls, 2)
check("a new run's round 1 is its own result", calls[2], "endPvP")

-- Pending death.
setup()
states["pvp.lives"] = { runId = "r1", players = {}, pending = { MINE } }
listeners["pvp.lives"]()
listeners["pvp.lives"]()
check("65: my pending entry calls deathPending once", #calls, 1)
check("65: with the opponent from waitsOn", calls[1], "deathPending a b 2:Big")
states["pvp.lives"] = { runId = "r1", players = {}, pending = {} }
listeners["pvp.lives"]()
listeners["pvp.lives"]()
check("98: my entry removed -> end_pending_death once", #calls, 2)
check("98: it is end_pending_death", calls[2], "end_pending_death")

setup()
states["pvp.lives"] = { runId = "r1", players = {}, pending = { MINE } }
listeners["pvp.lives"]()
states["pvp.result"] = { runId = "r1", kind = "win", places = { { playerId = "a", place = 1 } } }
states["pvp.lives"] = { runId = "r1", players = {}, pending = {} }
listeners["pvp.lives"]()
check("98: a set result ends the screen, not this", #calls, 1)

setup()
states["pvp.lives"] =
	{ runId = "r1", players = {}, pending = { { playerId = "b", blindKey = "2:Big", waitsOn = { "a" } } } }
listeners["pvp.lives"]()
check("85: opponent's entry gives deathPending with my id as waitsOn", calls[1], "deathPending b a 2:Big")
check("85: once", #calls, 1)

-- F9: the started player count (pvp.rules) picks the branch, not the wait list's length.
setup()
states["pvp.rules"] = { runId = "r1", mode = "royale", startedCount = 3 }
states["pvp.lives"] = { runId = "r1", players = {}, pending = { MINE } }
listeners["pvp.lives"]()
check("F9: 3 started, wait list of 1: no opponent named", calls[1], "deathPending a nil 2:Big")
setup()
states["pvp.rules"] = { runId = "r1", mode = "standard", startedCount = 2 }
states["pvp.lives"] = { runId = "r1", players = {}, pending = { MINE } }
listeners["pvp.lives"]()
check("F9: 2 started: the opponent from waitsOn", calls[1], "deathPending a b 2:Big")
setup()
states["pvp.rules"] = { runId = "r0", mode = "royale", startedCount = 3 }
states["pvp.lives"] = { runId = "r1", players = {}, pending = { MINE } }
listeners["pvp.lives"]()
check("F9: rules of another run are ignored (the list length decides)", calls[1], "deathPending a b 2:Big")

-- 98 vs ResultNet: the pending entry clears before the result is read here, so this net ends
-- the screen once; a later ResultNet call is its own (the function is idempotent).
setup()
states["pvp.lives"] = { runId = "r1", players = {}, pending = { MINE } }
listeners["pvp.lives"]()
states["pvp.lives"] = { runId = "r1", players = {}, pending = {} }
listeners["pvp.lives"]()
states["pvp.result"] = { runId = "r1", kind = "win", places = { { playerId = "a", place = 1 } } }
listeners["pvp.lives"]()
tick()
check("98: lives cleared before the result: this net ends the screen exactly once", #calls, 2)
check("98: that call is end_pending_death", calls[2], "end_pending_death")

-- Socket reconnect: the same process, the same PVP.GAME; every push replays.
setup()
states["pvp.round"] = round_state(1, { "a" })
states["pvp.lives"] = { runId = "r1", players = {}, pending = { MINE } }
listeners["pvp.round"]()
check("socket reconnect: first apply runs both", #calls, 2)
listeners["pvp.round"]()
listeners["pvp.lives"]()
tick()
check("socket reconnect: the replay applies nothing", #calls, 2)

-- Process restart: the module is loaded again and PVP.GAME comes back from the run save.
-- The marks are PVP.GAME.round_end_applied (saved), not module memory.
setup()
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
check("restart (a): round 1 applied before the crash", #calls, 1)
local saved = PVP.GAME
setup(saved)
states["pvp.round"] = { runId = "r1", roundId = 2, phase = "playing", lastResult = { roundId = 1, losers = { "a" } } }
lobby.player_id = "a"
listeners["pvp.round"]()
tick()
check("restart (a): mid-round-2, round 1 is not applied again", #calls, 0)

-- No-save rejoin in blind 2: the catch-up starts from a fresh PVP.GAME with no marks, ReadyNet
-- adopted lastStart (round_id 2), and the server's lastResult is still round 1's. Round 1's
-- end is not applied, and is marked.
setup({ round_id = 2 })
states["pvp.round"] = { runId = "r1", roundId = 2, phase = "playing", lastResult = { roundId = 1, losers = { "a" } } }
listeners["pvp.round"]()
tick()
check("no-save rejoin in blind 2: round 1's end is not applied", #calls, 0)
check("no-save rejoin in blind 2: its mark is recorded", PVP.GAME.round_end_applied.rounds[1], true)
states["pvp.round"] = round_state(2, { "a" })
listeners["pvp.round"]()
check("no-save rejoin in blind 2: round 2's own end still applies", #calls, 1)

-- Rejoin in the shop after round 1 (residual note 5): marked, no endPvP, so no late end_pvp flag.
setup({ round_id = 1 })
in_blind = false
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
tick()
check("rejoin in the shop after round 1: no endPvP", #calls, 0)
check("rejoin in the shop after round 1: marked", PVP.GAME.round_end_applied.rounds[1], true)
in_blind = true
listeners["pvp.round"]()
check("rejoin in the shop: entering a later blind does not apply it", #calls, 0)

-- A PvP boss that is no longer in its blind (the blind's flag is off) is the shop too.
setup({ round_id = 1 })
G.GAME.blind.in_blind = false
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
check("blind flag off: no endPvP", #calls, 0)

-- The live normal case: in round 1's PvP blind when its result arrives.
setup({ round_id = 1 })
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
listeners["pvp.round"]()
check("live: in blind 1 when round 1 resolves, applies once", #calls, 1)

-- A round id that is not the result's (nil, or another round) only marks.
setup({ round_id = 3 })
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
check("round id 3 in the blind: round 1's result only marks", #calls, 0)
setup()
PVP.GAME.round_id = nil
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
check("no round id yet: only marks", #calls, 0)

-- Round 2 resolved while the player was down: the saved marks lack it, and the rejoin
-- adopted lastStart 2 while the player is in blind 2.
setup(saved)
PVP.GAME.round_id = 2
states["pvp.round"] = round_state(2, { "b" })
listeners["pvp.round"]()
listeners["pvp.round"]()
tick()
check("restart (b): a round decided while down applies once", #calls, 1)
check("restart (b): as a win", calls[1], "endPvP")

-- Marks of another run are dropped.
setup({ round_end_applied = { run_id = "r0", rounds = { [1] = true }, pending = {} } })
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
check("marks of another run do not block this run's round 1", #calls, 1)

-- Restart (c): a rejoin snapshot arrives before the lobby's started run is set, then the
-- lobby attach holds the gate, CONNECTED calls on_connected(), the hold clears, a frame runs.
setup()
lobby._holding = true
lobby._game.started = nil
states["pvp.round"] = round_state(1, { "a" })
listeners["pvp.round"]()
tick()
check("restart (c): no current run yet, nothing applies", #calls, 0)
lobby._game.started = { run_id = "r1" }
PVP.RoundEndNet.on_connected()
check("restart (c): on_connected while the run is held applies nothing", #calls, 0)
lobby._holding = nil
tick()
check("restart (c): the frame after the hold clears applies once", #calls, 1)
tick()
PVP.RoundEndNet.on_connected()
check("restart (c): and only once", #calls, 1)

-- Rejoin INSIDE PvP blind 3 with lastResult 3 already there. The lobby attach holds the run
-- for the whole CONNECTED handler, where ReadyNet restores PVP.GAME.round_id from lastStart
-- (no startBlind) and RoundEndNet.on_connected is called; the round is read once the hold clears.
local function load_ready_net()
	dofile("lib/_state_value.lua")
	dofile("lib/ready_view.lua")
	function lobby:get_players()
		return { { id = "a" }, { id = "b" } }
	end
	PVP.dispatch_action = function(name)
		calls[#calls + 1] = "dispatch " .. name
	end
	localize = function(key)
		return key
	end
	local round_value = states["pvp.round"]
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/ready_net.lua")
	states["pvp.round"] = round_value
end
local function rejoin_in_blind_3()
	setup()
	PVP.GAME.round_id = nil
	lobby._holding = true
	states["pvp.ready"] = {
		runId = "r1",
		round = 3,
		ready = {},
		out = {},
		lastStart = { roundId = 3, firstPlayer = "a", players = { "a", "b" } },
	}
	states["pvp.round"] =
		{ runId = "r1", roundId = 3, phase = "resolved", lastResult = { roundId = 3, losers = { "a" } } }
	load_ready_net()
end

rejoin_in_blind_3()
check("rejoin inside blind 3: nothing applied before CONNECTED", #calls, 0)
PVP.ReadyNet.evaluate()
check("rejoin inside blind 3: ReadyNet adopts the round without a startBlind", #calls, 0)
check("rejoin inside blind 3: PVP.GAME.round_id is 3", PVP.GAME.round_id, 3)
PVP.RoundEndNet.on_connected()
tick()
check("rejoin inside blind 3: on_connected and a frame while the run is held apply nothing", #calls, 0)
check("rejoin inside blind 3: and mark nothing", PVP.GAME.round_end_applied, nil)
lobby._holding = nil
tick()
check("rejoin inside blind 3: lastResult 3 ends the round exactly once", #calls, 1)
check("rejoin inside blind 3: as a loss", calls[1], "endPvP")
PVP.RoundEndNet.on_connected()
tick()
check("rejoin inside blind 3: and only once", #calls, 1)

-- The hold makes the order inside CONNECTED harmless: an on_connected before ReadyNet has the
-- round id reads nothing, so the round still ends once after the hold clears.
rejoin_in_blind_3()
PVP.RoundEndNet.on_connected()
check("on_connected before ReadyNet.evaluate, run held: nothing marked", PVP.GAME.round_end_applied, nil)
PVP.ReadyNet.evaluate()
lobby._holding = nil
tick()
check("on_connected before ReadyNet.evaluate, run held: the round still ends once", #calls, 1)

-- 80: a wait on more than one player is the N>2 branch (no opponent).
setup()
states["pvp.lives"] =
	{ runId = "r1", players = {}, pending = { { playerId = "b", blindKey = "2:Big", waitsOn = { "a", "c" } } } }
listeners["pvp.lives"]()
check("80: several waitsOn gives a nil opponent", calls[1], "deathPending b nil 2:Big")

-- Team pending death: the pvp.teams map of the current run puts team_id on the command.
local TEAM_ENTRY = { playerId = "b", blindKey = "2:Big", waitsOn = { "a" } }
setup()
states["pvp.teams"] = { runId = "r1", teams = { a = "RUNNER", b = "HUNTER" } }
states["pvp.lives"] = { runId = "r1", players = {}, pending = { TEAM_ENTRY } }
listeners["pvp.lives"]()
check("team: team_id reaches deathPending", calls[1], "deathPending b a 2:Big team=HUNTER")
setup()
states["pvp.teams"] = { runId = "r0", teams = { a = "RUNNER", b = "HUNTER" } }
states["pvp.lives"] = { runId = "r1", players = {}, pending = { TEAM_ENTRY } }
listeners["pvp.lives"]()
check("team: a pvp.teams value of another run is ignored", calls[1], "deathPending b a 2:Big")
setup()
states["pvp.lives"] = { runId = "r1", players = {}, pending = { TEAM_ENTRY } }
listeners["pvp.lives"]()
check("team: no pvp.teams value, no team_id", calls[1], "deathPending b a 2:Big")
setup()
states["pvp.teams"] = { runId = "r1", teams = { a = "A", b = "A" } }
states["pvp.lives"] = { runId = "r1", players = {}, pending = { TEAM_ENTRY } }
listeners["pvp.lives"]()
states["pvp.lives"] = { runId = "r1", players = {}, pending = {} }
listeners["pvp.lives"]()
check("team: a teammate's entry going ends my pending screen", calls[2], "end_pending_death")

-- The server spent my hands while the round is still open (the backstop): handsSpent runs once.
local function spent_state(roundId, mine)
	return {
		runId = "r1",
		roundId = roundId,
		phase = "playing",
		players = { a = { handsLeft = 0, handsSpent = mine }, b = { handsLeft = 2 } },
	}
end

setup()
states["pvp.round"] = spent_state(1, true)
listeners["pvp.round"]()
check("spent: handsSpent is called once", #calls, 1)
check("spent: it is handsSpent", calls[1], "handsSpent")
check("spent: marked in the saved marks", PVP.GAME.round_end_applied.spent, 1)
listeners["pvp.round"]()
tick()
PVP.RoundEndNet.on_connected()
check("spent: a re-push of the same state is a no-op", #calls, 1)

setup({ round_end_applied = { run_id = "r1", rounds = {}, pending = {}, spent = 1 } })
states["pvp.round"] = spent_state(1, true)
listeners["pvp.round"]()
check("spent: a reload with the mark set does nothing", #calls, 0)

setup()
G.GAME.current_round.hands_left = 0
states["pvp.round"] = spent_state(1, true)
listeners["pvp.round"]()
check("spent: nothing when my hands are already 0", #calls, 0)

setup()
states["pvp.round"] = spent_state(1, nil)
listeners["pvp.round"]()
check("spent: nothing without the flag", #calls, 0)

setup()
gate_open = false
states["pvp.round"] = spent_state(1, true)
listeners["pvp.round"]()
check("spent: nothing while the run is not loaded", #calls, 0)
gate_open = true
tick()
check("spent: applied once the run is loaded", #calls, 1)

setup()
states["pvp.round"] = spent_state(1, true)
states["pvp.round"].lastResult = { roundId = 1, losers = { "a" } }
listeners["pvp.round"]()
check("spent + result in one state: both run", #calls, 2)
check("spent + result: handsSpent first", calls[1], "handsSpent")
check("spent + result: endPvP second", calls[2], "endPvP")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
