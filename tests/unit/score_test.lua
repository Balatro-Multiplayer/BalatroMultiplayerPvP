-- Plain Lua test for PVP.Score (no game needed).
-- Run from the repo root: luajit tests/unit/score_test.lua
-- Needs the MPAPI repo next to this one (BalatroMultiplayerAPI/lib/big_score.lua).
MPAPI = {}
PVP = {}
dofile("../BalatroMultiplayerAPI/lib/big_score.lua")
dofile("lib/score.lua")
local S = PVP.Score

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(tostring(name), tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

-- Score text, from the ADR: 10^100 and 10^10^20, next to plain numbers.
local PLAIN = "999999999999999"
local E100 = "100,1"
local TOWER = "20,2"

check("zero is not greater than zero", S.greater(S.ZERO, S.ZERO), false)
check("zero equals zero", S.equal("0", "0"), true)
check("a plain score beats zero", S.greater("5", "0"), true)
check("10 beats 9, not text order", S.greater("10", "9"), true)
check("an exponent score beats a big plain score", S.greater(E100, PLAIN), true)
check("a plain score does not beat an exponent score", S.greater(PLAIN, E100), false)
check("a tower beats an exponent score", S.greater(TOWER, E100), true)
check("an exponent score does not beat a tower", S.greater(E100, TOWER), false)
check("same text is equal", S.equal(E100, E100), true)
check("a missing score counts as zero", S.greater("1", nil), true)
check("a missing score equals zero", S.equal(nil, "0"), true)
check("a malformed score counts as zero", S.greater("1", "banana"), true)
check("a malformed score equals zero", S.equal("1e5", "0"), true)
check("a number is not score text", S.parse(5), nil)
check("parse gives canonical text", S.parse("12345"), "12345")
check("or_zero of garbage", S.or_zero("x"), "0")

check("display of a small score has comma groups", S.display("1234567"), "1,234,567")
check("display of an exponent score", S.display(E100), "1e100")
check("display of nothing", S.display(nil), "0")

check("small_number of a small score", S.small_number("42"), 42)
check("small_number of an exponent score", S.small_number(E100), nil)
check("small_number of a score past the switch point", S.small_number("100000000000"), nil)

check("from a double", S.from_game_value(1234), "1234")
check(
	"a big-number-mod value and a double agree",
	S.from_game_value({ array = { 1234 }, sign = 1 }),
	S.from_game_value(1234)
)
check("an Amulet-style value past 1e308", S.from_game_value({ array = { 400, 1 }, sign = 1 }), "400,1")

-- Fakes shaped like the two mods' constructors.
-- Talisman: to_big(number) or to_big(array) builds {array, sign}; a table that wraps
-- the array ({ array = ... }) has no array[1] and normalizes to 0.
-- Amulet: to_big(number) or to_big(array, sign); the value hides its array behind
-- get_array() (its .array is a shared empty table), and a wrapping table reads as 0.
local function make_mod(kind, add)
	local mt = { __add = add }
	local function build(array, sign)
		local held = { array[1] or 0, array[2] }
		if kind == "amulet" then
			return setmetatable({
				array = {},
				sign = sign,
				get_array = function() return held end,
			}, mt)
		end
		return setmetatable({ array = held, sign = sign }, mt)
	end
	return function(x, sign)
		sign = sign or 1
		if type(x) == "number" then return build({ x }, sign) end
		return build(x, sign)
	end
end
local function add_first_entries(x, y)
	local function entries(v)
		return v.get_array and v.get_array() or v.array
	end
	local a, b = entries(x), entries(y)
	local sum = { a[1] + b[1], a[2] or b[2] }
	local result = setmetatable({ array = sum, sign = 1 }, getmetatable(x))
	if x.get_array then
		result.get_array = function() return sum end
	end
	return result
end

-- With a number mod, a score reads back through the mod's own number.
for _, kind in ipairs({ "talisman", "amulet" }) do
	local saved = to_big
	to_big = make_mod(kind, add_first_entries)
	check(kind .. ": to_game_value reads back", MPAPI.BigScore.from_game_value(S.to_game_value("1234.5,1")), "1234.5,1")
	check(kind .. ": to_game_value of a plain score", MPAPI.BigScore.from_game_value(S.to_game_value("12345")), "12345")
	check(kind .. ": to_game_value of a tower", MPAPI.BigScore.from_game_value(S.to_game_value("20,3")), "20,3")
	check(kind .. ": to_game_value of malformed text", S.to_game_value("banana"), nil)
	to_big = saved
end

-- A mod that returns 0 for an array score without an error (Amulet given a wrapping
-- table): to_game_value refuses it.
do
	local saved = to_big
	local real = make_mod("amulet", add_first_entries)
	to_big = function(x, sign)
		if type(x) == "table" and x.array then return real(0, sign) end
		return real(x, sign)
	end
	check("zero from a wrapping table is built right now", MPAPI.BigScore.from_game_value(S.to_game_value("400,1")), "400,1")
	to_big = function(x, sign)
		if type(x) == "table" then return real(0, sign) end
		return real(x, sign)
	end
	local value, reason = S.to_game_value("400,1")
	check("a zero for a nonzero array score is refused", value, nil)
	check("the refusal says why", type(reason) == "string" and reason:find("different value", 1, true) ~= nil, true)
	to_big = saved
end

-- First-entry rounding of 1 ulp from the mod's own log10 is accepted; a wrong score is not.
do
	local saved = to_big
	local real = make_mod("talisman", add_first_entries)
	local nudge = 1
	to_big = function(x, sign)
		local v = real(x, sign)
		if type(x) == "table" then v.array[1] = v.array[1] * (1 + nudge) end
		return v
	end
	nudge = 2e-16
	check("1 ulp in the first entry is accepted", S.to_game_value("20.17609125905568,3") ~= nil, true)
	nudge = 1e-3
	check("a wrong first entry is refused", S.to_game_value("20.17609125905568,3"), nil)
	to_big = saved
end

-- Talisman's BigNum mode reads the second argument of to_big as an exponent, so a
-- plain score is built from the number alone.
do
	local saved = to_big
	local real = make_mod("talisman", add_first_entries)
	to_big = function(x, exponent)
		if type(x) == "number" then return real(x * 10 ^ (exponent or 0)) end
		return real(x)
	end
	check("bignum mode: a plain score keeps its value", MPAPI.BigScore.from_game_value(S.to_game_value("12345")), "12345")
	to_big = saved
end

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
