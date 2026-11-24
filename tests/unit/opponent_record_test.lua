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
-- Taxes payout
check("taxes: nothing sold this ante, PvP reached, old sells are not counted", R.taxes_mult_gain({ [1] = 1, [2] = 3 }, 3, 2, 4), 0)
check("taxes: ante 2 within start ante adds ante 1", R.taxes_mult_gain({ [1] = 1, [2] = 3 }, 2, 2, 4), 16)
check("taxes: after start ante only this ante", R.taxes_mult_gain({ [1] = 1, [2] = 3, [3] = 2 }, 3, 2, 4), 8)
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
check("pincher: no spends known pays 0", R.pincher_payout(nil, 1, 3), 0)
check("taxes: no sells known gains 0", R.taxes_mult_gain(nil, 2, 1, 4), 0)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
