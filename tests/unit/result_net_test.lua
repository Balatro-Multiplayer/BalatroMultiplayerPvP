-- Run from the repo root: luajit tests/unit/result_net_test.lua
-- The shell around lib/result_view.lua with stubbed MPAPI, G and handlers: a result
-- applies once per run, only in a loaded run of the current run id, and a forfeit and
-- a vote each send one request.
local requests, applied, states, listeners, saves, lobby, staged, ended, shown_votes

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

local function setup(config, game)
	requests, applied, states, listeners, saves, staged, ended, shown_votes = {}, {}, {}, {}, 0, false, 0, {}
	lobby = { mod_id = "pvp", player_id = "a", _game = { started = { run_id = "r1" } } }
	local function handler(name)
		return function()
			applied[#applied + 1] = name
		end
	end
	PVP = {
		id = "pvp",
		GAME = game or {},
		config = config or {},
		match_log = function() end,
		show_vote_counts = function(tally, run)
			shown_votes[#shown_votes + 1] = { tally = tally, run = run }
		end,
		end_pending_death = function()
			ended = ended + 1
		end,
		HANDLERS = { winGame = handler("winGame"), loseGame = handler("loseGame"), drawGame = handler("drawGame") },
	}
	PVP.RunGate = {
		loaded = function()
			return G.STAGE == G.STAGES.RUN and not staged
		end,
	}
	SMODS = {
		save_mod_config = function()
			saves = saves + 1
		end,
	}
	G = { STAGE = "run", STAGES = { RUN = "run", MAIN_MENU = "menu" }, GAME = { round_resets = {} } }
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
		run_save = {
			is_staged = function()
				return staged
			end,
		},
		request = function(kind, payload, on_result)
			requests[#requests + 1] = { kind = kind, payload = payload, on_result = on_result }
		end,
	}
	dofile("lib/_state_value.lua")
	dofile("lib/result_view.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/result_net.lua")
end

local function tick()
	PVP.ResultNet.update()
end

local WIN = {
	runId = "r1",
	kind = "win",
	winnerId = "a",
	places = { { playerId = "a", place = 1 }, { playerId = "b", place = 2 } },
}
local DRAW = {
	runId = "r1",
	kind = "draw",
	places = { { playerId = "a", place = 1 }, { playerId = "b", place = 1 } },
}

setup()
check("subscribes to the result", type(listeners["pvp.result"]), "function")
check("subscribes to the votes", type(listeners["pvp.votes"]), "function")

-- Two SNAPSHOTs carrying the same result.
states["pvp.result"] = WIN
listeners["pvp.result"]()
check("result_handled set with the profile marker", PVP.GAME.result_handled, true)
PVP.GAME.result_handled = nil
listeners["pvp.result"]()
check("exactly once per run: a repeat of the recorded run does nothing", #applied, 1)
check("win handler", applied[1], "winGame")
check("profile marks the run", PVP.config.recordedRuns[1], "r1")
check("team_pending cleared", PVP.GAME.team_pending, nil)
check("pending death ended", ended, 1)
check("a win saves the config only in record_match, not here", saves, 0)

-- The same result twice without clearing result_handled.
setup()
states["pvp.result"] = WIN
listeners["pvp.result"]()
listeners["pvp.result"]()
tick()
check("result_handled stops a repeat", #applied, 1)

-- A fresh process: the profile still has the run recorded.
local kept = PVP.config
setup(kept)
states["pvp.result"] = WIN
listeners["pvp.result"]()
check("recordedRuns: recorded run does not apply after a restart", #applied, 0)

setup()
states["pvp.result"] = { runId = "r1", kind = "win", winnerId = "b", places = WIN.places }
lobby.player_id = "b"
listeners["pvp.result"]()
check("loser runs loseGame", applied[1], "loseGame")

setup()
states["pvp.result"] = DRAW
listeners["pvp.result"]()
listeners["pvp.result"]()
check("draw applies once", #applied, 1)
check("draw handler", applied[1], "drawGame")
check("a draw saves the config itself", saves, 1)

setup()
states["pvp.result"] = { runId = nil, kind = nil, places = {} }
listeners["pvp.result"]()
check("idle result applies nothing", #applied, 0)

setup()
states["pvp.result"] = WIN
listeners["pvp.result"]()
PVP.GAME.result_handled = nil
states["pvp.result"] = { runId = "r2", kind = "draw", places = DRAW.places }
lobby._game.started.run_id = "r2"
listeners["pvp.result"]()
check("a new run applies again", #applied, 2)

setup()
lobby.mod_id = "other"
states["pvp.result"] = WIN
listeners["pvp.result"]()
check("another mod's lobby applies nothing", #applied, 0)

-- Never outside a run; the result waits for the run.
setup()
G.STAGE = "menu"
states["pvp.result"] = WIN
listeners["pvp.result"]()
tick()
check("not in a run applies nothing", #applied, 0)
check("not in a run leaves it unrecorded", PVP.config.recordedRuns, nil)
G.STAGE = "run"
tick()
check("applies on the first frame in the run", #applied, 1)
tick()
check("and only once", #applied, 1)

-- A rejoin snapshot before the run save is back (lives_net.lua run_loaded).
setup()
staged = true
states["pvp.result"] = WIN
listeners["pvp.result"]()
tick()
check("staged load: applies nothing before the load", #applied, 0)
staged = false
tick()
check("staged load: applies after the load", #applied, 1)

-- GAME_ENDED clears the lobby's started run in the same step as the result: a staged
-- rejoin must still apply it after the load.
setup()
staged = true
states["pvp.result"] = WIN
listeners["pvp.result"]()
lobby._game.started = nil
tick()
check("rejoin: nothing applies while staged", #applied, 0)
staged = false
tick()
check("rejoin: applies once after the load though the lobby run is gone", #applied, 1)
tick()
check("rejoin: and only once", #applied, 1)

-- The latch survives a later read that finds no current run: after GAME_ENDED the same result pushed
-- again, or CONNECTED, reads nil and must not drop what was received.
setup()
staged = true
states["pvp.result"] = WIN
listeners["pvp.result"]()
lobby._game.started = nil
listeners["pvp.result"]()
PVP.ResultNet.on_connected()
tick()
check("a later read with no run: nothing applies while staged", #applied, 0)
staged = false
tick()
check("a later read with no run does not drop the latched result", #applied, 1)
check("a later read with no run: the right handler runs", applied[1], "winGame")
tick()
check("a later read with no run: and only once", #applied, 1)

-- A stale latch: r1 latched off-run, the next loaded frame is in r2 with r1's result still in state.
setup()
G.STAGE = "menu"
states["pvp.result"] = WIN
listeners["pvp.result"]()
lobby._game.started.run_id = "r2"
G.STAGE = "run"
tick()
check("stale latch: r1 result does not end r2", #applied, 0)
check("stale latch: and is not recorded", PVP.config.recordedRuns, nil)

-- A result of another run than the lobby's current one.
setup()
states["pvp.result"] = { runId = "r0", kind = "win", winnerId = "a", places = WIN.places }
listeners["pvp.result"]()
tick()
check("another run's result never applies", #applied, 0)
check("another run's result is not recorded", PVP.config.recordedRuns, nil)

-- A contested match has no result to apply.
setup(nil, { contested = true })
states["pvp.result"] = WIN
listeners["pvp.result"]()
tick()
check("contested does not stack loseGame/record_match", #applied, 0)
check("contested is not marked", PVP.config.recordedRuns, nil)
setup(nil, { won = true })
states["pvp.result"] = WIN
listeners["pvp.result"]()
check("a game already won applies nothing", #applied, 0)
setup(nil, { draw = true })
states["pvp.result"] = DRAW
listeners["pvp.result"]()
check("a game already drawn applies nothing", #applied, 0)

-- Forfeit and vote: one request each.
setup()
PVP.ResultNet.forfeit()
check("forfeit sends one request", #requests, 1)
check("forfeit kind", requests[1].kind, "pvp.forfeit")
check("forfeit carries the run", requests[1].payload.runId, "r1")
PVP.ResultNet.vote({ kind = "draw", yes = true })
check("vote sends one request", #requests, 2)
check("vote kind", requests[2].kind, "pvp.vote")
check(
	"vote payload",
	requests[2].payload.kind .. tostring(requests[2].payload.yes) .. requests[2].payload.runId,
	"drawtruer1"
)
PVP.ResultNet.vote({ runId = "r9", kind = "seed", yes = false })
check("vote keeps a given run", requests[3].payload.runId, "r9")
requests[3].on_result(false, { reason = "no_vote" })
requests[3].on_result(true, {})
check("a refusal draws nothing and does not throw", #requests, 3)

-- Votes state.
setup()
states["pvp.votes"] = { runId = "r1", draw = { "a", "b" }, seed = {} }
listeners["pvp.votes"]()
check("vote tally draw", PVP.GAME.vote_tally.draw, 2)
check("vote tally mine", PVP.GAME.vote_tally.i_draw, true)
check("the vote counts are shown once, with the run", #shown_votes, 1)
check("the shown counts are the tally", shown_votes[1].tally, PVP.GAME.vote_tally)
check("the shown counts name the run", shown_votes[1].run, "r1")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
