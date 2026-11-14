-- Generates tests/fixtures/score_cases.json from the real lib/score.lua, so the
-- server's TypeScript port (lobby/pvp/score.ts) can be tested for parity.
-- Run from the repo root: luajit tests/tools/gen_score_cases.lua
-- Needs the MPAPI repo next to this one (BalatroMultiplayerAPI/lib/big_score.lua).
-- Loaded by tests/unit/score_parity_test.lua, which uses build(), encode() and
-- call() so the fixture cannot drift from lib/score.lua.
--
-- JSON conventions: a score is its score text string; a nil is null; a number
-- that JSON cannot hold (inf, nan) is {"$num":"inf"|"-inf"|"nan"}; a table
-- argument is a JSON object (the game values the number mods hand over).
-- Each case has a "side": "server" (the server ports it: parse, compare,
-- greater, equal, sum, from_game_value of a finite number) or "client" (display
-- and game-value plumbing the server does not port; rows kept for reference).
--
-- sum follows the no-number-mod rule on the server: once a total passes the double
-- range the largest score stands in. This differs from a Talisman client past
-- ~1e308; accepted.

-- The game's localize, as the key in angle brackets (display of an unknown score).
localize = localize or function(key)
	return "<" .. key .. ">"
end

MPAPI = MPAPI or {}
PVP = PVP or {}
if not PVP.Score then
	dofile("../BalatroMultiplayerAPI/lib/big_score.lua")
	dofile("lib/score.lua")
end

local M = {}

local NULL = {}
M.NULL = NULL
local OBJ = {}

local function obj(t)
	return setmetatable(t, OBJ)
end

local function encode_number(n)
	if n ~= n then return '{"$num":"nan"}' end
	if n == math.huge then return '{"$num":"inf"}' end
	if n == -math.huge then return '{"$num":"-inf"}' end
	if n == math.floor(n) and math.abs(n) < 1e15 then return string.format("%.0f", n) end
	return string.format("%.17g", n)
end

local function encode_string(s)
	return '"'
		.. s:gsub('[%c"\\]', function(ch)
			if ch == '"' then return '\\"' end
			if ch == "\\" then return "\\\\" end
			return string.format("\\u%04x", ch:byte())
		end)
		.. '"'
end

local function encode(v)
	local kind = type(v)
	if v == nil or v == NULL then return "null" end
	if kind == "boolean" then return v and "true" or "false" end
	if kind == "number" then return encode_number(v) end
	if kind == "string" then return encode_string(v) end
	local parts = {}
	if getmetatable(v) == OBJ then
		local keys = {}
		for k in pairs(v) do
			keys[#keys + 1] = k
		end
		table.sort(keys)
		for _, k in ipairs(keys) do
			parts[#parts + 1] = encode_string(k) .. ":" .. encode(v[k])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	for i = 1, v.n or #v do
		parts[i] = encode(v[i])
	end
	return "[" .. table.concat(parts, ",") .. "]"
end
M.encode = encode

-- Runs one case: S[fn](args...) with args a table carrying its length in n.
function M.call(fn, args)
	return PVP.Score[fn](unpack(args, 1, args.n))
end

local cases = {}

local function case(name, fn, ...)
	cases[#cases + 1] = { name = name, fn = fn, args = { n = select("#", ...), ... } }
end

-- Score text, with the cases named by the branch of score.lua / big_score.lua they cover.
-- parse: non-string, malformed text, normalize
case("parse: number is not score text", "parse", 5)
case("parse: nil", "parse", nil)
case("parse: table", "parse", obj({ array = { 5 } }))
case("parse: plain", "parse", "12345")
case("parse: zero", "parse", "0")
case("parse: empty", "parse", "")
case("parse: garbage", "parse", "abc")
case("parse: talisman e-notation text is not score text", "parse", "1.2e20")
case("parse: negative", "parse", "-5")
case("parse: leading zero", "parse", "007")
case("parse: bare zero-zero", "parse", "00")
case("parse: decimal floors", "parse", "1.5")
case("parse: trailing dot", "parse", "1.")
case("parse: leading dot", "parse", ".5")
case("parse: surrounding space", "parse", " 5 ")
case("parse: empty entry", "parse", "1,,2")
case("parse: decimal in a higher entry", "parse", "1,2.5")
case("parse: trailing comma", "parse", "5,")
case("parse: exponent text 10^100", "parse", "100,1")
case("parse: tower text", "parse", "20,2")
case("parse: comma groups read as an array", "parse", "1,234,567")
case("parse: zero entries trimmed", "parse", "0,0")
case("parse: trailing zero entry trimmed", "parse", "1.5,0")
case("parse: low first entry with a tower folds down", "parse", "5,1")
case("parse: first entry past the safe integer", "parse", "9007199254740992")
case("parse: twenty digit number", "parse", "99999999999999999999")
case("parse: zero second entry with a third", "parse", "5,0,3")
case("parse: higher entry past the safe integer", "parse", "1,9007199254740992")
case("parse: text past the length limit", "parse", string.rep("1", 4097))
case("parse: 101 entries refused", "parse", string.rep("1,", 100) .. "1")
case("parse: 100 entries kept", "parse", string.rep("1,", 99) .. "1")
case("parse: non-ascii digits", "parse", "\xef\xbc\x91\xef\xbc\x92")

-- compare: an unknown score (nil or malformed) ranks below every score, zero included

-- compare, greater, equal
case("compare: 10 over 9, not text order", "compare", "10", "9")
case("compare: 9 under 10", "compare", "9", "10")
case("compare: same plain", "compare", "5", "5")
case("compare: equal different spellings", "compare", "5.9", "5")
case("compare: equal after flooring", "compare", "1000", "1000.9")
case("compare: exponent over a plain score", "compare", "100,1", "999999999999999")
case("compare: tower over an exponent", "compare", "20,2", "100,1")
case("compare: exponent under a tower", "compare", "100,1", "20,2")
case("compare: same exponent", "compare", "100,1", "100,1")
case("compare: lower exponent", "compare", "100,1", "101,1")
case("compare: higher second entry wins", "compare", "100,2", "100,1")
case("compare: longer array wins", "compare", "20,9,9", "20,9")
case("compare: nil and nil", "compare", nil, nil)
case("compare: score over nil", "compare", "1", nil)
case("compare: nil under score", "compare", nil, "1")
case("compare: garbage ranks below zero", "compare", "abc", "0")
case("compare: e-notation text ranks below zero", "compare", "1e5", "0")
case("compare: empty ranks below zero", "compare", "", "0")
case("compare: number ranks below zero", "compare", 5, "0")
case("compare: comma groups read as an array", "compare", "1,234,567", "5")
case("greater: zero is not greater than zero", "greater", "0", "0")
case("greater: plain over zero", "greater", "5", "0")
case("greater: score over malformed", "greater", "1", "banana")
case("equal: zero and zero", "equal", "0", "0")
case("equal: spellings", "equal", "5.9", "5")
case("equal: nil and zero", "equal", nil, "0")
case("equal: nil and nil", "equal", nil, nil)
case("greater: zero over nil", "greater", "0", nil)
case("equal: different", "equal", "5", "6")

-- display (Balatro notation)
case("display: zero", "display", "0")
case("display: nil", "display", nil)
case("display: garbage", "display", "abc")
case("display: comma groups", "display", "1234567")
case("display: one below the switch point", "display", "99999999999")
case("display: the switch point", "display", "100000000000")
case("display: mantissa rounds up to the next exponent", "display", "999950000000")
case("display: mantissa rounds half up", "display", "123450000000")
case("display: trailing zeros trimmed", "display", "120000000000")
case("display: big plain score", "display", "999999999999999")
case("display: 10^100", "display", "100,1")
case("display: 20,1", "display", "20,1")
case("display: first entry past 1e6, one tower", "display", "1000000,1")
case("display: first entry past 1e6 rounds up", "display", "9999999,1")
case("display: tower 10^10^20", "display", "20,2")
case("display: three tower", "display", "50,3")
case("display: eight tower", "display", "20,8")
case("display: nine tower, long form", "display", "20,9")
case("display: fractional first entry under 10", "display", "12.34,9")
case("display: fractional first entry under 100", "display", "50.5,9")
case("display: fractional first entry over 100", "display", "150.25,9")
case("display: entry past 1e6 in an exponent", "display", "20000000,9")
case("display: three entries", "display", "20,9,9")
case("display: seven entries", "display", "20,9,9,9,9,9,9")
case("display: eight entries", "display", "20,9,9,9,9,9,9,9")
case("display: top score", "display", string.rep("9007199254740991,", 99) .. "9007199254740991")

-- small_number (G is nil, so the switch point is 100000000000)
case("small_number: small", "small_number", "42")
case("small_number: zero", "small_number", "0")
case("small_number: nil", "small_number", nil)
case("small_number: garbage", "small_number", "abc")
case("small_number: exponent", "small_number", "100,1")
case("small_number: comma text", "small_number", "1,234,567")
case("small_number: just below the switch point", "small_number", "99999999999")
case("small_number: the switch point", "small_number", "100000000000")
case("small_number: floors a decimal", "small_number", "12.9")

-- from_game_value: numbers, strings, number-mod tables
case("from_game_value: zero", "from_game_value", 0)
case("from_game_value: double", "from_game_value", 1234)
case("from_game_value: below one", "from_game_value", 0.5)
case("from_game_value: negative", "from_game_value", -5)
case("from_game_value: fraction floors", "from_game_value", 123456789.9)
case("from_game_value: 1e15", "from_game_value", 1e15)
case("from_game_value: 1e20", "from_game_value", 1.5e20)
case("from_game_value: largest double", "from_game_value", 1.7976931348623157e308)
case("from_game_value: infinity", "from_game_value", math.huge)
case("from_game_value: negative infinity", "from_game_value", -math.huge)
case("from_game_value: nan", "from_game_value", 0 / 0)
case("from_game_value: nil", "from_game_value", nil)
case("from_game_value: boolean", "from_game_value", true)
case("from_game_value: score text", "from_game_value", "1234")
case("from_game_value: comma text", "from_game_value", "1,234,567")
case("from_game_value: exponent text", "from_game_value", "100,1")
case("from_game_value: inf word", "from_game_value", "inf")
case("from_game_value: padded NaN word", "from_game_value", " NaN ")
case("from_game_value: naneinf word", "from_game_value", "naneinf")
case("from_game_value: infinity word", "from_game_value", "Infinity")
case("from_game_value: e-notation text read as a number", "from_game_value", "1e20")
case("from_game_value: small e-notation text", "from_game_value", "1e5")
case("from_game_value: padded number text", "from_game_value", " 42 ")
case("from_game_value: negative text", "from_game_value", "-5")
case("from_game_value: hex text (Lua tonumber)", "from_game_value", "0x10")
case("from_game_value: garbage", "from_game_value", "abc")
case("from_game_value: empty", "from_game_value", "")
case("from_game_value: OmegaNum plain", "from_game_value", obj({ array = { 1234 }, sign = 1 }))
case("from_game_value: OmegaNum past 1e308", "from_game_value", obj({ array = { 400, 1 }, sign = 1 }))
case("from_game_value: OmegaNum negative", "from_game_value", obj({ array = { 5 }, sign = -1 }))
case("from_game_value: OmegaNum no sign", "from_game_value", obj({ array = { 7 } }))
case("from_game_value: OmegaNum empty array", "from_game_value", obj({ array = {} }))
case("from_game_value: OmegaNum zero", "from_game_value", obj({ array = { 0 }, sign = 1 }))
case("from_game_value: OmegaNum tower", "from_game_value", obj({ array = { 20, 2 }, sign = 1 }))
case("from_game_value: OmegaNum nan entry", "from_game_value", obj({ array = { 0 / 0 }, sign = 1 }))
case("from_game_value: OmegaNum infinite entry", "from_game_value", obj({ array = { 5, math.huge }, sign = 1 }))
case(
	"from_game_value: OmegaNum 101 entries",
	"from_game_value",
	obj({ array = (function()
		local t = {}
		for i = 1, 101 do
			t[i] = 1
		end
		return t
	end)(), sign = 1 })
)
case("from_game_value: BigNum small", "from_game_value", obj({ m = 5, e = 3 }))
case("from_game_value: BigNum large", "from_game_value", obj({ m = 1.5, e = 20 }))
case("from_game_value: BigNum zero mantissa", "from_game_value", obj({ m = 0, e = 5 }))
case("from_game_value: BigNum infinite exponent", "from_game_value", obj({ m = 1, e = math.huge }))
case("from_game_value: BigNum nan mantissa", "from_game_value", obj({ m = 0 / 0, e = 1 }))
case("from_game_value: empty table", "from_game_value", obj({}))
case("from_game_value: table of text", "from_game_value", obj({ array = "5" }))

-- sum: the server adopts the no-number-mod rule (doubles; once a total passes the
-- double range, or a score is not a plain number, the largest score stands in).
-- This differs from a Talisman client past ~1e308; accepted.
case("sum: empty", "sum", {})
case("sum: one", "sum", { "7" })
case("sum: two", "sum", { "1", "2" })
case("sum: four", "sum", { "10", "20", "30", "40" })
case("sum: zero", "sum", { "0" })
case("sum: a malformed score makes the sum unknown", "sum", { "5", "abc" })
case("sum: only malformed", "sum", { "x", "y" })
case("sum: exponent beside a plain score stands in", "sum", { "100,1", "5" })
case("sum: two exponent scores, the largest stands in", "sum", { "100,1", "200,1" })
case("sum: equal exponent scores stand in as one", "sum", { "100,1", "100,1" })
case("sum: tower beats exponent", "sum", { "100,1", "20,2" })
case("sum: comma text is not a plain number", "sum", { "1,234,567", "5" })
case("sum: total above 1e15, below 2^53", "sum", { "999999999999999", "999999999999999" })
case("sum: two safe maximums", "sum", { "9007199254740991", "9007199254740991" })
case("sum: decimals floor before adding", "sum", { "1.9", "2.9" })

local SERVER_FNS = { parse = true, compare = true, greater = true, equal = true, sum = true }

local function side(c)
	if SERVER_FNS[c.fn] then return "server" end
	local arg = c.args[1]
	if c.fn == "from_game_value" and type(arg) == "number" and arg == arg and math.abs(arg) ~= math.huge then
		return "server"
	end
	return "client"
end

local function case_json(c)
	return '{"args":'
		.. encode(c.args)
		.. ',"fn":'
		.. encode_string(c.fn)
		.. ',"name":'
		.. encode_string(c.name)
		.. ',"out":'
		.. encode(M.call(c.fn, c.args))
		.. ',"side":'
		.. encode_string(side(c))
		.. "}"
end

-- The whole fixture file text, one case per line.
function M.build()
	local lines = {}
	for i, c in ipairs(cases) do
		lines[i] = "\t" .. case_json(c)
	end
	return "[\n" .. table.concat(lines, ",\n") .. "\n]\n"
end

M.count = #cases

if arg and arg[0] and arg[0]:find("gen_score_cases", 1, true) then
	local file = assert(io.open("tests/fixtures/score_cases.json", "wb"))
	file:write(M.build())
	file:close()
	print(("wrote tests/fixtures/score_cases.json (%d cases)"):format(#cases))
end

return M
