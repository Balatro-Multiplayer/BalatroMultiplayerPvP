-- Run from the repo root: luajit tests/unit/clock_view_test.lua
-- lib/clock_view.lua: the personal clocks of the server's "pvp.clocks" state. The live math, an
-- unknown clock is nil and never 0, a bad entry is rejected, and the display clamps at 0.
PVP = {}
dofile("lib/_state_value.lua")
dofile("lib/clock_view.lua")
local View = PVP.ClockView

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

local function wire(fields)
	local entry = { ms = 100000, running = true, rate = 1, n = 3, spent = false }
	for name, value in pairs(fields or {}) do
		entry[name] = value
	end
	return entry
end

local function clock(fields, at)
	local c = View.parse(wire(fields))
	return View.keep(nil, c, at or 10)
end

-- parse / players

test("parse keeps the five fields of a good entry", function()
	local c = View.parse(wire())
	equal(c.ms, 100000)
	equal(c.running, true)
	equal(c.rate, 1)
	equal(c.n, 3)
	equal(c.spent, false)
end)

for _, row in ipairs({
	{ "ms", nil },
	{ "ms", -1 },
	{ "ms", "5" },
	{ "ms", 0 / 0 },
	{ "running", nil },
	{ "running", 1 },
	{ "rate", nil },
	{ "rate", 0 },
	{ "n", nil },
	{ "n", 1.5 },
	{ "n", -1 },
	{ "spent", "yes" },
	{ "spent", nil },
}) do
	test(("parse rejects %s = %s"):format(row[1], tostring(row[2])), function()
		local entry = wire()
		entry[row[1]] = row[2]
		local c, reason = View.parse(entry)
		equal(c, nil)
		equal(reason, row[1])
	end)
end

test("parse rejects a non-table entry", function()
	local c, reason = View.parse(5)
	equal(c, nil)
	equal(reason, "not a table")
end)

test("players: no value is nil, a value of another shape is nil", function()
	equal(View.players(nil), nil)
	equal(View.players("x"), nil)
end)

test("players: a bad entry is rejected with its reason, the others stay", function()
	local clocks, rejected = View.players({ me = wire(), they = wire({ ms = -5 }) })
	equal(clocks.me.ms, 100000)
	equal(clocks.they, nil)
	equal(rejected.they, "ms")
	equal(rejected.me, nil)
end)

test("players: an empty value lists nobody", function()
	local clocks, rejected = View.players({})
	equal(next(clocks), nil)
	equal(next(rejected), nil)
end)

-- keep

test("keep: a new n restarts the countdown from the pushed time", function()
	local kept = clock({ n = 3 }, 10)
	local pushed = View.parse(wire({ n = 4, ms = 50000 }))
	local next_clock = View.keep(kept, pushed, 20)
	equal(next_clock.ms, 50000)
	equal(next_clock.at, 20)
	equal(next_clock.n, 4)
end)

test("keep: a push of the same n keeps the countdown it has", function()
	local kept = clock({ n = 3, ms = 100000 }, 10)
	local pushed = View.parse(wire({ n = 3, ms = 100000 }))
	equal(View.keep(kept, pushed, 20), kept)
end)

test("keep: a snapshot of the same n restarts the countdown from its live time", function()
	local kept = clock({ n = 3, ms = 100000 }, 10)
	local snap = View.keep(kept, View.parse(wire({ n = 3, ms = 90000 })), 20, true)
	equal(snap.ms, 90000)
	equal(snap.at, 20)
	local held = View.keep(kept, View.parse(wire({ n = 3, ms = 100000, running = false })), 20, true)
	equal(held.running, false)
	equal(held.at, 20)
end)

test("keep: a later push of the same n and the frozen higher time keeps the snapshot's countdown", function()
	local kept = clock({ n = 3, ms = 100000 }, 10)
	local snap = View.keep(kept, View.parse(wire({ n = 3, ms = 90000 })), 20, true)
	equal(View.keep(snap, View.parse(wire({ n = 3, ms = 100000 })), 30), snap)
	equal(View.keep(snap, View.parse(wire({ n = 3, ms = 100000 })), 30, false), snap)
end)

test("keep: a lower n is taken like any new n", function()
	local kept = clock({ n = 9 }, 10)
	local next_clock = View.keep(kept, View.parse(wire({ n = 1, ms = 7000 })), 20)
	equal(next_clock.n, 1)
	equal(next_clock.ms, 7000)
end)

-- live_ms

test("live_ms: a running clock falls at its rate", function()
	equal(View.live_ms(clock({ rate = 1 }, 10), 12), 98000)
	equal(View.live_ms(clock({ rate = 2 }, 10), 12), 96000)
end)

test("live_ms: a held clock stands still", function()
	equal(View.live_ms(clock({ running = false }, 10), 500), 100000)
end)

test("live_ms: the display clamps at 0", function()
	equal(View.live_ms(clock({ ms = 1000 }, 10), 99), 0)
end)

test("live_ms: a clock never counts backwards", function()
	equal(View.live_ms(clock({}, 10), 5), 100000)
end)

test("live_ms: 0 ms stays 0, a known value", function()
	equal(View.live_ms(clock({ ms = 0, running = false }, 10), 11), 0)
end)

test("live_ms: unknown clock or unknown time is nil, not 0", function()
	equal(View.live_ms(nil, 5), nil)
	equal(View.live_ms(clock({}, 10), nil), nil)
	equal(View.live_ms({ ms = 5, running = true, rate = 1 }, 5), nil)
end)

-- read

test("read: an unknown clock is { known = false } and nothing else", function()
	local r = View.read(nil, 5)
	equal(r.known, false)
	equal(r.ms, nil)
	equal(r.running, nil)
end)

test("read: a running clock", function()
	local r = View.read(clock({ rate = 2, spent = false }, 10), 11)
	equal(r.known, true)
	equal(r.ms, 98000)
	equal(r.running, true)
	equal(r.rate, 2)
	equal(r.spent, false)
end)

test("read: a held (not running) and spent clock", function()
	local r = View.read(clock({ running = false, spent = true, ms = 0 }, 10), 20)
	equal(r.running, false)
	equal(r.spent, true)
	equal(r.ms, 0)
end)

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
