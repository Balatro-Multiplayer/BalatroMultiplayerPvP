-- Run from the repo root: luajit tests/unit/ready_view_test.lua
-- lib/ready_view.lua is pure: table rows plus the byte-identical server fixtures
-- in tests/fixtures/net-v1/ (the server's contract examples).
PVP = {}
dofile("lib/_state_value.lua")
dofile("lib/ready_view.lua")
local ReadyView = PVP.ReadyView

local fixture = dofile("tests/unit/net_fixture.lua")

local push = fixture("state_ready_push").changed["pvp.ready"]
local started = fixture("state_round_started").changed["pvp.ready"]
local full = fixture("state_full").changed["pvp.ready"]
local snapshot = fixture("snapshot_v1").match["pvp.ready"]
local idle = fixture("state_idle").changed["pvp.ready"]

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

-- Fixtures decode as the contract says.
check("fixture push: round 2 start", push.lastStart.roundId, 2)
check("fixture push: ready table", push.ready.u1, true)
check("fixture started: null firstReady is nil", started.firstReady, nil)
check("fixture full equals the push of the same round", full.lastStart.roundId, started.lastStart.roundId)
check("fixture snapshot equals the full state", snapshot.lastStart.firstPlayer, full.lastStart.firstPlayer)

-- decide: [name, value, record, current run, expect start round id (nil = none), expect record.started]
-- The caller is "u1", who is in the players of every u1/u2 fixture.
local RUN = "r-abc"
local ME = "u1"
local rows = {
	{ "fresh process: a lastStart that has me in it counts as started", push, nil, RUN, nil, 2 },
	{
		"fresh process: a lastStart without me in it is not mine to have started",
		{ runId = RUN, lastStart = { roundId = 4, firstPlayer = "u2", players = { "u2", "u3" } } },
		nil,
		RUN,
		nil,
		0,
	},
	{ "fresh process from a snapshot does not start", snapshot, nil, RUN, nil, 3 },
	{ "push of a new round starts it", started, { run_id = RUN, started = 2 }, RUN, 3, 3 },
	{ "duplicate push does nothing", started, { run_id = RUN, started = 3 }, RUN, nil, 3 },
	{ "snapshot of an already started round does nothing", snapshot, { run_id = RUN, started = 3 }, RUN, nil, 3 },
	{ "state_full of an already started round does nothing", full, { run_id = RUN, started = 3 }, RUN, nil, 3 },
	{ "missed push starts from the snapshot", snapshot, { run_id = RUN, started = 2 }, RUN, 3, 3 },
	{
		"missed several rounds still starts once, from the latest",
		snapshot,
		{ run_id = RUN, started = 0 },
		RUN,
		3,
		3,
	},
	{ "older lastStart than the record does nothing", push, { run_id = RUN, started = 3 }, RUN, nil, 3 },
	{
		"game restart: new run with a record of the old one starts nothing",
		started,
		{ run_id = "r-old", started = 9 },
		RUN,
		nil,
		3,
	},
	{ "stale state of the previous run is ignored", started, { run_id = "r-new", started = 1 }, "r-new", nil, 1 },
	{
		"state without a lastStart does nothing",
		{ runId = RUN, round = 0, ready = {} },
		{ run_id = RUN, started = 0 },
		RUN,
		nil,
		0,
	},
	{ "state without a run id does nothing", { round = 1 }, { run_id = RUN, started = 1 }, RUN, nil, 1 },
	{ "idle value (no game) starts nothing", idle, { run_id = RUN, started = 3 }, RUN, nil, 3 },
	{ "idle value with no record starts nothing and keeps none", idle, nil, nil, nil, nil },
	{
		"mirror of an ended game: stale run id after the end is ignored",
		started,
		{ run_id = "r-next", started = 0 },
		"r-next",
		nil,
		0,
	},
	{ "mirror of an ended game with no record is ignored", started, nil, "r-next", nil, nil },
}
for _, row in ipairs(rows) do
	local start, record = ReadyView.decide(row[2], row[3], row[4], ME)
	check(row[1] .. " (start)", start and start.round_id, row[5])
	check(row[1] .. " (record)", record and record.started, row[6])
end

check("nil state keeps the record", select(2, ReadyView.decide(nil, { run_id = RUN, started = 4 }, RUN, ME)).started, 4)
check("nil state with no record stays nil", select(2, ReadyView.decide(nil, nil, RUN, ME)), nil)

-- A run restart end to end: the new run's first state is taken as seen, the next one starts.
do
	local function last(round)
		return { roundId = round, players = { ME } }
	end
	local record
	local _
	_, record = ReadyView.decide({ runId = "r1", round = 1, lastStart = last(1) }, record, "r1", ME)
	local start
	start, record = ReadyView.decide({ runId = "r1", round = 2, lastStart = last(2) }, record, "r1", ME)
	check("run one round two starts", start and start.round_id, 2)
	start, record = ReadyView.decide({ runId = "r2", round = 1, lastStart = last(1) }, record, "r2", ME)
	check("new run: its already-there start is not replayed", start, nil)
	start, record = ReadyView.decide({ runId = "r2", round = 2, lastStart = last(2) }, record, "r2", ME)
	check("new run: round two starts once", start and start.round_id, 2)
	start = ReadyView.decide({ runId = "r2", round = 2, lastStart = last(2) }, record, "r2", ME)
	check("new run: and not twice", start, nil)
end

-- Mapping from lastStart.
do
	local start = ReadyView.decide(started, { run_id = RUN, started = 2 }, RUN, ME)
	check("round id is a number", type(start.round_id), "number")
	check("first player", start.first_player, "u1")
	check("a start carries no hands", start.starting_hands, nil)
	local bare = ReadyView.decide({ runId = RUN, lastStart = { roundId = 4 } }, { run_id = RUN, started = 2 }, RUN, ME)
	check("a start with no player list carries none (the caller logs it)", bare.players, nil)
	local listed = ReadyView.decide(
		{ runId = RUN, lastStart = { roundId = 4, firstPlayer = "u1", players = { "u1", "b" } } },
		{ run_id = RUN, started = 2 },
		RUN,
		ME
	)
	check("a start carries the ids that were ready", listed.players[2], "b")

	-- The first player is the server's id (or nil) in every lobby size: no lobby-size rule, no "" sentinel.
	local three = ReadyView.decide(
		{ runId = RUN, lastStart = { roundId = 4, firstPlayer = "c", players = { "u1", "b", "c" } } },
		{ run_id = RUN, started = 3 },
		RUN,
		ME
	)
	check("three players: the first player is kept", three.first_player, "c")
	local nobody = ReadyView.decide(
		{ runId = RUN, lastStart = { roundId = 5, players = { "u1", "b" } } },
		{ run_id = RUN, started = 4 },
		RUN,
		ME
	)
	check("no first player stays nil", nobody.first_player, nil)
end

check("idle value: nothing is ready", ReadyView.i_am_ready(idle, "u1"), false)
check("idle value: runId decodes to absent", idle.runId, nil)
check("idle value: lastStart decodes to absent", idle.lastStart, nil)
check("idle value: no resend", ReadyView.should_resend_ready(idle, "u1", false, true, false), false)
check("nil state: nothing to start", (ReadyView.decide(nil, nil, RUN, ME)), nil)

-- The button follows the state.
check("ready when my id is in ready", ReadyView.i_am_ready(push, "u1"), true)
check("not ready when only the other is", ReadyView.i_am_ready(push, "u2"), false)
check("not ready on an empty ready table", ReadyView.i_am_ready(started, "u1"), false)
check("not ready with no state", ReadyView.i_am_ready(nil, "u1"), false)

-- Request payloads.
do
	local p = ReadyView.ready_payload(push, "r-abc")
	check("ready payload run", p.runId, "r-abc")
	check("ready payload round is state round + 1", p.roundId, 3)
	check("ready payload carries no hand count", p.startingHands, nil)
	check("ready payload on a run the state is not of is not built", ReadyView.ready_payload(push, "r-new"), nil)
	check("ready payload with no state is not built: no round is assumed", ReadyView.ready_payload(nil, "r-new"), nil)
	check("unready payload with no state is not built", ReadyView.unready_payload(nil, "r-new"), nil)
	check(
		"ready payload from a state of this run with no round number is not built",
		ReadyView.ready_payload({ runId = "r-abc", ready = {} }, "r-abc"),
		nil
	)
	check(
		"unready payload from a state of this run with no round number is not built",
		ReadyView.unready_payload({ runId = "r-abc", ready = {} }, "r-abc"),
		nil
	)
	check("ready payload with no lobby run is not built: the state's run is not borrowed", ReadyView.ready_payload(push, nil), nil)
	check("unready payload with no lobby run is not built", ReadyView.unready_payload(push, nil), nil)
	do
		local start, kept = ReadyView.decide(started, { run_id = "r-abc", started = 0 }, nil, "u1")
		check("decide with no lobby run starts nothing", start, nil)
		check("decide with no lobby run keeps the record", kept.started, 0)
	end
	local k = ReadyView.ready_payload(push, "r-abc", "2:Boss")
	check("ready payload carries the blind key unchanged", k.blindKey, "2:Boss")
	check("ready payload with a key keeps the run", k.runId, "r-abc")
	check("ready payload with a key keeps the round", k.roundId, 3)
	check("ready payload with a key carries no hand count", k.startingHands, nil)
	check("ready payload with no key carries none", ReadyView.ready_payload(push, "r-abc").blindKey, nil)
	local u = ReadyView.unready_payload(push, "r-abc")
	check("unready payload has no blind key", u.blindKey, nil)
	check("unready payload run", u.runId, "r-abc")
	check("unready payload round", u.roundId, 3)
	check("unready payload has no hands", u.startingHands, nil)
end

-- Re-send Ready after a snapshot.
check(
	"resend when wanted, on blind select and dropped",
	ReadyView.should_resend_ready(started, "u1", true, true, false),
	true
)
check("no resend when the server still has it", ReadyView.should_resend_ready(push, "u1", true, true, false), false)
check("no resend when not wanted", ReadyView.should_resend_ready(started, "u1", false, true, false), false)
check("no resend when not on blind select", ReadyView.should_resend_ready(started, "u1", true, false, false), false)
check("no resend when eliminated", ReadyView.should_resend_ready(started, "u1", true, true, true), false)
check("no resend with no state", ReadyView.should_resend_ready(nil, "u1", true, true, false), false)

-- starts_here: in the run's player list, not eliminated, in a run.
local PLAYERS = { "u1", "u2" }
check("starts_here: a player starts", ReadyView.starts_here(PLAYERS, "u1", nil, true), true)
check("starts_here: a spectator does not", ReadyView.starts_here(PLAYERS, "u9", nil, true), false)
check("starts_here: an eliminated player does not", ReadyView.starts_here(PLAYERS, "u1", true, true), false)
check("starts_here: outside a run it does not", ReadyView.starts_here(PLAYERS, "u1", nil, false), false)
check("starts_here: nobody in the run", ReadyView.starts_here({}, "u1", nil, true), false)
check("starts_here: an absent player list starts nobody", ReadyView.starts_here(nil, "u1", nil, true), false)

-- restored_round_id: a rejoin wiped PVP.GAME.round_id; the server's lastStart of this run names the round.
check("restored: no round id, a started blind of this run", ReadyView.restored_round_id(nil, started, RUN, ME), 3)
check("restored: a round id is already there", ReadyView.restored_round_id(2, started, RUN, ME), nil)
check("restored: no state", ReadyView.restored_round_id(nil, nil, RUN, ME), nil)
check("restored: a state of another run", ReadyView.restored_round_id(nil, started, "r-other", ME), nil)
check("restored: no current run", ReadyView.restored_round_id(nil, started, nil, ME), nil)
check("restored: I was not in that start", ReadyView.restored_round_id(nil, started, RUN, "u9"), nil)
check("restored: nothing started yet", ReadyView.restored_round_id(nil, { runId = RUN, ready = {} }, RUN, ME), nil)

-- The pvp.ready of the server's Teams 2v2 midgame example: round 1 started, a1 ready for round 2.
do
	local midgame = fixture("state_pvp_midgame").changed["pvp.ready"]
	local start = ReadyView.decide(midgame, { run_id = "r1", started = 0 }, "r1", "a1")
	check(
		"midgame: a fresh record takes round 1 as started",
		select(2, ReadyView.decide(midgame, nil, "r1", "a1")).started,
		1
	)
	check("midgame: round 1 starts", start.round_id, 1)
	check("midgame: the first player is the server's id", start.first_player, "a1")
	check("midgame: a1 is ready", ReadyView.i_am_ready(midgame, "a1"), true)
	check("midgame: a2 is not", ReadyView.i_am_ready(midgame, "a2"), false)
	local p = ReadyView.ready_payload(midgame, "r1")
	check("midgame: the next ready is for run r1", p.runId, "r1")
	check("midgame: the next ready is for round 2", p.roundId, 2)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
