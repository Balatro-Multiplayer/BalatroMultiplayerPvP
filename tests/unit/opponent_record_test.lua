-- Plain Lua test for lib/opponent_record.lua (pure, no game needed).
-- Run from the repo root: luajit tests/unit/opponent_record_test.lua
PVP = {}
dofile("lib/opponent_record.lua")
local R = PVP.OPPONENT_RECORD

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local function empty()
	return { sells = 0, sells_per_ante = {}, spent_in_shop = {} }
end

local TARGET, OTHER = "target", "other"

-- recorder
do
	local rec = R.apply(empty(), { opponent_selling_card = true, from = TARGET }, 2, TARGET, false)
	check("sell from target: total", rec.sells, 1)
	check("sell from target: this ante", rec.sells_per_ante[2], 1)
end

do
	local rec = empty()
	rec = R.apply(rec, { opponent_selling_card = true, from = TARGET }, 2, TARGET, false)
	rec = R.apply(rec, { opponent_selling_card = true, from = TARGET }, 2, TARGET, false)
	rec = R.apply(rec, { opponent_selling_card = true, from = TARGET }, 3, TARGET, false)
	check("sells per ante: ante 2", rec.sells_per_ante[2], 2)
	check("sells per ante: ante 3", rec.sells_per_ante[3], 1)
	check("sells total", rec.sells, 3)
end

do
	local rec = R.apply(empty(), { opponent_selling_card = true, from = OTHER }, 2, TARGET, false)
	check("sell from a non-target is ignored", rec.sells, 0)
	check("sell from a non-target leaves per-ante empty", rec.sells_per_ante[2], nil)
end

do
	local rec = R.apply(empty(), { opponent_selling_card = true, from = TARGET }, 2, TARGET, true)
	check("byed ignores sells", rec.sells, 0)
	rec = R.apply(empty(), { opponent_spent_in_shop = 9, from = TARGET }, 2, TARGET, true)
	check("byed ignores spends", #rec.spent_in_shop, 0)
end

do
	local rec = R.apply(empty(), { opponent_selling_card = true, from = OTHER }, 2, nil, false)
	check("no target yet: anyone counts", rec.sells, 1)
end

do
	local rec = empty()
	rec = R.apply(rec, { opponent_spent_in_shop = 7, from = TARGET }, 1, TARGET, false)
	rec = R.apply(rec, { opponent_spent_in_shop = "4", from = TARGET }, 1, TARGET, false)
	check("spend appends a number", rec.spent_in_shop[1], 7)
	check("spend coerces strings", rec.spent_in_shop[2], 4)
	check("spend list length", #rec.spent_in_shop, 2)
	rec = R.apply(rec, { opponent_spent_in_shop = "oops", from = TARGET }, 1, TARGET, false)
	check("unparseable spend is dropped", #rec.spent_in_shop, 2)
end

do
	local before = empty()
	local after = R.apply(before, { opponent_selling_card = true, from = TARGET }, 2, TARGET, false)
	check("input record is not mutated", before.sells, 0)
	check("output is a new record", after ~= before, true)
	-- Once per event, never once per joker copy.
	check("one event is exactly +1", after.sells, 1)
end

-- Hostile or broken spend values record 0, never inf / nan / negative.
for _, bad in ipairs({ "inf", "nan", "1e999", -5, "-5" }) do
	local rec = R.apply(empty(), { opponent_spent_in_shop = bad, from = TARGET }, 1, TARGET, false)
	check("bad spend " .. tostring(bad) .. " records 0", rec.spent_in_shop[1], 0)
end
do
	local rec = R.apply(empty(), { opponent_spent_in_shop = 5e9, from = TARGET }, 1, TARGET, false)
	check("spend is capped", rec.spent_in_shop[1], 1e9)
	rec = R.apply(empty(), { opponent_spent_in_shop = 0, from = TARGET }, 1, TARGET, false)
	check("zero spend is kept", rec.spent_in_shop[1], 0)
end

-- Taxes payout
check("taxes: nothing sold this ante, PvP reached, old sells are not counted", R.taxes_mult_gain({ [1] = 1, [2] = 3 }, 3, 2, 4), 0)
check("taxes: ante 2 within start round adds ante 1", R.taxes_mult_gain({ [1] = 1, [2] = 3 }, 2, 2, 4), 16)
check("taxes: after start round only this ante", R.taxes_mult_gain({ [1] = 1, [2] = 3, [3] = 2 }, 3, 2, 4), 8)
check("taxes: no sells", R.taxes_mult_gain({}, 2, 2, 4), 0)
check("taxes: ante 1 only counts ante 1", R.taxes_mult_gain({ [1] = 2 }, 1, 2, 4), 8)

-- Penny Pincher payout
check("pincher: $7 / 3 = 2", R.pincher_payout({ 7 }, 1, 3), 2)
check("pincher: $9 / 3 = 3", R.pincher_payout({ 0, 9 }, 2, 3), 3)
check("pincher: index past the end pays 0", R.pincher_payout({ 9 }, 2, 3), 0)
check("pincher: negative index pays 0", R.pincher_payout({ 9 }, -3, 3), 0)
check("pincher: under the divisor pays 0", R.pincher_payout({ 2 }, 1, 3), 0)
check("pincher: payout scales with dollars per step", R.pincher_payout({ 9 }, 1, 3, 2), 6)
check("pincher: dollars defaults to 1", R.pincher_payout({ 9 }, 1, 3), 3)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
