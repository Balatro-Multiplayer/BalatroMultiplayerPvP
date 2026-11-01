-- Run from the repo root: lua5.4 tests/unit/lockstep_test.lua
local L = dofile("lib/lockstep.lua")

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function near(a, b, msg)
	if math.abs(a - b) > 1e-6 then error((msg or "") .. " expected ~" .. tostring(b) .. ", got " .. tostring(a), 2) end
end

-- run the clock in 0.1s steps, collecting events
local function run(clock, seconds, can_tick)
	local events = {}
	for _ = 1, math.floor(seconds * 10 + 0.5) do
		for _, e in ipairs(clock:update(0.1, can_tick ~= false)) do
			events[#events + 1] = e
		end
	end
	return events
end
local function count(events, type)
	local n = 0
	for _, e in ipairs(events) do
		if e.type == type then n = n + 1 end
	end
	return n
end

test("enter adds increment, capped", function()
	local c = L.new()
	c:enter("shop")
	eq(c.bank, 110)
	c.bank = 145
	c:enter("blind_select")
	eq(c.bank, 150)
end)

test("phase cap limits remaining even with a full bank", function()
	local c = L.new()
	c:enter("blind_select")
	eq(c:remaining(), 15)
end)

test("shop times out at phase cap, fires once, warns once", function()
	local c = L.new()
	c:enter("shop")
	local ev = run(c, 74)
	eq(count(ev, "warn"), 1)
	eq(count(ev, "timeout"), 0)
	ev = run(c, 1.1)
	eq(count(ev, "timeout"), 1)
	near(c.bank, 110 - 75, "bank charged")
end)

test("timeout retries if game doesn't move, then gives up", function()
	local c = L.new()
	c:enter("blind_select")
	run(c, 15)
	local ev = run(c, 30)
	eq(count(ev, "timeout"), 3, "max_retries")
end)

test("no ticking while animations run", function()
	local c = L.new()
	c:enter("shop")
	run(c, 100, false)
	eq(c.bank, 110)
end)

test("ready freezes the clock", function()
	local c = L.new()
	c:enter("shop")
	c:set_ready(true)
	local ev = run(c, 200)
	eq(#ev, 0)
	eq(c.bank, 110)
end)

test("collapse clamps to window when others are ready", function()
	local c = L.new()
	c:enter("shop")
	run(c, 10)
	c:set_others_ready(true)
	near(c:remaining(), 15)
	local ev = run(c, 15.1)
	eq(count(ev, "timeout"), 1)
end)

test("collapse never adds time", function()
	local c = L.new()
	c:enter("shop")
	run(c, 70)
	c:set_others_ready(true)
	near(c:remaining(), 5)
end)

test("round turns: per-turn cap, refresh + increment, followup collapse", function()
	local c = L.new()
	c:enter("round") -- bank 110
	eq(c:remaining(), 30)
	run(c, 20)
	c:turn()
	near(c.bank, 95, "110 - 20 + 5")
	eq(c:remaining(), 30)
	c:set_others_ready(true)
	eq(c:remaining(), 15)
	c:turn()
	eq(c:remaining(), 8, "followup window")
end)

test("grace floor: dry bank still gets a few seconds per decision", function()
	local c = L.new()
	c:enter("round")
	c.bank = 0
	near(c:remaining(), 4)
	local ev = run(c, 3.9)
	eq(count(ev, "timeout"), 0)
	ev = run(c, 0.2)
	eq(count(ev, "timeout"), 1)
end)

test("telegraph ramps 0 -> 1 over warn window", function()
	local c = L.new()
	c:enter("blind_select")
	eq(c:telegraph(), 0)
	run(c, 10)
	near(c:telegraph(), 0)
	run(c, 2.5)
	near(c:telegraph(), 0.5)
end)

test("pack spends parent's phase budget, parent re-fires after pack closes", function()
	local c = L.new()
	c:enter("shop")
	run(c, 60)
	c:enter("pack")
	near(c:remaining(), 15, "parent shop has 15 left")
	local ev = run(c, 15.1)
	eq(count(ev, "timeout"), 1)
	eq(ev[#ev].phase, "pack")
	c:exit()
	eq(c:phase(), "shop")
	ev = run(c, 0.1)
	eq(count(ev, "timeout"), 1, "shop fires right after")
end)

test("top-level enter replaces stack", function()
	local c = L.new()
	c:enter("shop")
	c:enter("pack")
	c:enter("blind_select")
	eq(#c.stack, 1)
end)

-- timeout table
local function seq(...)
	local rolls, i = { ... }, 0
	return function(n)
		i = i + 1
		local r = rolls[i] or 1
		assert(r >= 1 and r <= n, "roll out of range")
		return r
	end
end

test("blind select always takes the blind", function()
	for r = 1, 1 do
		eq(L.pick_timeout("blind_select", {}, seq(r)), "take_blind")
	end
end)

test("round: weighted hand vs discard", function()
	local ctx = { hands_left = 3, discards_left = 2 }
	eq(L.pick_timeout("round", ctx, seq(1)), "random_hand")
	eq(L.pick_timeout("round", ctx, seq(3)), "random_hand")
	eq(L.pick_timeout("round", ctx, seq(4)), "random_discard")
end)

test("round: mercy rule forces discard on last hand", function()
	eq(L.pick_timeout("round", { hands_left = 1, discards_left = 1 }, seq(1)), "random_discard")
end)

test("round: no discards left -> always plays", function()
	eq(L.pick_timeout("round", { hands_left = 1, discards_left = 0 }, seq(1)), "random_hand")
	eq(L.pick_timeout("round", { hands_left = 3, discards_left = 0 }, seq(3)), "random_hand")
end)

test("shop: impulse buy only when affordable", function()
	eq(L.pick_timeout("shop", { affordable = 2 }, seq(4)), "impulse_buy")
	eq(L.pick_timeout("shop", { affordable = 0 }, seq(3)), "leave_shop")
end)

test("pack: skip when nothing pickable", function()
	eq(L.pick_timeout("pack", { pickable = 0 }, seq(1)), "skip_pack")
	eq(L.pick_timeout("pack", { pickable = 3 }, seq(1)), "random_pick")
end)

test("every timeout key has an executor name in the table", function()
	local keys = {}
	for _, entries in pairs(L.TIMEOUTS) do
		for _, e in ipairs(entries) do
			keys[e.key] = true
		end
	end
	for _, k in ipairs({ "take_blind", "random_hand", "random_discard", "cash_out", "leave_shop", "impulse_buy", "random_pick", "skip_pack" }) do
		assert(keys[k], k)
	end
end)

print(string.format("lockstep: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
