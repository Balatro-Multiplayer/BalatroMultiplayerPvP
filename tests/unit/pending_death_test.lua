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
	check("opponent failed the blind: draw", outcome, PD.Outcome.DRAW)
	check("draw has no winner", winner, nil)
end

do
	local results = {}
	PD.record(results, B, X, false)
	PD.record(results, B, X, true)
	check("a failed blind stays failed", (decide(results)), PD.Outcome.DRAW)
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

if failures > 0 then
	os.exit(1)
end
