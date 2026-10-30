-- Plain Lua test for lib/pending_death.lua (pure decision logic, no game needed).
-- Run from the repo root: lua5.4 tests/unit/pending_death_test.lua
PVP = {}
dofile("lib/pending_death.lua")
local PD = PVP.PendingDeath

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local A, B = "player_a", "player_b"
local X = PD.blind_key(3, "Boss")
local pending = { player_id = A, blind_key = X }
local here = { present = true, lives = 2 }

local function decide(results, opponent)
	local outcome, winner = PD.decide(pending, B, results, opponent or here)
	return outcome, winner
end

do
	local outcome = decide({})
	check("opponent has not reached the blind: still pending", outcome, PD.Outcome.PENDING)
end

do
	local results = {}
	PD.record(results, B, X, true)
	local outcome, winner = decide(results)
	check("opponent beat the blind: win", outcome, PD.Outcome.WIN)
	check("opponent beat the blind: winner is the opponent", winner, B)
end

do
	local results = {}
	PD.record(results, B, X, false)
	local outcome, winner = decide(results)
	check("opponent failed the blind and kept a life: win", outcome, PD.Outcome.WIN)
	check("opponent failed the blind and kept a life: winner is the opponent", winner, B)
	local drawn, none = decide(results, { present = true, lives = 0 })
	check("opponent lost their last life to it too: draw", drawn, PD.Outcome.DRAW)
	check("draw has no winner", none, nil)
end

do
	local results = {}
	PD.record(results, B, X, false)
	PD.record(results, B, X, true)
	check("a failed blind stays failed", results[B][X], PD.BlindResult.FAILED)
end

do
	local results = {}
	PD.record(results, B, X, false)
	local outcome, winner = decide(results, { present = false, lives = 2 })
	check("opponent failed the blind then left: the dead player wins", outcome, PD.Outcome.WIN)
	check("opponent failed the blind then left: winner is the dead player", winner, A)
end

do
	local results = {}
	PD.record(results, B, PD.blind_key(3, "Big"), true)
	check("a different blind does not count", (decide(results)), PD.Outcome.PENDING)
end

do
	local outcome, winner = decide({}, { present = false, lives = 2 })
	check("opponent left before the blind: win", outcome, PD.Outcome.WIN)
	check("opponent left: the dead player wins", winner, A)
end

do
	local results = {}
	PD.record(results, B, X, true)
	local outcome, winner = decide(results, { present = false, lives = 2 })
	check("opponent beat the blind then left: still the opponent wins", outcome, PD.Outcome.WIN)
	check("opponent beat the blind then left: winner", winner, B)
end

do
	local outcome = decide({}, { present = true, lives = 0 })
	check("opponent died elsewhere: draw", outcome, PD.Outcome.DRAW)
end

do
	check("blind key separates ante and blind", PD.blind_key(1, "Small") ~= PD.blind_key(2, "Small"), true)
end

-- Matches of 3 or more players.
local C = "player_c"
local here3 = { present = true, lives = 2 }
local gone = { present = false, lives = 2 }
local out = { present = true, lives = 0 }

do
	local pd = { { player_id = A, blind_key = X } }
	check("3p: nobody has a result: unresolved", PD.many_resolved(pd, {}, { [A] = out, [B] = here3, [C] = here3 }), false)

	local results = {}
	PD.record(results, B, X, true)
	check("3p: one survivor still open: unresolved", PD.many_resolved(pd, results, { [A] = out, [B] = here3, [C] = here3 }), false)

	PD.record(results, C, X, false)
	check("3p: both reported: resolved", PD.many_resolved(pd, results, { [A] = out, [B] = here3, [C] = here3 }), true)

	check("3p: one reported, one eliminated: resolved", PD.many_resolved(pd, results, { [A] = out, [B] = here3, [C] = out }), true)

	local half = {}
	PD.record(half, B, X, true)
	check("3p: one reported, one left: resolved", PD.many_resolved(pd, half, { [A] = out, [B] = here3, [C] = gone }), true)
end

do
	-- A died on X. B beat X and won. C failed X.
	local pd = { { player_id = A, blind_key = X, out_before = {} } }
	local results = {}
	PD.record(results, B, X, true)
	PD.record(results, C, X, false)
	local places = PD.places({ A, B, C }, pd, results, { [A] = out, [B] = here3, [C] = out })
	check("3p: beater wins", places[B], 1)
	check("3p: failer ties with the dead player", places[C], places[A])
	check("3p: dead player is below the winner", places[A], 2)
end

do
	-- A died on X. C beat X then B (alive) beat X. C was eliminated by B later.
	local pd = { { player_id = A, blind_key = X, out_before = {} } }
	local results = {}
	PD.record(results, B, X, true)
	PD.record(results, C, X, true)
	local places = PD.places({ A, B, C }, pd, results, { [A] = out, [B] = here3, [C] = out })
	check("3p: both beat: winner first", places[B], 1)
	check("3p: both beat: eliminated beater second", places[C], 2)
	check("3p: both beat: dead player last", places[A], 3)
end

do
	-- The last survivor fails X: ties with the dead player, the other beater is above.
	local pd = { { player_id = A, blind_key = X, out_before = {} } }
	local results = {}
	PD.record(results, C, X, true)
	PD.record(results, B, X, false)
	local places = PD.places({ A, B, C }, pd, results, { [A] = out, [B] = here3, [C] = out })
	check("3p: beater above a failing survivor", places[C], 1)
	check("3p: failing survivor ties with the dead", places[B], 2)
	check("3p: dead tied", places[A], 2)
end

do
	-- C was eliminated before A died: C ranks below A.
	local pd = { { player_id = A, blind_key = X, out_before = { [C] = true } } }
	local results = {}
	PD.record(results, B, X, true)
	local places = PD.places({ A, B, C }, pd, results, { [A] = out, [B] = here3, [C] = out })
	check("3p: earlier elimination ranks below the dead", places[C] > places[A], true)
	check("3p: winner first", places[B], 1)
end

do
	-- Two deaths on different blinds. A died on X, then C died on Y. B beat both.
	local Y = PD.blind_key(4, "Small")
	local pd = {
		{ player_id = A, blind_key = X, out_before = {} },
		{ player_id = C, blind_key = Y, out_before = { [A] = true } },
	}
	local results = {}
	PD.record(results, B, X, true)
	PD.record(results, B, Y, true)
	PD.record(results, C, X, false)
	local places = PD.places({ A, B, C }, pd, results, { [A] = out, [B] = here3, [C] = out })
	check("two deaths: survivor wins", places[B], 1)
	check("two deaths: the later death ranks above the earlier", places[C] < places[A], true)
end

do
	check("many_resolved with no pending deaths", PD.many_resolved({}, {}, {}), true)
	local list = PD.add_pending({}, A, X, { [C] = true })
	check("add_pending adds once", #list, 1)
	PD.add_pending(list, A, X, {})
	check("add_pending ignores a repeat", #list, 1)
	check("find_pending", PD.find_pending(list, A).blind_key, X)
end

-- Manhunt and Teams: a whole side is pending. decide_team reads the other side's players.
do
	local H1, H2 = "hunter_1", "hunter_2"
	local live = { present = true, lives = 1 }
	local function team(results, roster)
		return PD.decide_team(X, results, roster)
	end

	check("team: no hunter has a result: pending", (team({}, { [H1] = live, [H2] = live })), PD.Outcome.PENDING)

	local beaten = {}
	PD.record(beaten, H2, X, true)
	check("team: one beats X, the other still plays: win", (team(beaten, { [H1] = live, [H2] = live })), PD.Outcome.WIN)

	local failed = {}
	PD.record(failed, H1, X, false)
	check("team: one failed, one still plays: pending", (team(failed, { [H1] = live, [H2] = live })), PD.Outcome.PENDING)

	local half_failed = {}
	PD.record(half_failed, H1, X, false)
	PD.record(failed, H2, X, false)
	check("team: every player failed: draw", (team(failed, { [H1] = live, [H2] = live })), PD.Outcome.DRAW)

	check(
		"team: one failed, one eliminated: draw",
		(team(half_failed, { [H1] = live, [H2] = { present = true, lives = 0 } })),
		PD.Outcome.DRAW
	)

	local one_failed = {}
	PD.record(one_failed, H1, X, false)
	check(
		"team: one failed, one left: draw",
		(team(one_failed, { [H1] = live, [H2] = { present = false, lives = 1 } })),
		PD.Outcome.DRAW
	)

	check("team: everyone left: draw", (team({}, { [H1] = { present = false, lives = 1 } })), PD.Outcome.DRAW)

	local late = {}
	PD.record(late, H1, X, true)
	check("team: a player beat X then left: win", (team(late, { [H1] = { present = false, lives = 1 } })), PD.Outcome.WIN)

	check("team: no one on the other side: draw", (team({}, {})), PD.Outcome.DRAW)

	local other = {}
	PD.record(other, H1, PD.blind_key(3, "Big"), true)
	check("team: a different blind does not count", (team(other, { [H1] = live })), PD.Outcome.PENDING)

	local _, winner = team(beaten, { [H2] = live })
	check("team: a win has no single winner id", winner, nil)
end

if failures > 0 then
	os.exit(1)
end
