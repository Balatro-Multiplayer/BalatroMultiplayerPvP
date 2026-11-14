-- Run from the repo root: luajit tests/unit/timer_view_test.lua
-- lib/timer_view.lua is pure: table rows named by case, then a loop over elapsed time.
-- The deadline tables follow the wire shape (pvp.round.deadline): built here, then read
-- from the server fixtures.
PVP = {}
dofile("lib/timer_view.lua")
local TimerView = PVP.TimerView

local failures = 0
local function check(name, got, want)
	if got == want then
		print("ok   " .. name)
	else
		failures = failures + 1
		print(("FAIL %s: got %s, wanted %s"):format(name, tostring(got), tostring(want)))
	end
end

local function ante(remaining_ms, by, against)
	return { kind = "ante", by = by or "a", against = against or { "b" }, remainingMs = remaining_ms, n = 1 }
end

-- name, deadline, my id, elapsed, threshold, then the wanted running / timed_me / started_by_me / seconds.
local rows = {
	{ "no deadline: nothing runs", nil, "a", 0, 0, false, false, false, nil },
	{ "starter of a server-counted deadline", ante(150000), "a", 0, 0, true, false, true, 150 },
	{ "starter counts down with the time since it arrived", ante(150000), "a", 30, 0, true, false, true, 120 },
	{ "timed player of a server-counted deadline", ante(150000), "b", 10, 0, true, true, false, 140 },
	{ "a third player is not involved", ante(150000), "c", 0, 0, false, false, false, nil },
	{ "a third player is not involved in an own-clock deadline", ante(nil), "c", 0, 0, false, false, false, nil },
	{ "own-clock deadline, starter: the HUD keeps its own clock", ante(nil), "a", 5, 0, true, false, true, nil },
	{ "own-clock deadline, timed: the HUD keeps its own clock", ante(nil), "b", 5, 0, true, true, false, nil },
	{
		"own-clock PvP deadline, timed",
		{ kind = "pvp", by = "a", against = { "b" }, n = 2 },
		"b",
		0,
		0,
		true,
		true,
		false,
		nil,
	},
	{ "remaining never below 0", ante(150000), "b", 400, 0, true, true, false, 0 },
	{ "remaining never below 0 for the starter", ante(1000), "a", 5, 0, true, false, true, 0 },
	{ "a negative elapsed counts as 0", ante(150000), "a", -3, 0, true, false, true, 150 },
	{
		"threshold: timed player above it keeps its own bank and the box looks idle",
		ante(300000),
		"b",
		0,
		180,
		false,
		true,
		false,
		nil,
	},
	{ "threshold: still above it after some time", ante(300000), "b", 100, 180, false, true, false, nil },
	{ "threshold: one second above it is still held back", ante(181000), "b", 0, 180, false, true, false, nil },
	{ "threshold: at it the box runs", ante(300000), "b", 120, 180, true, true, false, 180 },
	{ "threshold: below it the box shows the remaining time", ante(300000), "b", 150, 180, true, true, false, 150 },
	{ "threshold: the starter sees the whole bank, running", ante(300000), "a", 0, 180, true, false, true, 300 },
	{ "threshold: a bank under it is shown as is", ante(100000), "b", 0, 180, true, true, false, 100 },
	{ "threshold: nil counts as none", ante(150000), "b", 0, nil, true, true, false, 150 },
	{ "threshold: an own-clock deadline has nothing to hide", ante(nil), "b", 0, 180, true, true, false, nil },
	{ "Teams: both timed players see it", ante(60000, "a", { "b", "c" }), "c", 10, 0, true, true, false, 50 },
	{ "no id: not involved", ante(150000), nil, 0, 0, false, false, false, nil },
}
for _, row in ipairs(rows) do
	local got = TimerView.read(row[2], row[3], row[4], row[5])
	check(row[1] .. ": running", got.running, row[6])
	check(row[1] .. ": timed_me", got.timed_me, row[7])
	check(row[1] .. ": started_by_me", got.started_by_me, row[8])
	check(row[1] .. ": seconds", got.seconds, row[9])
end

check("server_counted: a number of ms", TimerView.server_counted(ante(1)), true)
check("server_counted: own clock", TimerView.server_counted(ante(nil)), false)
check("server_counted: no deadline", TimerView.server_counted(nil), false)
check("remaining: an own-clock deadline has none", TimerView.remaining(ante(nil), 3), nil)

-- A deadline with no remainingMs is a personal-clock marker: no run-out and no time of its own, the clocks are
-- the server's. TimerView has no run-out rule any more.
check("run_out: the server makes every run-out, the view has no rule for it", TimerView.run_out, nil)

-- The timer box (TimerView.box): name, clocks, in the PvP blind, personal clock, deadline seconds, bank
-- seconds, then the wanted kind, seconds and running.
local bank = { ante = "bank", pvp = nil, personal = nil }
local bank_pvp = { ante = "bank", pvp = { baseMs = 60000, handMs = 15000 }, personal = nil }
local pressure = { ante = "personal", pvp = nil, personal = { kind = "pressure", baseMs = 300000 } }
local speedlatro = { ante = "personal", pvp = nil, personal = { kind = "speedlatro", baseMs = 300000 } }
local none = { ante = "none", pvp = nil, personal = nil }
local known = { known = true, ms = 90500, running = true, rate = 1, spent = 0 }
local boxes = {
	{ "rules unknown: draws --", nil, false, known, 12, 150, "unknown", nil, nil },
	{ "bank, nothing known yet: draws --", bank, false, { known = false }, nil, nil, "unknown", nil, nil },
	{ "bank, only the bank: shown standing", bank, false, { known = false }, nil, 150, "seconds", 150, false },
	{ "bank, a deadline counts: shown running", bank, false, { known = false }, 140, 150, "seconds", 140, true },
	{ "bank in the PvP blind with no hand timer: the deadline's time is not the PvP clock", bank, true, { known = false }, 9, 150, "seconds", 9, true },
	{ "PvP hand timer in the PvP blind: the deadline's time", bank_pvp, true, { known = false }, 12, 150, "seconds", 12, true },
	{ "PvP hand timer in the PvP blind, no deadline: draws --", bank_pvp, true, { known = false }, nil, 150, "unknown", nil, nil },
	{ "PvP hand timer outside the PvP blind: the bank", bank_pvp, false, { known = false }, nil, 150, "seconds", 150, false },
	{ "personal clock: the server's clock", pressure, false, known, nil, nil, "seconds", 90.5, true },
	{ "personal clock in the PvP blind with no hand timer: still the personal clock", pressure, true, known, nil, nil, "seconds", 90.5, true },
	{ "personal clock paused by the server: the box does not count", pressure, false, { known = true, ms = 90500, running = false, rate = 1, spent = 0 }, nil, nil, "seconds", 90.5, false },
	{ "personal clock not read yet: draws --", pressure, false, { known = false }, nil, nil, "unknown", nil, nil },
	{ "Speedlatro: the arrows", speedlatro, false, known, nil, nil, "speedlatro", nil, nil },
	{ "no ante clock, no deadline, no bank: draws --", none, false, { known = false }, nil, nil, "unknown", nil, nil },
	{ "PvP blind: the running deadline wins over pvpLeftMs", bank_pvp, true, { known = false }, 12, 150, "seconds", 12, true, 45 },
	{ "PvP blind, no deadline: the server's pvpLeftMs, not running", bank_pvp, true, { known = false }, nil, 150, "seconds", 45, false, 45 },
	{ "PvP blind, no deadline, pvpLeftMs 0: zero is a value", bank_pvp, true, { known = false }, nil, 150, "seconds", 0, false, 0 },
	{ "PvP blind, pvpLeftMs unknown (nil): draws --", bank_pvp, true, { known = false }, nil, 150, "unknown", nil, nil, nil },
	{ "PvP blind, pvpLeftMs not a number: draws --", bank_pvp, true, { known = false }, nil, 150, "unknown", nil, nil, "45" },
	{ "outside the PvP blind: pvpLeftMs is not the box", bank_pvp, false, { known = false }, nil, 150, "seconds", 150, false, 45 },
}
for _, row in ipairs(boxes) do
	local got = TimerView.box(row[2], row[3], row[4], row[5], row[6], row[10])
	check("box: " .. row[1] .. ": kind", got.kind, row[7])
	check("box: " .. row[1] .. ": seconds", got.seconds, row[8])
	check("box: " .. row[1] .. ": running", got.running, row[9])
end

-- pvp_left_seconds: my pvpLeftMs from the "pvp.round" value, in seconds, nil while the server has not given it.
local round = { runId = "r1", players = { a = { pvpLeftMs = 45500 }, b = { pvpLeftMs = nil }, c = { pvpLeftMs = "9" } } }
check("pvp_left_seconds: my allowance in seconds", TimerView.pvp_left_seconds(round, "r1", "a"), 45.5)
check("pvp_left_seconds: null/absent is unknown", TimerView.pvp_left_seconds(round, "r1", "b"), nil)
check("pvp_left_seconds: a non-number is unknown", TimerView.pvp_left_seconds(round, "r1", "c"), nil)
check("pvp_left_seconds: no entry for me is unknown", TimerView.pvp_left_seconds(round, "r1", "z"), nil)
check("pvp_left_seconds: another run is unknown", TimerView.pvp_left_seconds(round, "r2", "a"), nil)
check("pvp_left_seconds: no value is unknown", TimerView.pvp_left_seconds(nil, "r1", "a"), nil)

-- Only the PvP allowance box carries pvp_allowance.
check("box: the PvP allowance box is flagged", TimerView.box(bank_pvp, true, { known = false }, nil, 150, 400).pvp_allowance, true)
check("box: the ante bank box is not flagged", TimerView.box(bank_pvp, false, { known = false }, nil, 150, 400).pvp_allowance, nil)

-- Seconds are never negative and never grow as the time since arrival grows, for every
-- player and threshold.
local ok = true
for _, who in ipairs({ "a", "b", "c" }) do
	for _, threshold in ipairs({ 0, 60, 180 }) do
		for _, ms in ipairs({ 0, 1, 999, 60000, 150000, 400000 }) do
			local previous
			for elapsed = 0, 500, 7 do
				local seconds = TimerView.read(ante(ms), who, elapsed, threshold).seconds
				if seconds ~= nil then
					ok = ok and seconds >= 0 and (previous == nil or seconds <= previous)
					previous = seconds
				end
			end
		end
	end
end
check("property: seconds never negative and never grow with elapsed time", ok, true)

-- The view hands back a fresh table each time: a caller may write into it.
local first = TimerView.read(nil, "a", 0, 0)
first.running = true
check("not-involved answers are not shared", TimerView.read(nil, "a", 0, 0).running, false)

-- A paused deadline: a timed player is disconnected, the server holds the time and `remainingMs` is
-- the frozen time left. Literal wire shape; the server's own example is read at the end.
local function paused(remaining_ms, by, against)
	local d = ante(remaining_ms, by, against)
	d.paused = true
	return d
end

-- name, deadline, my id, elapsed, then the wanted paused / running / seconds.
local paused_rows = {
	{ "paused: the timed player sees the frozen time", paused(75000), "b", 0, true, true, 75 },
	{ "paused: whatever time passes, the time stays", paused(75000), "b", 40, true, true, 75 },
	{ "paused: the starter sees it frozen too", paused(75000), "a", 500, true, true, 75 },
	{ "paused: it never goes below 0", paused(0), "b", 9, true, true, 0 },
	{ "paused: a third player is not involved", paused(75000), "c", 0, false, false, nil },
	{ "paused: an own-clock deadline has no server time to hold", paused(nil), "b", 5, false, true, nil },
	{ "not paused: the same deadline counts down", ante(75000), "b", 40, false, true, 35 },
}
for _, row in ipairs(paused_rows) do
	local got = TimerView.read(row[2], row[3], row[4], 0)
	check(row[1] .. ": paused", got.paused, row[5])
	check(row[1] .. ": running", got.running, row[6])
	check(row[1] .. ": seconds", got.seconds, row[7])
end
check(
	"paused: a deadline with paused = false counts down",
	TimerView.remaining({ remainingMs = 60000, paused = false }, 10),
	50
)
check("paused: remaining is frozen", TimerView.remaining(paused(75000), 40), 75)
check("paused: an own-clock deadline is not paused", TimerView.paused(paused(nil)), false)
check("paused: no deadline is not paused", TimerView.paused(nil), false)
check(
	"paused: the display threshold still holds back a frozen time above it",
	TimerView.read(paused(300000), "b", 0, 180).seconds,
	nil
)

-- Same-n pushes carry the time frozen at the n's start: the countdown keeps its time, except that a
-- pause freezes it and the push after the pause resumes it from where it stood.
local running_kept = ante(90000)
local pushed, restart = TimerView.keep_time(running_kept, ante(150000))
check("keep_time: a push of the same n keeps the time", pushed.remainingMs, 90000)
check("keep_time: and the arrival", restart, false)
pushed, restart = TimerView.keep_time(running_kept, paused(61000))
check("keep_time: a pause takes the frozen time", pushed.remainingMs, 61000)
check("keep_time: and is paused", pushed.paused, true)
check("keep_time: and restarts the arrival", restart, true)
pushed, restart = TimerView.keep_time(paused(61000), ante(150000))
check("keep_time: the push after a pause resumes from the frozen time", pushed.remainingMs, 61000)
check("keep_time: and is no longer paused", TimerView.paused(pushed), false)
check("keep_time: and restarts the arrival", restart, true)
pushed = TimerView.keep_time(running_kept, ante(150000, "x", { "y" }))
check("keep_time: who is timed is refreshed", pushed.by, "x")
check("keep_time: the pushed table is not written into", running_kept.by, "a")
pushed = TimerView.keep_time(ante(nil), ante(nil, "x", { "y" }))
check("keep_time: an own-clock deadline stays one", TimerView.server_counted(pushed), false)

-- The server's own contract examples (tests/fixtures/net-v1/) read as the rows above.
local fixture = dofile("tests/unit/net_fixture.lua")
local state_ante = fixture("state_deadline_ante").changed["pvp.round"].deadline
local state_pvp = fixture("state_deadline_pvp").changed["pvp.round"].deadline
local snapshot = fixture("snapshot_deadline").match["pvp.round"].deadline
check("fixture ante: counted by the server", TimerView.server_counted(state_ante), true)
check("fixture ante: the timed player sees 30 s", TimerView.read(state_ante, "b", 0, 0).seconds, 30)
check("fixture ante: the starter sees it as theirs", TimerView.read(state_ante, "a", 0, 0).started_by_me, true)
check("fixture pvp: counted by the server", TimerView.server_counted(state_pvp), true)
check("fixture pvp: the timed player sees 60 s", TimerView.read(state_pvp, "b", 0, 0).seconds, 60)
check("fixture pvp: the timed player is timed", TimerView.read(state_pvp, "b", 0, 0).timed_me, true)
check("fixture snapshot: a rejoining player sees the live 20 s", TimerView.read(snapshot, "b", 0, 0).seconds, 20)
local state_paused = fixture("state_deadline_paused").changed["pvp.round"].deadline
check("fixture paused: the timed player sees it paused", TimerView.read(state_paused, "b", 0, 0).paused, true)
check("fixture paused: 20 s stay 20 s", TimerView.read(state_paused, "b", 30, 0).seconds, 20)
check("fixture paused: the starter sees it frozen too", TimerView.read(state_paused, "a", 30, 0).seconds, 20)

-- The midgame example (Teams 2v2, round 1 resolved): the null deadline of pvp.round runs nothing.
local midgame_deadline = fixture("state_pvp_midgame").changed["pvp.round"].deadline
check("fixture midgame: a null deadline is nil", midgame_deadline, nil)
check("fixture midgame: not server counted", TimerView.server_counted(midgame_deadline), false)
check("fixture midgame: no timer runs for a1", TimerView.read(midgame_deadline, "a1", 0, 0).running, false)

-- can_time: the timer button reads players[me].canTime, the server's own wouldTime.
do
	local function round(players, run)
		return { runId = run or "r1", roundId = 3, phase = "playing", players = players }
	end
	local both = { a = { canTime = true }, b = { canTime = false } }
	check("canTime true for me: the button is on", TimerView.can_time(round(both), "r1", "a"), true)
	check("canTime false for me: the button is off", TimerView.can_time(round(both), "r1", "b"), false)
	check("no entry for me: off", TimerView.can_time(round(both), "r1", "c"), false)
	check("another run's state: off", TimerView.can_time(round(both, "r0"), "r1", "a"), false)
	check("no state: off", TimerView.can_time(nil, "r1", "a"), false)
	check("no run: off", TimerView.can_time(round(both), nil, "a"), false)
	check(
		"a canTime that is not the boolean true: off",
		TimerView.can_time(round({ a = { canTime = "yes" } }), "r1", "a"),
		false
	)
	-- A masked viewer's projection carries no canTime key at all: no button, not a guess from the score.
	check(
		"masked entry (no canTime key): off",
		TimerView.can_time(
			round({ a = { handsLeft = 3, score = nil, timerLosses = 0, handsSpent = false } }),
			"r1",
			"a"
		),
		false
	)
	-- The decision is the server's alone: the local score or first-player facts are not inputs.
	check(
		"canTime true stays true whatever else the entry says",
		TimerView.can_time(round({ a = { canTime = true, score = "0", handsLeft = 0 } }), "r1", "a"),
		true
	)
end

-- The masked example (Teams 2v2, round 1, nobody has played a hand): no entry carries canTime.
do
	local masked = fixture("state_pvp_masked").changed["pvp.round"]
	for _, id in ipairs({ "a1", "a2", "b1", "b2" }) do
		check("fixture masked: no canTime for " .. id, masked.players[id].canTime, nil)
		check("fixture masked: button off for " .. id, TimerView.can_time(masked, "r1", id), false)
	end
end

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
