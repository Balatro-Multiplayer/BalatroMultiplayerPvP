-- Run from the repo root: luajit tests/unit/lives_view_test.lua
-- The pure rules of lib/lives_view.lua that decide the elimination of a player in a game that
-- started with 3 or more players (R31), and the started player count.
PVP = {}
dofile("lib/_state_value.lua")
dofile("lib/applied_effects.lua")
dofile("lib/lives_view.lua")
local LivesView = PVP.LivesView
local AppliedEffects = PVP.AppliedEffects

local fixture = dofile("tests/unit/net_fixture.lua")

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

local function rules(count, run_id)
	return { runId = run_id or "r1", mode = "royale", startedCount = count }
end

-- `mine` is my seat; "b" and "c" are alive.
local function lives(mine, pending, run_id)
	return {
		runId = run_id or "r1",
		players = { a = mine, b = { lives = 2, eliminated = false }, c = { lives = 1, eliminated = false } },
		pending = pending or {},
	}
end
local OUT = { lives = 0, eliminated = true }
local ALIVE = { lives = 2, eliminated = false }
local WAITING = { playerId = "a", blindKey = "2:Big", waitsOn = { "b", "c" } }

local function fire(lives_value, rules_value, run_id, latched)
	return LivesView.should_eliminate(lives_value, rules_value, run_id or "r1", "a", latched)
end

-- started_count
check("started_count: the count of the same run", LivesView.started_count(rules(3), "r1"), 3)
check("started_count: a number run id matches its string", LivesView.started_count(rules(3, 7), "7"), 3)
check("started_count: another run's value is nil", LivesView.started_count(rules(3, "r0"), "r1"), nil)
check(
	"started_count: the idle value is nil",
	LivesView.started_count({ runId = nil, mode = nil, startedCount = 0 }, "r1"),
	nil
)
check("started_count: no value is nil", LivesView.started_count(nil, "r1"), nil)
check("started_count: no current run is nil", LivesView.started_count(rules(3), nil), nil)

-- should_eliminate
check("N=3, eliminated, no pending: fire", fire(lives(OUT), rules(3)), true)
check("N=8, eliminated, no pending: fire", fire(lives(OUT), rules(8)), true)
check("N=3, lives 0 without the flag: fire", fire(lives({ lives = 0 }), rules(3)), true)
check("N=3, eliminated, my pending entry: wait", fire(lives(OUT, { WAITING }), rules(3)), false)
check(
	"N=3, eliminated, someone else's pending entry: fire",
	fire(lives(OUT, { { playerId = "b", blindKey = "2:Big", waitsOn = { "a", "c" } } }), rules(3)),
	true
)
check("N=3, alive: no", fire(lives(ALIVE), rules(3)), false)
check("N=3, my seat missing: no", fire(lives(nil), rules(3)), false)
check("N=2, eliminated: no (the duel keeps its own end flow)", fire(lives(OUT), rules(2)), false)
check("N=1, eliminated: no", fire(lives(OUT), rules(1)), false)
check("already latched for this run: no", fire(lives(OUT), rules(3), "r1", "r1"), false)
check("latched in an older run, a new run: fire", fire(lives(OUT, {}, "r2"), rules(3, "r2"), "r2", "r1"), true)
check("wrong-run lives value: no", fire(lives(OUT, {}, "r0"), rules(3)), false)
check("wrong-run rules value: no", fire(lives(OUT), rules(3, "r0")), false)
check("no rules value: no", fire(lives(OUT), nil), false)
check("no lives value: no", fire(nil, rules(3)), false)
check(
	"result set: no (the result decides what I see)",
	LivesView.should_eliminate(lives(OUT), rules(3), "r1", "a", nil, true),
	false
)
check("result not set: fire", LivesView.should_eliminate(lives(OUT), rules(3), "r1", "a", nil, false), true)
check("no current run: no", LivesView.should_eliminate(lives(OUT), rules(3), nil, "a", nil), false)
check("no player id: no", LivesView.should_eliminate(lives(OUT), rules(3), "r1", nil, nil), false)

-- total_to_show: the server's total for me, only from a state of the current run.
do
	local value = lives(ALIVE)
	local cache = { a = 3, b = 4 }
	check("total: my lives from the cache", LivesView.total_to_show(value, cache, "r1", "a"), 3)
	check("total: a player the cache lacks", LivesView.total_to_show(value, cache, "r1", "z"), nil)
	check("total: no cache", LivesView.total_to_show(value, nil, "r1", "a"), nil)
	check("total: no current run", LivesView.total_to_show(value, cache, nil, "a"), nil)
	check("total: a stale state of another run", LivesView.total_to_show(value, cache, "r2", "a"), nil)
	check("total: no state value", LivesView.total_to_show(nil, cache, "r1", "a"), nil)
	check("total: zero lives is still a total", LivesView.total_to_show(value, { a = 0 }, "r1", "a"), 0)
end

-- The pvp.rules, pvp.lives and effects of the server's Teams 2v2 examples: one round lost by team A
-- (midgame), then the final state with team A out (result).
do
	local midgame = fixture("state_pvp_midgame").changed
	local final = fixture("state_pvp_result").changed
	check("midgame rules: four started", LivesView.started_count(midgame["pvp.rules"], "r1"), 4)

	local cache = LivesView.cache(midgame["pvp.lives"], "r1")
	check("midgame: a1 has 3 lives", cache.a1, 3)
	check("midgame: a2 has 3 lives", cache.a2, 3)
	check("midgame: b1 has 4 lives", cache.b1, 4)
	check("midgame: b2 has 4 lives", cache.b2, 4)
	cache = LivesView.cache(final["pvp.lives"], "r1")
	check("result: a1 has 0 lives", cache.a1, 0)
	check("result: a2 has 0 lives", cache.a2, 0)
	check("result: b1 has 4 lives", cache.b1, 4)
	check("result: b2 has 4 lives", cache.b2, 4)
	check("midgame: a value of another run shows nothing", LivesView.cache(midgame["pvp.lives"], "r2"), nil)
	check("midgame: no known lobby run shows nothing", LivesView.cache(midgame["pvp.lives"], nil), nil)
	check("idle value with no lobby run is an empty cache", next(LivesView.cache({ runId = nil, players = {} }, nil)), nil)

	-- The life-loss event of a1 (delta -1 under pvp:1) turns into the comeback gold and one life off.
	local ctx = { my_id = "a1", run_id = "r1", gold_on_life_loss = true, no_gold_on_round_loss = false }
	local effects, applied = AppliedEffects.step(midgame["pvp.lives"], nil, ctx)
	check("midgame: a1's loss gives two effects", #effects, 2)
	check("midgame: the comeback gold first", effects[1].type, "comebackBonus")
	check("midgame: then one life off", effects[2].type, "easeLives")
	check("midgame: the delta", effects[2].delta, -1)
	check("midgame: the lives after it", effects[2].lives, 3)
	check("midgame: one event applied", applied.events.a1, 1)
	check(
		"midgame: b1 has no event to apply",
		#AppliedEffects.step(midgame["pvp.lives"], nil, { my_id = "b1", run_id = "r1" }),
		0
	)

	-- The four events of a1 at the end, caught up at once: 3, 2, 1, 0 lives.
	ctx.gold_on_life_loss = false
	effects, applied = AppliedEffects.step(final["pvp.lives"], nil, ctx)
	check("result: a1's four losses give four effects", #effects, 4)
	check("result: lives after the first", effects[1].lives, 3)
	check("result: lives after the second", effects[2].lives, 2)
	check("result: lives after the third", effects[3].lives, 1)
	check("result: lives after the fourth", effects[4].lives, 0)
	check("result: four events applied", applied.events.a1, 4)

	-- With four started and nothing pending, a1 is told it is out at the end; b1 is not, and a1 is not at midgame.
	local rules_value = midgame["pvp.rules"]
	check("result: a1 is out", LivesView.should_eliminate(final["pvp.lives"], rules_value, "r1", "a1", nil), true)
	check("result: b1 is not", LivesView.should_eliminate(final["pvp.lives"], rules_value, "r1", "b1", nil), false)
	check(
		"midgame: a1 is not out",
		LivesView.should_eliminate(midgame["pvp.lives"], rules_value, "r1", "a1", nil),
		false
	)
end

if failed > 0 then
	print(("lives_view_test: %d failed"):format(failed))
	os.exit(1)
end
print(("lives_view_test: ok (%d)"):format(passed))
