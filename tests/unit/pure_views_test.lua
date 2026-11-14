-- Run from the repo root: luajit tests/unit/pure_views_test.lua
-- Every lib/*_view.lua is pure (see NET.md): it must not touch the game or engine
-- globals. This scans the code of each view, with comments and strings removed.

-- Names that may not appear as a bare identifier (a field such as `t.os` is fine).
local FORBIDDEN_NAMES = {
	"G",
	"_G",
	"MPAPI",
	"love",
	"os",
	"io",
	"SMODS",
	"localize",
	"rawget",
	"getfenv",
	"setfenv",
	"require",
	"dofile",
	"loadstring",
}

-- The text with comments and string literals blanked out (newlines kept).
local function strip(text)
	local out = {}
	local i, n = 1, #text
	while i <= n do
		local c = text:sub(i, i)
		if text:sub(i, i + 1) == "--" then
			local eq = text:match("^%-%-%[(=*)%[", i)
			if eq then
				local _, close = text:find("]" .. eq .. "]", i, true)
				i = (close or n) + 1
			else
				i = (text:find("\n", i, true) or n + 1)
			end
		elseif c == '"' or c == "'" then
			local j = i + 1
			while j <= n do
				local d = text:sub(j, j)
				if d == "\\" then
					j = j + 2
				elseif d == c or d == "\n" then
					break
				else
					j = j + 1
				end
			end
			out[#out + 1] = '""'
			i = j + 1
		elseif c == "[" and text:match("^%[=*%[", i) then
			local eq = text:match("^%[(=*)%[", i)
			local _, close = text:find("]" .. eq .. "]", i, true)
			out[#out + 1] = '""'
			i = (close or n) + 1
		else
			out[#out + 1] = c
			i = i + 1
		end
	end
	return table.concat(out)
end

-- Whether the name starting at `pos` is a field or method (`t.name`, `t:name`, not `a..name`).
local function is_member(code, pos)
	local before = code:sub(1, pos - 1):match("(%.?[%.:]?)%s*$") or ""
	if before:sub(-1) == ":" then return true end
	return before:sub(-1) == "." and before:sub(-2, -2) ~= "."
end

-- Every whole-word use of `name` that is not a field access, as a count.
local function bare_uses(code, name)
	local count, init = 0, 1
	local pattern = "%f[%w_]" .. name .. "%f[^%w_]"
	while true do
		local pos = code:find(pattern, init)
		if not pos then return count end
		if not is_member(code, pos) then count = count + 1 end
		init = pos + #name
	end
end

-- PVP.<member> where the member is not CamelCase (PVP.GAME, PVP.match_log are state
-- or shell; PVP.ReadyView, PVP.Score are pure libraries).
local function impure_pvp_member(code)
	local init = 1
	while true do
		local pos, stop, member = code:find("%f[%w_]PVP%s*%.%s*([%a_][%w_]*)", init)
		if not pos then return nil end
		if not is_member(code, pos) and (member:find("^[^A-Z]") or not member:find("[a-z]")) then
			return "PVP." .. member
		end
		init = stop + 1
	end
end

-- The forbidden names found in the code of `text`, as a list.
local function violations(text)
	local code = strip(text)
	local found = {}
	for _, name in ipairs(FORBIDDEN_NAMES) do
		if bare_uses(code, name) > 0 then found[#found + 1] = name end
	end
	if code:find("%f[%w_]math%s*%.%s*random%f[^%w_]") then found[#found + 1] = "math.random" end
	local pvp = impure_pvp_member(code)
	if pvp then found[#found + 1] = pvp end
	return found
end

local passed, failed = 0, 0
local function check(name, got, want)
	if got == want then
		passed = passed + 1
		print("ok   " .. name)
	else
		failed = failed + 1
		print(("FAIL %s: got %s, wanted %s"):format(name, tostring(got), tostring(want)))
	end
end

-- The scanner itself, on planted text: [name, text, expected first hit (nil = clean)].
local cases = {
	{ "G.GAME", "local x = G.GAME.round", "G" },
	{ "G[ index", "local x = G['GAME']", "G" },
	{ "G aliased", "local g = G", "G" },
	{ "G as an argument", "f(G)", "G" },
	{ "G method call", "G:save()", "G" },
	{ "_G index", "local x = _G['a']", "_G" },
	{ "G after concat", 'local s = "a"..G.x', "G" },
	{ "MPAPI", "MPAPI.request('a')", "MPAPI" },
	{ "love", "love.timer.getTime()", "love" },
	{ "os", "local t = os.time()", "os" },
	{ "io", "local f = io.open('a')", "io" },
	{ "SMODS", "SMODS.Joker({})", "SMODS" },
	{ "math.random", "local r = math.random(3)", "math.random" },
	{ "rawget", "local v = rawget(t, 1)", "rawget" },
	{ "getfenv", "local e = getfenv(1)", "getfenv" },
	{ "setfenv", "setfenv(1, {})", "setfenv" },
	{ "require", "local m = require('x')", "require" },
	{ "dofile", "dofile('x.lua')", "dofile" },
	{ "loadstring", "loadstring('x')()", "loadstring" },
	{ "PVP.GAME", "local g = PVP.GAME", "PVP.GAME" },
	{ "PVP.LOBBY", "local g = PVP.LOBBY", "PVP.LOBBY" },
	{ "PVP.ACTIONS", "PVP.ACTIONS.go()", "PVP.ACTIONS" },
	{ "PVP.HANDLERS", "PVP.HANDLERS.go()", "PVP.HANDLERS" },
	{ "PVP.match_log", "PVP.match_log('debug', 'x')", "PVP.match_log" },
	{ "PVP.config", "local c = PVP.config.x", "PVP.config" },
	{ "PVP.UTILS", "PVP.UTILS.clocks_of()", "PVP.UTILS" },
	{ "PVP.current_run_id", "local r = PVP.current_run_id()", "PVP.current_run_id" },
	{ "localize", "local s = localize('k_x')", "localize" },
	{ "code after a comment", "-- note\nlocal x = G.GAME", "G" },
	{ "code after a string", 'local s = "a" .. G.GAME', "G" },
	-- Not caught.
	{ "clean code", "local t = {}\nfunction t.go(a) return a + 1 end", nil },
	{ "names that merely contain G", "local BIG = 1\nlocal x = BIG.y\nlocal pos = 1", nil },
	{ "field named os", "local x = self.os.x", nil },
	{ "field named G", "local z = t.G.z", nil },
	{ "method named G", "t:G()", nil },
	{ "field named require", "local f = t.require", nil },
	{ "field named io", "local f = t.io", nil },
	{ "field named localize", "local f = t.localize", nil },
	{ "math.floor", "local r = math.floor(3.5)", nil },
	{ "PVP.ReadyView", "PVP.ReadyView = {}\nlocal ReadyView = PVP.ReadyView", nil },
	{ "PVP.Score", "local s = PVP.Score.total(1)", nil },
	{ "PVP.PendingDeath", "local s = PVP.PendingDeath.new()", nil },
	{ "bare PVP table", "PVP = {}", nil },
	{ "line comment", "local a = 1 -- reads G.GAME", nil },
	{ "block comment", "--[[ G.GAME\nMPAPI ]] local a = 1", nil },
	{ "leveled block comment", "--[==[ os.time() ]==] local a = 1", nil },
	{ "string literal", "local s = \"G.GAME\" .. 'MPAPI'", nil },
	{ "escaped quote in a string", 'local s = "a\\"G.GAME"', nil },
	{ "long string", "local s = [[ G.GAME ]]", nil },
}
for _, case in ipairs(cases) do
	check("planted " .. case[1] .. (case[3] and " is caught" or " is not caught"), violations(case[2])[1], case[3])
end

-- Every real view.
local windows = package.config:sub(1, 1) == "\\"
local listing = assert(io.popen(windows and 'dir /b "lib\\*_view.lua"' or "ls lib/*_view.lua"))
local files = {}
for line in listing:lines() do
	local name = line:match("([^/\\]+_view%.lua)%s*$")
	if name then files[#files + 1] = "lib/" .. name end
end
listing:close()
-- Pure rule modules that are not named *_view.lua.
files[#files + 1] = "lib/applied_effects.lua"
files[#files + 1] = "lib/_state_value.lua"
files[#files + 1] = "lib/round_facts.lua"
table.sort(files)
check("found the view files", #files > 0, true)
for _, path in ipairs(files) do
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	local found = violations(text)
	check(path .. " is pure" .. (#found > 0 and (" (uses " .. table.concat(found, ", ") .. ")") or ""), #found, 0)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
