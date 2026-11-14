-- Run from the repo root: luajit tests/unit/result_view_test.lua
-- The pure rules of lib/result_view.lua.
PVP = {}
dofile("lib/_state_value.lua")
dofile("lib/result_view.lua")
local ResultView = PVP.ResultView

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

local IDLE = { runId = nil, kind = nil, winnerId = nil, winnerTeam = nil, places = {} }
local WIN = {
	runId = "r1",
	kind = "win",
	winnerId = "a",
	winnerTeam = nil,
	places = { { playerId = "b", place = 2 }, { playerId = "a", place = 1 } },
}
local DRAW = {
	runId = "r1",
	kind = "draw",
	winnerId = nil,
	places = { { playerId = "a", place = 1 }, { playerId = "b", place = 1 } },
}

check("idle value shows nothing", ResultView.outcome(IDLE, "a"), nil)
check("nil value shows nothing", ResultView.outcome(nil, "a"), nil)
check("winner sees win", ResultView.outcome(WIN, "a").outcome, "win")
check("loser sees loss", ResultView.outcome(WIN, "b").outcome, "loss")
check("loser's place", ResultView.outcome(WIN, "b").place, 2)
check("spectator sees nothing", ResultView.outcome(WIN, "z"), nil)
check("draw view: a", ResultView.outcome(DRAW, "a").outcome, "draw")
check("draw view: b", ResultView.outcome(DRAW, "b").outcome, "draw")
check("draw view: both place 1", ResultView.outcome(DRAW, "b").place, 1)
local team_win = {
	runId = "r2",
	kind = "win",
	winnerTeam = "A",
	places = { { playerId = "a", place = 1 }, { playerId = "c", place = 1 }, { playerId = "b", place = 2 } },
}
check("team mate of the winner wins", ResultView.outcome(team_win, "c").outcome, "win")

-- A tie for first is a draw only for the tied; the rest lose.
local ROYALE_DRAW = {
	runId = "r3",
	kind = "draw",
	places = { { playerId = "a", place = 1 }, { playerId = "b", place = 1 }, { playerId = "c", place = 3 } },
}
check("draw of 3: first tied a draws", ResultView.outcome(ROYALE_DRAW, "a").outcome, "draw")
check("draw of 3: first tied b draws", ResultView.outcome(ROYALE_DRAW, "b").outcome, "draw")
check("draw of 3: third place loses", ResultView.outcome(ROYALE_DRAW, "c").outcome, "loss")

check("pending: new result", ResultView.pending_outcome(WIN, "a", {}, "r1").outcome, "win")
check("pending: no record list", ResultView.pending_outcome(WIN, "a", nil, "r1").outcome, "win")
check("pending: already recorded run", ResultView.pending_outcome(WIN, "a", { "r1" }, "r1"), nil)
check("pending: another run recorded", ResultView.pending_outcome(WIN, "a", { "r0" }, "r1").run_id, "r1")
check("pending: result of another run than the current", ResultView.pending_outcome(WIN, "a", {}, "r2"), nil)
check("pending: no current run", ResultView.pending_outcome(WIN, "a", {}, nil), nil)
check(
	"pending: numeric run id is a string",
	ResultView.pending_outcome({ runId = 7, kind = "draw", places = DRAW.places }, "a", {}, "7").run_id,
	"7"
)

check(
	"pending: carries the list to save",
	table.concat(ResultView.pending_outcome(WIN, "a", { "r0" }, "r1").recorded, ","),
	"r0,r1"
)

-- record_once: the one decision both the result and "you are out" ask before showing the end of a run.
check("record_once: a new run is added last", table.concat(ResultView.record_once({ "r0" }, "r1"), ","), "r0,r1")
check("record_once: no list yet", table.concat(ResultView.record_once(nil, "r1"), ","), "r1")
check("record_once: a run already recorded is nil", ResultView.record_once({ "r0", "r1" }, "r1"), nil)
local full_list = {}
for i = 1, ResultView.RECORDED_CAP do
	full_list[i] = "x" .. i
end
check(
	"record_once: keeps only the newest RECORDED_CAP",
	#ResultView.record_once(full_list, "r1"),
	ResultView.RECORDED_CAP
)

-- to_apply: the pending outcome unless the latch is stale or the game already has its end.
local function apply_input(over)
	local input = {
		result_value = WIN,
		my_id = "a",
		recorded = {},
		latched_run = "r1",
		current_run_id = "r1",
		game = {},
	}
	for name, value in pairs(over or {}) do
		input[name] = value
	end
	return input
end
check("to_apply: the result of the current run", ResultView.to_apply(apply_input()).outcome, "win")
check("to_apply: it carries the list to save", ResultView.to_apply(apply_input()).recorded[1], "r1")
local rejoin = apply_input()
rejoin.current_run_id = nil
check("to_apply: a rejoin (no current run) uses the latched run", ResultView.to_apply(rejoin).outcome, "win")
check(
	"to_apply: a latch from an earlier run is stale",
	ResultView.to_apply(apply_input({ current_run_id = "r2" })),
	nil
)
local unlatched = apply_input()
unlatched.latched_run = nil
check("to_apply: nothing latched while a run is current", ResultView.to_apply(unlatched), nil)
check(
	"to_apply: already handled in this run",
	ResultView.to_apply(apply_input({ game = { result_handled = true } })),
	nil
)
check(
	"to_apply: a contested match is a moderator's",
	ResultView.to_apply(apply_input({ game = { contested = true } })),
	nil
)
check("to_apply: already won", ResultView.to_apply(apply_input({ game = { won = true } })), nil)
check("to_apply: already drawn", ResultView.to_apply(apply_input({ game = { draw = true } })), nil)
check("to_apply: a run already recorded", ResultView.to_apply(apply_input({ recorded = { "r1" } })), nil)
check("to_apply: not in the match", ResultView.to_apply(apply_input({ my_id = "z" })), nil)

check("result_run: the current run's result", ResultView.result_run(WIN, "r1"), "r1")
check("result_run: another run", ResultView.result_run(WIN, "r2"), nil)
check("result_run: no current run", ResultView.result_run(WIN, nil), nil)
check("result_run: idle", ResultView.result_run(IDLE, "r1"), nil)

check("recorded: in list", ResultView.is_recorded({ "a", "b" }, "b"), true)
check("recorded: not in list", ResultView.is_recorded({ "a" }, "b"), false)
check("recorded: nil list", ResultView.is_recorded(nil, "b"), false)
check("remember: appended last", ResultView.remember({ "a" }, "b")[2], "b")
check("remember: no duplicate", #ResultView.remember({ "a", "b" }, "a"), 2)
local many = {}
for i = 1, 60 do
	many = ResultView.remember(many, "r" .. i)
end
check("remember: capped at 50", #many, 50)
check("remember: oldest pruned", ResultView.is_recorded(many, "r10"), false)
check("remember: newest kept", ResultView.is_recorded(many, "r60"), true)
check("remember: boundary kept", ResultView.is_recorded(many, "r11"), true)

local VOTES = { runId = "r1", draw = { "a" }, seed = { "a", "b" } }
local tally = ResultView.tally(VOTES, "b", "r1")
check("tally draw count", tally.draw, 1)
check("tally seed count", tally.seed, 2)
check("tally i_draw", tally.i_draw, false)
check("tally i_seed", tally.i_seed, true)
check("tally stale run counts none", ResultView.tally(VOTES, "a", "r2").seed, 0)
check("tally idle", ResultView.tally({ runId = nil, draw = {}, seed = {} }, "a", "r1").draw, 0)
check("tally nil", ResultView.tally(nil, "a", "r1").i_draw, false)
check("tally unknown current run accepts the votes' run", ResultView.tally(VOTES, "a", nil).draw, 1)

local payload = ResultView.vote_payload("r1", "draw", true)
check("vote payload run", payload.runId, "r1")
check("vote payload kind", payload.kind, "draw")
check("vote payload yes", payload.yes, true)
check("vote payload yes is boolean", ResultView.vote_payload("r1", "seed", nil).yes, false)
check("forfeit payload", ResultView.forfeit_payload(5).runId, "5")

-- The server's Teams 2v2 examples: the idle pvp.result and the open draw vote of midgame, then the
-- final result (team B wins, places for four seats).
do
	local midgame = dofile("tests/unit/net_fixture.lua")("state_pvp_midgame").changed
	local final = dofile("tests/unit/net_fixture.lua")("state_pvp_result").changed["pvp.result"]
	check("midgame: the idle result shows nothing", ResultView.outcome(midgame["pvp.result"], "a1"), nil)
	check("midgame: the idle result is of no run", ResultView.result_run(midgame["pvp.result"], "r1"), nil)
	local tally = ResultView.tally(midgame["pvp.votes"], "b1", "r1")
	check("midgame votes: one draw vote", tally.draw, 1)
	check("midgame votes: no seed vote", tally.seed, 0)
	check("midgame votes: b1 voted", tally.i_draw, true)
	check("midgame votes: a1 did not", ResultView.tally(midgame["pvp.votes"], "a1", "r1").i_draw, false)

	check("result: win", final.kind, "win")
	check("result: team B won", final.winnerTeam, "B")
	check("result: no single winner", final.winnerId, nil)
	check("result: of run r1", ResultView.result_run(final, "r1"), "r1")
	for id, want in pairs({ a1 = { "loss", 2 }, a2 = { "loss", 2 }, b1 = { "win", 1 }, b2 = { "win", 1 } }) do
		local shown = ResultView.outcome(final, id)
		check("result: " .. id .. " outcome", shown.outcome, want[1])
		check("result: " .. id .. " place", shown.place, want[2])
		check("result: " .. id .. " run", shown.run_id, "r1")
	end
	check("result: a spectator sees nothing", ResultView.outcome(final, "z"), nil)
	check("result: b1 applies it once", ResultView.pending_outcome(final, "b1", {}, "r1").outcome, "win")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
