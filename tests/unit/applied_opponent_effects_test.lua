-- Plain Lua test for lib/applied_opponent_effects.lua: the effects of "pvp.effects" an opponent's cards had on
-- this player apply exactly once, in order of n, only at an apply point. Run from the repo root:
-- luajit tests/unit/applied_opponent_effects_test.lua
PVP = {}
dofile("lib/_state_value.lua")
dofile("lib/applied_opponent_effects.lua")
local Step = PVP.AppliedOpponentEffects.step

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("ok   " .. name)
	else
		failed = failed + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function equal(got, want, what)
	assert(got == want, ("%s: got %s, wanted %s"):format(what or "value", tostring(got), tostring(want)))
end

local function state(incoming, run)
	return { runId = run or "run1", me = { incoming = incoming } }
end

local function rec(from, n, kind, amount)
	return { from = from, n = n, kind = kind, amount = amount }
end

local LIVE = { can_apply = true, run_id = "run1" }

local function names(effects)
	local out = {}
	for _, e in ipairs(effects) do
		out[#out + 1] = e.from .. "#" .. e.n .. ":" .. e.kind .. "=" .. e.amount
	end
	return table.concat(out, ",")
end

test("every record applies once, with the server's amount", function()
	local effects, applied, refused, waiting = Step(
		state({ rec("a", 1, "pizza", 1), rec("a", 2, "gambling", 10), rec("a", 3, "asteroid", 1) }),
		nil,
		LIVE
	)
	equal(names(effects), "a#1:pizza=1,a#2:gambling=10,a#3:asteroid=1")
	equal(#refused, 0, "refused")
	equal(waiting, false, "waiting")
	equal(applied.count, 3, "count")
	equal(applied.runId, "run1", "run")
end)

test("the same projection again applies nothing", function()
	local value = state({ rec("a", 1, "pizza", 1), rec("b", 2, "gambling", 10) })
	local _, applied = Step(value, nil, LIVE)
	local effects, again = Step(value, applied, LIVE)
	equal(#effects, 0, "effects")
	equal(again.count, 2)
end)

test("a longer projection applies only what is new", function()
	local _, applied = Step(state({ rec("a", 1, "pizza", 1) }), nil, LIVE)
	local effects, next_applied = Step(state({ rec("a", 1, "pizza", 1), rec("a", 2, "pizza", 1) }), applied, LIVE)
	equal(names(effects), "a#2:pizza=1")
	equal(next_applied.count, 2)
end)

test("an older projection after a newer one does nothing and the count never goes back", function()
	local _, applied = Step(state({ rec("a", 1, "pizza", 1), rec("a", 2, "pizza", 1) }), nil, LIVE)
	local effects, kept = Step(state({ rec("a", 1, "pizza", 1) }), applied, LIVE)
	equal(#effects, 0, "effects")
	equal(kept.count, 2, "count")
end)

test("a record arriving while it cannot apply is applied when it can", function()
	local value = state({ rec("a", 1, "gambling", 10) })
	local effects, applied, _, waiting = Step(value, nil, { can_apply = false, run_id = "run1" })
	equal(#effects, 0, "applied while blocked")
	equal(waiting, true, "waiting")
	equal(applied.count, 0, "counted while blocked")
	local later, marked, _, still = Step(value, applied, LIVE)
	equal(names(later), "a#1:gambling=10")
	equal(still, false, "still waiting")
	equal(marked.count, 1)
end)

test("effects are ordered by n, whatever the order of the list", function()
	local effects = Step(state({ rec("a", 3, "pizza", 1), rec("a", 1, "pizza", 1), rec("a", 2, "gambling", 10) }), nil, LIVE)
	equal(names(effects), "a#1:pizza=1,a#2:gambling=10,a#3:pizza=1")
end)

test("effects of two actors share one n, the position in my list", function()
	local effects, applied = Step(state({ rec("a", 1, "pizza", 1), rec("b", 2, "pizza", 1), rec("a", 3, "pizza", 1) }), nil, LIVE)
	equal(names(effects), "a#1:pizza=1,b#2:pizza=1,a#3:pizza=1")
	equal(applied.count, 3)
end)

test("a record listed twice applies once", function()
	local effects = Step(state({ rec("a", 1, "pizza", 1), rec("a", 1, "pizza", 1) }), nil, LIVE)
	equal(#effects, 1)
end)

test("a new run starts again from nothing", function()
	local _, applied = Step(state({ rec("a", 1, "pizza", 1) }, "run1"), nil, LIVE)
	local effects, next_applied = Step(state({ rec("a", 1, "pizza", 1) }, "run2"), applied, { can_apply = true, run_id = "run2" })
	equal(#effects, 1, "effects of the new run")
	equal(next_applied.runId, "run2")
end)

test("a state of another run than the live one changes nothing", function()
	local _, applied = Step(state({ rec("a", 1, "pizza", 1) }, "run1"), nil, LIVE)
	local effects, kept = Step(state({ rec("a", 9, "pizza", 1) }, "run0"), applied, LIVE)
	equal(#effects, 0, "effects")
	equal(kept, applied, "record")
end)

test("no live run: nothing applies and the effects wait", function()
	local effects, applied, _, waiting = Step(state({ rec("a", 1, "pizza", 1) }), nil, { can_apply = true, run_id = nil })
	equal(#effects, 0, "effects")
	equal(waiting, true, "waiting")
	equal(applied.count, 0, "count")
end)

test("a carried count of the run stops a re-read state applying again", function()
	local carried = { runId = "run1", count = 2 }
	local effects = Step(state({ rec("a", 1, "pizza", 1), rec("a", 2, "pizza", 1), rec("a", 3, "gambling", 10) }), carried, LIVE)
	equal(names(effects), "a#3:gambling=10")
end)

test("no projection for me, or none at all, is nothing", function()
	equal(#Step(nil, nil, LIVE), 0)
	equal(#Step({ runId = "run1", me = nil }, nil, LIVE), 0)
	equal(#Step({ runId = "run1" }, nil, LIVE), 0)
	equal(#Step({ me = { incoming = { rec("a", 1, "pizza", 1) } } }, nil, LIVE), 0, "no run on the value")
end)

test("a record with no whole positive amount is refused and does not hold up the next", function()
	local effects, applied, refused = Step(
		state({ rec("a", 1, "gambling", nil), rec("a", 2, "pizza", 1.5), rec("a", 3, "pizza", -1), rec("a", 4, "pizza", 1) }),
		nil,
		LIVE
	)
	equal(names(effects), "a#4:pizza=1")
	equal(#refused, 3, "refused")
	equal(applied.count, 4)
end)

test("an unknown kind is refused, never guessed at", function()
	local effects, _, refused = Step(state({ rec("a", 1, "magnet", 1), rec("a", 2, "pizza", 1) }), nil, LIVE)
	equal(names(effects), "a#2:pizza=1")
	equal(#refused, 1, "refused")
end)

test("a record that names no actor or number is refused", function()
	local effects, _, refused = Step(state({ { kind = "pizza", amount = 1 }, rec("a", 0, "pizza", 1), rec("a", 1, "pizza", 1) }), nil, LIVE)
	equal(names(effects), "a#1:pizza=1")
	equal(#refused, 2, "refused")
end)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
