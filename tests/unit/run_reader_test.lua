-- Run from the repo root: luajit tests/unit/run_reader_test.lua
-- The run-side bodies and the opponent's run read from the view. Plain values only.
PVP = {}
dofile("pvp_api/_view.lua")
dofile("pvp_api/run_reader.lua")
local reader = PVP.run_reader

local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local function show(value)
	if type(value) ~= "table" then return tostring(value) end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. show(value[key]) end
	return "{" .. table.concat(parts, ",") .. "}"
end
local function same(actual, expected, message) eq(show(actual), show(expected), message) end

-- Bodies, with the server's field names.
same(reader.progress(3, "Shop"), { ante = 3, location = "Shop" }, "progress")
eq(reader.progress(3, nil), nil, "progress: no location")
same(reader.blind_result(2, "Boss", "lost"), { blindKey = "2:Boss", result = "lost" }, "blind result: lost")
same(reader.blind_result(2, "Big", "beaten"), { blindKey = "2:Big", result = "beaten" }, "blind result: beaten")
same(reader.blind_result(2, "Boss", "failed on the clock"), { blindKey = "2:Boss", result = "failed on the clock" }, "blind result: failed on the clock")
eq(reader.blind_result(2, "Nemesis", "beaten"), nil, "blind result: not a blind")
eq(reader.blind_result(2, "Big", nil), nil, "blind result: result unknown")
same(reader.skip(2, "Small", 1), { blindKey = "2:Small", total = 1 }, "skip")
eq(reader.skip(2, "Boss", 1), nil, "skip: a Boss cannot be skipped")
eq(reader.skip(2, "Big", 0), nil, "skip: total starts at 1")
same(reader.sell(2, 3), { ante = 2, total = 3 }, "sell")
same(reader.shop(2, 1, 7), { ante = 2, total = 1, spent = 7 }, "shop")
same(reader.shop(2, 1, 0), { ante = 2, total = 1, spent = 0 }, "shop: nothing spent is 0")
same(reader.shop(2, 1, 7.9), { ante = 2, total = 1, spent = 7 }, "shop: whole dollars")
same(reader.shop(2, 1, 1e9), { ante = 2, total = 1, spent = 1000000 }, "shop: capped")
eq(reader.shop(2, 1, -1), nil, "shop: no negative spend")
same(reader.voucher("v_mp_hieroglyph_manhunt"), { voucherKey = "v_mp_hieroglyph_manhunt" }, "voucher")
eq(reader.voucher(""), nil, "voucher: no key")
same(reader.effect("gambling", 2), { effect = "gambling", total = 2 }, "effect")
eq(reader.effect("traps", 1), nil, "effect: not an effect card")

-- Shape only: the server owns the limits.
eq(reader.progress(-1, "Shop"), nil, "ante: not negative")
eq(reader.progress(2.5, "Shop"), nil, "ante: whole")
eq(reader.progress(0, "Shop").ante, 0, "ante 0 is valid")
eq(reader.progress(3, ""), nil, "location: not empty")
eq(reader.progress(3, 7), nil, "location: text")
eq(reader.blind_result(2, "Big", "skipped"), nil, "blind result: a skip has its own input")
eq(reader.blind_result(2, "Big", true), nil, "blind result: a flag is no result")
eq(reader.blind_result(2, "Big", "won"), nil, "blind result: only the named results")
eq(reader.skip(2, "Small", 1.5), nil, "skip total whole")
eq(reader.skip(2, "Small", -1), nil, "skip total not negative")
eq(reader.sell(2, 0), nil, "sell: total starts at 1")
eq(reader.sell(2, 1.5), nil, "sell: total whole")
eq(reader.sell(2, -1), nil, "sell: total not negative")
eq(reader.sell(-1, 1), nil, "sell: ante not negative")
eq(reader.shop(2, 0, 1), nil, "shop: total starts at 1")
eq(reader.shop(2, 1.5, 1), nil, "shop: total whole")
eq(reader.shop(2, 1, 0 / 0), nil, "shop: no NaN spend")
eq(reader.shop(2, 1, "7"), nil, "shop: spend is a number")
eq(reader.shop(2, 1, 1000000).spent, 1000000, "shop: spend at the cap")
eq(reader.voucher(5), nil, "voucher key is text")
eq(reader.effect("pizza", 0), nil, "effect: total starts at 1")
eq(reader.effect("pizza", 1.5), nil, "effect: total whole")

-- The opponent's run from the view.
local function view(player)
	return { match = { run = { targets = { opponents = { "b" } }, players = { a = { lives = 4 }, b = player } } } }
end

eq(reader.opponent_facts(nil), nil, "no view")
eq(reader.opponent_facts({ match = { run = { targets = { opponents = {} }, players = {} } } }), nil, "no opponent")
local facts = reader.opponent_facts(view({
	lives = 3, ante = 4, location = "Shop", skips = 2, sells = { ["2"] = 1, ["3"] = 2 }, shopSpends = { 5, 0 },
}))
eq(facts.lives, 3, "lives")
eq(facts.ante, 4, "ante")
eq(facts.location, "Shop", "location")
eq(facts.skips, 2, "skips")
eq(facts.sells[2], 1, "sells: ante turned into a number")
eq(facts.sells[3], 2, "sells: ante 3")
eq(facts.shop_spends[2], 0, "shop spends: second shop")

local bare = reader.opponent_facts(view({ lives = 3 }))
eq(bare.lives, 3, "bare: lives known")
for _, name in ipairs({ "ante", "location", "skips", "sells", "shop_spends" }) do
	eq(bare[name], nil, "bare: " .. name .. " unknown, not defaulted")
end

eq(reader.opponent_facts(view({ ante = 1 })).lives, nil, "lives unknown, not defaulted")

-- A shop without a total is a hole in the list.
local holes = { [1] = 4, [3] = 6 }
local gap = reader.opponent_facts(view({ shopSpends = holes }))
eq(gap.shop_spends[1], 4, "hole: first shop")
eq(gap.shop_spends[2], nil, "hole: unknown shop stays unknown")
eq(gap.shop_spends[3], 6, "hole: third shop")

-- What the view cannot say as a number or text is unknown.
local odd = reader.opponent_facts(view({ sells = { x = 1, ["2"] = "many", ["3"] = 4 }, shopSpends = { x = 9, 7 }, location = 5 }))
same(odd.sells, { [3] = 4 }, "sells: an ante that is not a number or a count that is not a number is left out")
same(odd.shop_spends, { 7 }, "shop spends: a place that is not a number is left out")
eq(odd.location, nil, "location: not text is unknown")

-- Once only.
eq(#reader.changed(nil, facts), #reader.FACTS, "first view: every fact is shown")
same(reader.changed(facts, reader.opponent_facts(view({
	lives = 3, ante = 4, location = "Shop", skips = 2, sells = { ["2"] = 1, ["3"] = 2 }, shopSpends = { 5, 0 },
}))), {}, "the same view again shows nothing")
local later = reader.opponent_facts(view({
	lives = 2, ante = 4, location = "Shop", skips = 2, sells = { ["2"] = 1, ["3"] = 3 }, shopSpends = { 5, 0 },
}))
same(reader.changed(facts, later), { "lives", "sells" }, "only what changed is shown")
same(reader.changed(facts, nil), reader.FACTS, "a view that lost the opponent clears every fact")

-- A fact that only gains or loses a key is a change.
local function one(fields) return reader.opponent_facts(view(fields)) end
same(reader.changed(one({ sells = { ["2"] = 1 } }), one({ sells = { ["2"] = 1, ["4"] = 1 } })), { "sells" }, "sells gain an ante")
same(reader.changed(one({ sells = { ["2"] = 1, ["4"] = 1 } }), one({ sells = { ["2"] = 1 } })), { "sells" }, "sells lose an ante")
same(reader.changed(one({ shopSpends = { 5 } }), one({ shopSpends = { 5, 0 } })), { "shop_spends" }, "shop spends gain a shop")
same(reader.changed(one({ shopSpends = { 5, 0 } }), one({ shopSpends = { 5 } })), { "shop_spends" }, "shop spends lose a shop")
same(reader.changed(one({ sells = { ["2"] = 1 } }), one({ sells = { ["2"] = 1 } })), {}, "equal sells are no change")

-- A skip is a known count going up: never from nothing known, never equal, down or not a number.
for _, row in ipairs({
	{ 0, 1, true }, { 2, 5, true }, { 3, 3, false }, { 3, 2, false },
	{ nil, 1, false }, { 1, nil, false }, { nil, nil, false }, { "1", 2, false }, { 1, "2", false },
}) do
	eq(reader.skips_gained(row[1], row[2]), row[3], "skips_gained " .. tostring(row[1]) .. " -> " .. tostring(row[2]))
end

-- opponent_shown: what to show of the opponent's run this frame
local function table_view(opponents, players, statuses)
	return { me = "me", players = statuses or {}, match = { run = { targets = { opponents = opponents }, players = players } } }
end
local nothing = { facts = nil, id = nil, lives_guess = "none" }
local shown_cases = {
	{
		name = "the first view shows every fact, even unknown ones",
		before = nothing, table_is = "new", view = table_view({ "a" }, { a = { lives = 3, ante = 2 } }),
		lives_from = "opponent", reset = "keep", names = { "lives", "ante", "location", "skips", "sells", "shop_spends" },
		next_id = "a", next_guess = "none",
	},
	{
		name = "the same facts again show nothing",
		before = { facts = { lives = 3, ante = 2 }, id = "a", lives_guess = "none" }, table_is = "same",
		view = table_view({ "a" }, { a = { lives = 3, ante = 2 } }),
		lives_from = "opponent", reset = "keep", names = {}, next_id = "a", next_guess = "none",
	},
	{
		name = "one fact changing shows only it",
		before = { facts = { lives = 3, ante = 2 }, id = "a", lives_guess = "none" }, table_is = "same",
		view = table_view({ "a" }, { a = { lives = 2, ante = 2 } }),
		lives_from = "opponent", reset = "keep", names = { "lives" }, next_id = "a", next_guess = "none",
	},
	{
		name = "another player under the same table starts over",
		before = { facts = { lives = 3 }, id = "a", lives_guess = "none" }, table_is = "same",
		view = table_view({ "b" }, { b = { lives = 1 } }),
		lives_from = "opponent", reset = "new opponent", names = { "lives", "ante", "location", "skips", "sells", "shop_spends" },
		next_id = "b", next_guess = "none",
	},
	{
		name = "an opponent arriving drops the guessed lives",
		before = { facts = { lives = 4 }, id = nil, lives_guess = "highest of others" }, table_is = "same",
		view = table_view({ "b" }, { b = { lives = 4 } }),
		lives_from = "opponent", reset = "guessed lives dropped", names = { "lives" },
		next_id = "b", next_guess = "none",
	},
	{
		name = "a gap shows the highest lives of the others",
		before = nothing, table_is = "new",
		view = table_view({}, { me = { lives = 5 }, x = { lives = 2 }, y = { lives = 4 } }),
		lives_from = "highest of others", reset = "keep", names = { "lives" }, next_id = nil, next_guess = "highest of others",
	},
	{
		name = "a gap with an out opponent keeps their lives",
		before = { facts = { lives = 1 }, id = "a", lives_guess = "none" }, table_is = "same",
		view = table_view({}, { a = { lives = 0 }, x = { lives = 4 } }, { a = { status = "out" } }),
		lives_from = "out opponent", reset = "keep", names = { "lives" }, next_id = "a", next_guess = "none",
	},
	{
		name = "a gap with nobody known shows nothing",
		before = nothing, table_is = "new", view = table_view({}, {}),
		lives_from = "none", reset = "keep", names = {}, next_id = nil, next_guess = "none",
	},
}
for _, case in ipairs(shown_cases) do
	local got = reader.opponent_shown(case.before, case.view, case.table_is)
	eq(got.lives_from, case.lives_from, case.name .. ": lives_from")
	eq(got.reset, case.reset, case.name .. ": reset")
	local names = {}
	for _, change in ipairs(got.show) do names[#names + 1] = change.name end
	eq(table.concat(names, ","), table.concat(case.names, ","), case.name .. ": shown")
	eq(got.next.id, case.next_id, case.name .. ": next id")
	eq(got.next.lives_guess, case.next_guess, case.name .. ": next guess")
end

print(string.format("run_reader_test: %d checks ok", checks))
