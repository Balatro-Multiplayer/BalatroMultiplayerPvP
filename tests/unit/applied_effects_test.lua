-- Run from the repo root: luajit tests/unit/applied_effects_test.lua
-- lib/applied_effects.lua and lib/lives_view.lua are pure: table rows plus a property loop.
PVP = {}
dofile("lib/pending_death.lua")
dofile("lib/_state_value.lua")
dofile("lib/applied_effects.lua")
dofile("lib/lives_view.lua")
local AppliedEffects, LivesView = PVP.AppliedEffects, PVP.LivesView

local function equal(got, want, what)
	assert(got == want, ("%s: got %s, wanted %s"):format(what or "value", tostring(got), tostring(want)))
end

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

local function kinds(effects)
	local out = {}
	for _, e in ipairs(effects) do
		out[#out + 1] = e.type
	end
	return table.concat(out, ",")
end

local CTX =
	{ my_id = "me", run_id = "r1", gold_on_life_loss = true, no_gold_on_round_loss = false, blind_key = "2:Big" }

local function with(ctx, extra)
	local out = {}
	for k, v in pairs(ctx) do
		out[k] = v
	end
	for k, v in pairs(extra) do
		out[k] = v
	end
	return out
end

local function lives_value(run_id, lives, events, other_lives)
	return {
		runId = run_id,
		players = { me = { lives = lives, events = events }, they = { lives = other_lives or 4, events = {} } },
	}
end

test("step: a lives total that is missing applies nothing and keeps the record", function()
	local applied = { runId = "r1", events = { me = 0 } }
	local value = { runId = "r1", players = { me = { events = { { delta = -1 } } } } }
	local effects, record, rejected = AppliedEffects.step(value, applied, CTX)
	equal(#effects, 0, "effects")
	equal(record, applied, "record")
	equal(record.events.me, 0, "index")
	assert(rejected and rejected:find("lives total", 1, true), tostring(rejected))
end)

test("step: one event with no delta applies nothing for the whole batch", function()
	local applied = { runId = "r1", events = { me = 0 } }
	local value = { runId = "r1", players = { me = { lives = 2, events = { { delta = -1 }, {} } } } }
	local effects, record, rejected = AppliedEffects.step(value, applied, CTX)
	equal(#effects, 0, "effects")
	equal(record, applied, "record")
	assert(rejected and rejected:find("delta", 1, true), tostring(rejected))
end)

test("view cache: lives by player id, opponent lives 2", function()
	local cache = LivesView.cache(lives_value("r1", 3, {}, 2), "r1")
	equal(cache.me, 3)
	equal(cache.they, 2)
end)

test("view cache: nothing for no value, a stale run, or a player without lives", function()
	equal(LivesView.cache(nil, "r1"), nil)
	equal(LivesView.cache(lives_value("r0", 3, {}), "r1"), nil)
	equal(LivesView.cache({ runId = "r1", players = { a = { lives = 1 }, b = {} } }, nil), nil)
	local cache = LivesView.cache({ runId = "r1", players = { a = { lives = 1 }, b = {} } }, "r1")
	equal(cache.a, 1)
	equal(cache.b, nil)
end)

test("view cache: the idle value is an empty cache", function()
	local cache = LivesView.cache({ runId = nil, players = {}, teamLives = nil, pending = {} }, "r1")
	equal(next(cache), nil)
end)

test("a loss gives the comeback gold, then the lives, in the old handler's order", function()
	local effects, applied = AppliedEffects.step(lives_value("r1", 3, { { delta = -1, key = "2:Big" } }), nil, CTX)
	equal(kinds(effects), "comebackBonus,easeLives")
	equal(effects[2].delta, -1)
	equal(effects[2].lives, 3)
	equal(applied.events.me, 1)
	equal(applied.runId, "r1")
end)

test("no comeback gold when the lives before were 0 or the rule is off", function()
	local effects = AppliedEffects.step(lives_value("r1", 1, { { delta = 1, key = nil } }), nil, CTX)
	equal(kinds(effects), "easeLives")
	effects = AppliedEffects.step(
		lives_value("r1", 3, { { delta = -1, key = "2:Big" } }),
		nil,
		with(CTX, { gold_on_life_loss = false })
	)
	equal(kinds(effects), "easeLives")
end)

test("a gain (the Manhunt voucher) gives no comeback gold and no dollars zeroing", function()
	local effects = AppliedEffects.step(
		lives_value("r1", 4, { { delta = 1, key = nil } }),
		nil,
		with(CTX, { no_gold_on_round_loss = true })
	)
	equal(kinds(effects), "easeLives")
end)

test("a loss still gives the comeback gold", function()
	local effects = AppliedEffects.step(lives_value("r1", 3, { { delta = -1, key = "2:Big" } }), nil, CTX)
	equal(kinds(effects), "comebackBonus,easeLives")
end)

test("dollars are zeroed only for a loss in the blind being played now", function()
	local ctx = with(CTX, { no_gold_on_round_loss = true })
	local loss = lives_value("r1", 3, { { delta = -1, key = "2:Big" } })
	equal(kinds((AppliedEffects.step(loss, nil, ctx))), "comebackBonus,easeLives,zeroBlindDollars")
	equal(kinds((AppliedEffects.step(loss, nil, with(ctx, { blind_key = "2:Boss" })))), "comebackBonus,easeLives")
	local pvp = lives_value("r1", 3, { { delta = -1, key = "pvp:5" } })
	equal(
		kinds((AppliedEffects.step(pvp, nil, with(ctx, { blind_key = "pvp:5" })))),
		"comebackBonus,easeLives,zeroBlindDollars"
	)
	equal(kinds((AppliedEffects.step(pvp, nil, ctx))), "comebackBonus,easeLives")
	local off = with(ctx, { no_gold_on_round_loss = false })
	equal(kinds((AppliedEffects.step(loss, nil, off))), "comebackBonus,easeLives")
end)

test("blind_key names a normal blind and the PvP blind", function()
	equal(AppliedEffects.blind_key(false, "7", 2, "Big"), "2:Big")
	equal(AppliedEffects.blind_key(true, "7", 2, "Boss"), "pvp:7")
end)

test("a catch-up of several events reads lives before each from the server's total", function()
	local events = { { delta = -1, key = "1:Big" }, { delta = -1, key = "2:Big" } }
	local effects = AppliedEffects.step(lives_value("r1", 2, events), nil, CTX)
	equal(kinds(effects), "comebackBonus,easeLives,comebackBonus,easeLives")
	equal(effects[2].lives, 3)
	equal(effects[4].lives, 2)
	-- a player who fell to 0 and got one back: before the gain was 0, so no gold for it
	effects = AppliedEffects.step(lives_value("r1", 1, { { delta = -4, key = "3:Boss" }, { delta = 1 } }), nil, CTX)
	equal(kinds(effects), "comebackBonus,easeLives,easeLives")
end)

test("the same state again, or an older one, does nothing", function()
	local one = lives_value("r1", 3, { { delta = -1, key = "2:Big" } })
	local effects, applied = AppliedEffects.step(one, nil, CTX)
	equal(#effects, 2)
	local again, kept = AppliedEffects.step(one, applied, CTX)
	equal(#again, 0)
	equal(kept.events.me, 1)
	local older, kept2 = AppliedEffects.step(lives_value("r1", 4, {}), kept, CTX)
	equal(#older, 0)
	equal(kept2.events.me, 1)
end)

test("a runId change resets the index", function()
	local _, applied = AppliedEffects.step(lives_value("r1", 3, { { delta = -1, key = "2:Big" } }), nil, CTX)
	local effects, next_applied = AppliedEffects.step(
		lives_value("r2", 3, { { delta = -1, key = "1:Small" } }),
		applied,
		with(CTX, { run_id = "r2" })
	)
	equal(kinds(effects), "comebackBonus,easeLives")
	equal(next_applied.runId, "r2")
	equal(next_applied.events.me, 1)
end)

test("a value of another run than the lobby's, or the idle value, changes nothing", function()
	local _, applied = AppliedEffects.step(lives_value("r1", 3, { { delta = -1, key = "2:Big" } }), nil, CTX)
	local effects, kept = AppliedEffects.step(lives_value("r0", 3, { { delta = -1 }, { delta = -1 } }), applied, CTX)
	equal(#effects, 0)
	equal(kept, applied)
	effects, kept = AppliedEffects.step({ runId = nil, players = {}, pending = {} }, applied, CTX)
	equal(#effects, 0)
	equal(kept, applied)
	effects, kept = AppliedEffects.step(nil, nil, CTX)
	equal(#effects, 0)
	equal(kept, nil)
end)

test("a lobby with no known run applies nothing: unknown is not a wildcard", function()
	local value = lives_value("r1", 3, { { delta = -1, key = "2:Big" } })
	local ctx = with(CTX, {})
	ctx.run_id = nil
	local effects, kept, reason = AppliedEffects.step(value, nil, ctx)
	equal(#effects, 0)
	equal(kept, nil)
	equal(reason, nil)
	-- A record of another run is not reset and replayed by a value of any run either.
	local _, applied = AppliedEffects.step(lives_value("r0", 3, { { delta = -1 } }), nil, with(CTX, { run_id = "r0" }))
	effects, kept = AppliedEffects.step(value, applied, ctx)
	equal(#effects, 0)
	equal(kept, applied)
end)

test("only my own events count, other players' events apply nothing here", function()
	local value = lives_value("r1", 3, {})
	value.players.they.events = { { delta = -1, key = "2:Big" } }
	local effects = AppliedEffects.step(value, nil, CTX)
	equal(#effects, 0)
end)

-- Property: any replay and reorder of states (each a prefix of the server's log, as a push
-- or a snapshot) applies every event up to the longest prefix seen exactly once, and the
-- lives the effects end on are the server's.
test("property: replay and reorder of STATE/SNAPSHOT applies each event exactly once", function()
	math.randomseed(20261109)
	for _ = 1, 300 do
		local log, total = {}, 0
		local length = math.random(0, 9)
		for i = 1, length do
			local delta = math.random() < 0.8 and -1 or 1
			log[i] = { delta = delta, key = delta < 0 and ("%d:Big"):format(i) or nil }
		end
		local start = math.random(5, 9)
		for _, e in ipairs(log) do
			total = total + e.delta
		end
		local deliveries = math.random(1, 12)
		local applied, count, delta_sum, longest, comebacks, last_lives = nil, 0, 0, 0, 0, nil
		for _ = 1, deliveries do
			local n = math.random(0, length)
			local prefix, lives = {}, start
			for i = 1, n do
				prefix[i] = log[i]
				lives = lives + log[i].delta
			end
			local effects
			effects, applied = AppliedEffects.step(lives_value("r1", lives, prefix), applied, CTX)
			for _, e in ipairs(effects) do
				if e.type == "easeLives" then
					count = count + 1
					delta_sum = delta_sum + e.delta
					last_lives = e.lives
				elseif e.type == "comebackBonus" then
					comebacks = comebacks + 1
				end
			end
			longest = math.max(longest, n)
		end
		-- Reference walk: lives before each event, the comeback gold, the lives after the last.
		local want, want_comebacks, running = 0, 0, start
		for i = 1, longest do
			want = want + log[i].delta
			if running ~= 0 and log[i].delta < 0 then want_comebacks = want_comebacks + 1 end
			running = running + log[i].delta
		end
		equal(comebacks, want_comebacks, "comeback count")
		equal(last_lives, longest > 0 and running or nil, "final lives equal the server total")
		equal(count, longest, "applied count")
		equal(delta_sum, want, "applied delta")
	end
end)

if failures > 0 then os.exit(1) end
print("applied_effects_test: ok")
