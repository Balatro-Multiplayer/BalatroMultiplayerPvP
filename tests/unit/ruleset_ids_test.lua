-- Run from the repo root: luajit tests/unit/ruleset_ids_test.lua
-- H2: the server's clock table (nakama/src/lobby/pvp/settings.ts, RULESET_CLOCKS) has one row per
-- PvP ruleset; a ruleset it does not know is refused `bad_rules` at the start. Both repos check
-- their own list against the same fixture, tests/fixtures/net-v1/ruleset_ids.json, a
-- byte-identical copy of the server's nakama/src/lobby/__fixtures__/net-v1/ruleset_ids.json.
-- Adding a ruleset means adding its id to both fixtures and a row to the server table.
local fixture = dofile("tests/unit/net_fixture.lua")

local FILES = {
	"badlatro",
	"balanced",
	"chaos",
	"expanded",
	"experimental/experimental",
	"experimental/experimental_legacy",
	"legacy_ranked",
	"majorleague",
	"minorleague",
	"release",
	"sandbox",
	"smallworld",
	"speedlatro",
	"traditional",
	"vanilla",
	"wsob",
}

local function read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

-- The keys this file registers with PVP.Ruleset, outside comments.
local function registered_keys(text)
	text = text:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
	local keys = {}
	for key in text:gmatch('PVP%.Ruleset%(%s*{%s*key%s*=%s*"([%w_]+)"') do
		keys[#keys + 1] = "ruleset_mp_" .. key
	end
	return keys
end

local failures = 0
local function check(name, ok, detail)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. (detail and (": " .. detail) or ""))
	end
end

-- Every ruleset file is in FILES, so a new one cannot be missed.
local listed = {}
for _, f in ipairs(FILES) do
	listed["rulesets/" .. f .. ".lua"] = true
end
local dir_cmd = package.config:sub(1, 1) == "\\" and 'dir /s /b rulesets\\*.lua' or "find rulesets -name '*.lua'"
local pipe = assert(io.popen(dir_cmd))
for line in pipe:lines() do
	local path = line:gsub("\\", "/"):gsub("^.*/rulesets/", "rulesets/")
	if not path:find("/_[^/]*%.lua$") then
		check("listed: " .. path, listed[path] == true, "add it to FILES")
	end
end
pipe:close()

local registered = {}
for _, f in ipairs(FILES) do
	for _, key in ipairs(registered_keys(read("rulesets/" .. f .. ".lua"))) do
		registered[#registered + 1] = key
	end
end
table.sort(registered)

local want = fixture("ruleset_ids")
check("fixture is a list", type(want) == "table" and #want > 0)
check(
	"registered ids equal the fixture",
	table.concat(registered, ",") == table.concat(want, ","),
	"\n  lua:     " .. table.concat(registered, ",") .. "\n  fixture: " .. table.concat(want, ",")
)

-- The comment strip: a block-commented registration (rulesets/release.lua) registers nothing.
check(
	"a commented-out registration is not counted",
	#registered_keys('--[[\nPVP.Ruleset({\n\tkey = "gone",\n})\n]]\nPVP.Ruleset({ key = "kept" })') == 1
)

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
