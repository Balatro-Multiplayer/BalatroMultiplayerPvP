-- Parity fixture test for PVP.Score: every case in tests/fixtures/score_cases.json
-- must hold against lib/score.lua, and regenerating the fixture must give the
-- committed file byte for byte (a score.lua change forces a regeneration:
-- luajit tests/tools/gen_score_cases.lua).
-- Run from the repo root: luajit tests/unit/score_parity_test.lua
-- Needs the MPAPI repo next to this one (BalatroMultiplayerAPI/lib/big_score.lua).
MPAPI = {}
PVP = {}
dofile("../BalatroMultiplayerAPI/lib/big_score.lua")
dofile("lib/score.lua")
local gen = dofile("tests/tools/gen_score_cases.lua")

local FIXTURE = "tests/fixtures/score_cases.json"

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(tostring(name), tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local function read_file(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return (text:gsub("\r", ""))
end

-- A small JSON reader: null is gen.NULL, {"$num":...} is the number it names.
local function decode(text)
	local pos = 1
	local value

	local function skip()
		pos = text:find("[^ \t\r\n]", pos) or #text + 1
	end

	local function read_string()
		local out = {}
		pos = pos + 1
		while true do
			local ch = text:sub(pos, pos)
			if ch == '"' then
				pos = pos + 1
				return table.concat(out)
			elseif ch == "\\" then
				local esc = text:sub(pos + 1, pos + 1)
				if esc == "u" then
					out[#out + 1] = string.char(tonumber(text:sub(pos + 2, pos + 5), 16))
					pos = pos + 6
				else
					out[#out + 1] = ({ n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" })[esc] or esc
					pos = pos + 2
				end
			else
				assert(ch ~= "", "unterminated string")
				out[#out + 1] = ch
				pos = pos + 1
			end
		end
	end

	function value()
		skip()
		local ch = text:sub(pos, pos)
		if ch == '"' then return read_string() end
		if ch == "[" then
			local list, n = {}, 0
			pos = pos + 1
			skip()
			if text:sub(pos, pos) == "]" then
				pos = pos + 1
				return list
			end
			while true do
				n = n + 1
				list[n] = value()
				skip()
				local sep = text:sub(pos, pos)
				pos = pos + 1
				if sep == "]" then break end
				assert(sep == ",", "expected , or ] at " .. pos)
			end
			list.n = n
			return list
		end
		if ch == "{" then
			local object = {}
			pos = pos + 1
			skip()
			if text:sub(pos, pos) == "}" then
				pos = pos + 1
				return object
			end
			while true do
				skip()
				local key = read_string()
				skip()
				assert(text:sub(pos, pos) == ":", "expected : at " .. pos)
				pos = pos + 1
				object[key] = value()
				skip()
				local sep = text:sub(pos, pos)
				pos = pos + 1
				if sep == "}" then break end
				assert(sep == ",", "expected , or } at " .. pos)
			end
			local special = object["$num"]
			if special then return ({ inf = math.huge, ["-inf"] = -math.huge, nan = 0 / 0 })[special] end
			return object
		end
		for word, result in pairs({ ["true"] = true, ["false"] = false, ["null"] = gen.NULL }) do
			if text:sub(pos, pos + #word - 1) == word then
				pos = pos + #word
				return result
			end
		end
		local number = text:match("^-?[%d.eE+-]+", pos)
		assert(number, "bad JSON at " .. pos)
		pos = pos + #number
		return tonumber(number)
	end

	local result = value()
	skip()
	assert(pos > #text, "trailing JSON text")
	return result
end

-- A decoded null in the args is a nil to the function; every other value is as is.
local function unnull(args)
	local out = { n = args.n or #args }
	for i = 1, out.n do
		if args[i] ~= gen.NULL then out[i] = args[i] end
	end
	return out
end

local committed = read_file(FIXTURE)
check("regenerating gives the committed fixture byte for byte", gen.build() == committed, true)

local cases = decode(committed)
check("the fixture has at least 55 cases", #cases >= 55, true)
check("the fixture holds every generated case", #cases, gen.count)

local seen = {}
for _, c in ipairs(cases) do
	check("unique case name: " .. c.name, seen[c.name], nil)
	seen[c.name] = true
	check("side of " .. c.name, c.side == "server" or c.side == "client", true)
	local got = gen.call(c.fn, unnull(c.args))
	check(c.fn .. " | " .. c.name, gen.encode(got), gen.encode(c.out))
end

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all score parity cases passed")
