-- Plain Lua test for lib/opponent_record.lua (pure, no game needed): the readers of what the server
-- recorded about the opponent. Run from the repo root: luajit tests/unit/opponent_record_test.lua
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

-- Taxes
check("taxes: nothing sold this ante, PvP reached, old sells are not counted", R.taxes_mult_gain({ [1] = 1, [2] = 3 }, 3, 2, 4), 0)
check("taxes: ante 2 within start round adds ante 1", R.taxes_mult_gain({ [1] = 1, [2] = 3 }, 2, 2, 4), 16)
check("taxes: after start round only this ante", R.taxes_mult_gain({ [1] = 1, [2] = 3, [3] = 2 }, 3, 2, 4), 8)
check("taxes: no sells", R.taxes_mult_gain({}, 2, 2, 4), 0)
check("taxes: ante 1 only counts ante 1", R.taxes_mult_gain({ [1] = 2 }, 1, 2, 4), 8)
check("taxes: JSON string keys read the same", R.taxes_mult_gain({ ["1"] = 1, ["2"] = 3 }, 2, 2, 4), 16)

-- by_ante
check("by_ante: number key", R.by_ante({ [2] = 5 }, 2), 5)
check("by_ante: string key", R.by_ante({ ["2"] = 5 }, 2), 5)
check("by_ante: absent", R.by_ante({ [2] = 5 }, 3), nil)
check("by_ante: no map", R.by_ante(nil, 3), nil)
check("by_ante: no ante", R.by_ante({ [2] = 5 }, nil), nil)

-- B3: a spend the server cannot take is not a spend. It is never stored as 0.
for _, bad in ipairs({ 0 / 0, -4, math.huge, "oops", true, R.MAX_SPEND + 1 }) do
	check("B3 valid_spend rejects " .. tostring(bad), R.valid_spend(bad), false)
end
check("valid_spend: 0 is a spend", R.valid_spend(0), true)
check("valid_spend: the cap is a spend", R.valid_spend(R.MAX_SPEND), true)
check("valid_spend: 7", R.valid_spend(7), true)
check("valid_spend: a fraction is not a spend the server takes", R.valid_spend(2.5), false)

-- A slot the server holds but cannot be read as a spend pays nothing, by the written rule, not $0 as a spend.
do
	local row = { each = { "t" }, one = "t" }
	for _, bad in ipairs({ -4, "oops", true }) do
		local target = { slots = { { ante = 1, spent = bad } }, closed = false }
		check("B3 a bad stored spend " .. tostring(bad) .. " pays none", R.pincher_payout(row, target, 1, 3, 1).status, R.NONE)
	end
end

-- The server's record readers
local round = { runId = "r1", players = { me = { ante = 2 }, they = { ante = 3 } } }
check("player_ante: this run", R.player_ante(round, "r1", "me"), 2)
check("player_ante: another run is unknown", R.player_ante(round, "r0", "me"), nil)
check("player_ante: no run is unknown", R.player_ante(round, nil, "me"), nil)
check("player_ante: a player the state does not name", R.player_ante(round, "r1", "x"), nil)
check("player_ante: no state", R.player_ante(nil, "r1", "me"), nil)

local nemesis = { runId = "r1", byAnte = { ["1"] = { each = { "a" }, one = "a" }, ["2"] = { each = {} } } }
check("nemesis_row: string ante key", R.nemesis_row(nemesis, "r1", 1).one, "a")
check("nemesis_row: a known ante with nobody", R.nemesis_row(nemesis, "r1", 2).one, nil)
check("nemesis_row: a known ante with nobody is a row", R.nemesis_row(nemesis, "r1", 2) ~= nil, true)
check("nemesis_row: an ante not frozen yet is unknown", R.nemesis_row(nemesis, "r1", 3), nil)
check("nemesis_row: another run is unknown", R.nemesis_row(nemesis, "r0", 1), nil)

local opponent = { runId = "r1", players = { a = { sells = { ["1"] = 2 }, slots = { { ante = 1, spent = 9 } }, closed = false } } }
check("player: this run", R.player(opponent, "r1", "a").sells["1"], 2)
check("player: another run is unknown", R.player(opponent, "r0", "a"), nil)
check("player: unseated is unknown", R.player(opponent, "r1", "zz"), nil)
check("slot: recorded", R.slot(opponent, "r1", "a", 1).spent, 9)
check("slot: not recorded yet", R.slot(opponent, "r1", "a", 2), nil)

-- Penny Pincher: pending, none and dollars
local function slots(...)
	return { slots = { ... }, closed = false }
end
local row = { each = { "t" }, one = "t" }
local function pay(r, target, s, divisor, dollars)
	return R.pincher_payout(r, target, s, divisor, dollars or 1)
end
check("pincher: $7 / 3 = 2", pay(row, slots({ spent = 7 }), 1, 3).dollars, 2)
check("pincher: $9 / 3 = 3", pay(row, slots({ spent = 0 }, { spent = 9 }), 2, 3).dollars, 3)
check("pincher: under the divisor pays 0 dollars", pay(row, slots({ spent = 2 }), 1, 3).dollars, 0)
check("pincher: a spend is dollars", pay(row, slots({ spent = 9 }), 1, 3).status, R.DOLLARS)
check("pincher: payout scales with dollars per step", pay(row, slots({ spent = 9 }), 1, 3, 2).dollars, 6)
check("pincher: no slot yet (s < 1) is none", pay(row, slots({ spent = 9 }), 0, 3).status, R.NONE)
check("pincher: negative slot is none", pay(row, slots({ spent = 9 }), -2, 3).status, R.NONE)
check("pincher: the nemesis row not frozen is pending", pay(nil, nil, 1, 3).status, R.PENDING)
check("pincher: one === null (a bye) is none", pay({ each = {} }, nil, 1, 3).status, R.NONE)
check("pincher: no record of the opponent yet is pending", pay(row, nil, 1, 3).status, R.PENDING)
check("pincher: slot not recorded, live opponent is pending", pay(row, slots({ spent = 9 }), 2, 3).status, R.PENDING)
check(
	"pincher: slot not recorded, opponent left is none",
	pay(row, { slots = { { spent = 9 } }, closed = true }, 2, 3).status,
	R.NONE
)
check("pincher: a skipped slot is none", pay(row, slots({ skipped = true }), 1, 3).status, R.NONE)
check("pincher: a refused slot is none", pay(row, slots({ refused = "implausible" }), 1, 3).status, R.NONE)

-- B4: the opponent's true slots are [spend 9, skip, spend 6]. My Pincher at slot 2 reads the skip: $0 by rule,
-- and slot 3 reads the $6 shop. No late zero shifts the list.
do
	local target = slots({ ante = 1, spent = 9 }, { ante = 1, skipped = true }, { ante = 2, spent = 6 })
	check("B4 Pincher pays none for the opponent's skipped slot 2", pay(row, target, 2, 3).status, R.NONE)
	check("B4 Pincher reads the spend of slot 3 at slot 3", pay(row, target, 3, 3).dollars, 2)
	check("B4 Pincher reads the spend of slot 1 at slot 1", pay(row, target, 1, 3).dollars, 3)
end

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
