-- Run from the repo root: luajit tests/unit/round_facts_test.lua
-- lib/round_facts.lua is pure: whether a hand counts, and the PvP-timer run-outs still to take a hand off.
-- Rows are named by rule (contract section 3).
PVP = {}
dofile("lib/pending_death.lua")
dofile("lib/_state_value.lua")
dofile("lib/round_facts.lua")
local RoundFacts = PVP.RoundFacts

local failures = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

test("a hand counts only in the round this client started, while the server has it open", function()
	local open = { runId = "r1", roundId = 3, phase = "playing" }
	equal(RoundFacts.hand_counts(open, "r1", 3), true)
	equal(RoundFacts.hand_counts(open, "r1", "3"), true)
	-- A normal blind before the first PvP round: no round id yet.
	equal(RoundFacts.hand_counts({ runId = "r1", roundId = 0, phase = "shop" }, "r1", nil), false)
	-- A normal blind after a round: the id is the resolved round's.
	equal(RoundFacts.hand_counts({ runId = "r1", roundId = 3, phase = "resolved" }, "r1", 3), false)
	-- The server has moved on to another round, or to another run.
	equal(RoundFacts.hand_counts({ runId = "r1", roundId = 4, phase = "playing" }, "r1", 3), false)
	equal(RoundFacts.hand_counts(open, "r2", 3), false)
	equal(RoundFacts.hand_counts(nil, "r1", 3), false)
	equal(RoundFacts.hand_counts(open, nil, 3), false)
end)

test("pvp.round of the server's midgame example: round 1 of r1 is resolved, no hand counts", function()
	local round = dofile("tests/unit/net_fixture.lua")("state_pvp_midgame").changed["pvp.round"]
	equal(RoundFacts.hand_counts(round, "r1", 1), false)
	-- The same round while it is open: it counts for round 1 of r1 only.
	local open = { runId = round.runId, roundId = round.roundId, phase = "playing" }
	equal(RoundFacts.hand_counts(open, "r1", 1), true)
	equal(RoundFacts.hand_counts(open, "r1", 2), false)
	equal(RoundFacts.hand_counts(open, "r2", 1), false)
end)

test("pvp.round of the server's masked example: round 1 is open, scores unknown, no run-outs", function()
	local round = dofile("tests/unit/net_fixture.lua")("state_pvp_masked").changed["pvp.round"]
	equal(RoundFacts.hand_counts(round, "r1", 1), true)
	equal(round.players.b1.score, nil)
	equal(round.players.b1.handsLeft, 3)
	local delta = RoundFacts.timer_losses_to_apply(round, "r1", 1, "a1", nil)
	equal(delta, 0)
end)

local function round(losses, extra)
	local entry = { timerLosses = losses }
	for k, v in pairs(extra or {}) do
		entry[k] = v
	end
	return { runId = "r1", roundId = 3, phase = "playing", players = { u1 = entry, u2 = { timerLosses = 9 } } }
end

test("the server's timerLosses for me are applied once, as a delta", function()
	local delta, applied = RoundFacts.timer_losses_to_apply(round(1), "r1", 3, "u1", nil)
	equal(delta, 1)
	equal(applied.count, 1)
	-- The same push again changes nothing.
	delta, applied = RoundFacts.timer_losses_to_apply(round(1), "r1", 3, "u1", applied)
	equal(delta, 0)
	equal(applied.count, 1)
	-- A later push with one more run-out costs one more hand.
	delta, applied = RoundFacts.timer_losses_to_apply(round(3), "r1", 3, "u1", applied)
	equal(delta, 2)
	equal(applied.count, 3)
end)

test("the input record is never changed", function()
	local before = { run = "r1", round = 3, count = 1 }
	RoundFacts.timer_losses_to_apply(round(2), "r1", 3, "u1", before)
	equal(before.count, 1)
end)

test("a count that went down (a stale push) takes nothing back and keeps the higher count", function()
	local delta, applied =
		RoundFacts.timer_losses_to_apply(round(1), "r1", 3, "u1", { run = "r1", round = 3, count = 2 })
	equal(delta, 0)
	equal(applied.count, 2)
end)

test("a new round or run counts from what the server says, not from the old record", function()
	local old = { run = "r1", round = 2, count = 2 }
	local delta, applied = RoundFacts.timer_losses_to_apply(round(1), "r1", 3, "u1", old)
	equal(delta, 1)
	equal(applied.round, 3)
	local other_run = { run = "r0", round = 3, count = 2 }
	delta = RoundFacts.timer_losses_to_apply(round(1), "r1", 3, "u1", other_run)
	equal(delta, 1)
end)

test("nothing is applied when the round is not mine and open, or the count is unknown", function()
	local rec = { run = "r1", round = 3, count = 1 }
	local delta, kept = RoundFacts.timer_losses_to_apply(round(2), "r2", 3, "u1", rec)
	equal(delta, 0)
	equal(kept, rec)
	equal((RoundFacts.timer_losses_to_apply(round(2), "r1", 4, "u1", rec)), 0)
	equal((RoundFacts.timer_losses_to_apply(round(2), "r1", nil, "u1", rec)), 0)
	equal((RoundFacts.timer_losses_to_apply(nil, "r1", 3, "u1", rec)), 0)
	local resolved = round(2)
	resolved.phase = "resolved"
	equal((RoundFacts.timer_losses_to_apply(resolved, "r1", 3, "u1", rec)), 0)
	equal((RoundFacts.timer_losses_to_apply(round(2), "r1", 3, "u9", rec)), 0)
	local unknown = round(nil)
	equal((RoundFacts.timer_losses_to_apply(unknown, "r1", 3, "u1", rec)), 0)
end)

MPAPI = {
	BigScore = {
		normalize = function(text)
			return text:match("^%d+$") and text or nil
		end,
		compare = function(a, b)
			a, b = tonumber(a), tonumber(b)
			return a < b and -1 or (a > b and 1 or 0)
		end,
	},
}
dofile("lib/score.lua")

-- The entry as view.ts roundOf projects it: there is no handsDone key.
local function entry(fields)
	local out = { score = "300", handsLeft = 2, handsSpent = false, timerLosses = 0, canTime = true }
	for key, value in pairs(fields) do
		out[key] = value
	end
	return out
end
local MINE = { hands_left = 4, score = "0" }

test("resume_counts: the server's hands and a higher score replace mine", function()
	local plan = RoundFacts.resume_counts(MINE, entry({}))
	equal(plan.hands_left, 2)
	equal(plan.score, "300")
	equal(plan.run_hands_spent, false)
end)

test("resume_counts: a lower or equal or unknown server score keeps mine", function()
	equal(RoundFacts.resume_counts({ hands_left = 4, score = "500" }, entry({})).score, nil)
	equal(RoundFacts.resume_counts({ hands_left = 4, score = "300" }, entry({})).score, nil)
	equal(RoundFacts.resume_counts(MINE, entry({ score = false })).score, nil)
	equal(RoundFacts.resume_counts(MINE, entry({ score = 5 })).score, nil)
end)

test("resume_counts: no entry, unknown handsLeft or unknown handsSpent is nil with a reason", function()
	local plan, reason = RoundFacts.resume_counts(MINE, nil)
	equal(plan, nil)
	equal(reason, "no server entry")
	plan, reason = RoundFacts.resume_counts(MINE, entry({ handsLeft = false }))
	equal(plan, nil)
	equal(reason, "server handsLeft unknown")
	plan, reason = RoundFacts.resume_counts(MINE, entry({ handsLeft = "2" }))
	equal(plan, nil)
	plan, reason = RoundFacts.resume_counts(MINE, entry({ handsSpent = false }))
	equal(plan ~= nil, true)
	local unknown = entry({})
	unknown.handsSpent = nil
	plan, reason = RoundFacts.resume_counts(MINE, unknown)
	equal(plan, nil)
	equal(reason, "server handsSpent unknown")
	unknown.handsSpent = "true"
	equal((RoundFacts.resume_counts(MINE, unknown)), nil)
end)

test("resume_counts: handsSpent true writes no hands and runs nothing, even with handsLeft above 0", function()
	local plan = RoundFacts.resume_counts(MINE, entry({ handsSpent = true, handsLeft = 2 }))
	equal(plan.hands_left, nil)
	equal(plan.run_hands_spent, false)
	equal(plan.score, "300")
end)

test("resume_counts: handsLeft 0 with handsSpent false runs the hands-spent effect once", function()
	local plan = RoundFacts.resume_counts(MINE, entry({ handsLeft = 0 }))
	equal(plan.hands_left, nil)
	equal(plan.run_hands_spent, true)
	-- Already on 0 hands here: nothing to run, nothing to write.
	plan = RoundFacts.resume_counts({ hands_left = 0, score = "0" }, entry({ handsLeft = 0 }))
	equal(plan.run_hands_spent, false)
end)

test("selected_furthest: a selected blind is ante * 10 + its index, once it steps past the last report", function()
	equal(RoundFacts.selected_furthest(3, "Small", 0), 31)
	equal(RoundFacts.selected_furthest(3, "Big", 31), 32)
	equal(RoundFacts.selected_furthest(3, "Boss", 32), 33)
	equal(RoundFacts.selected_furthest(4, "Small", 33), 41)
	-- A blind already reported (skipped, or the same blind again) reports nothing.
	equal(RoundFacts.selected_furthest(3, "Big", 32), nil)
	equal(RoundFacts.selected_furthest(3, "Small", 32), nil)
	-- Nothing reported yet is a real start, not zero.
	equal(RoundFacts.selected_furthest(1, "Small", nil), 11)
end)

test("selected_furthest: an unknown blind or ante reports nothing", function()
	equal(RoundFacts.selected_furthest(3, nil, 0), nil)
	equal(RoundFacts.selected_furthest(3, "Tiny", 0), nil)
	equal(RoundFacts.selected_furthest(nil, "Big", 0), nil)
	equal(RoundFacts.selected_furthest(0, "Big", 0), nil)
end)

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
