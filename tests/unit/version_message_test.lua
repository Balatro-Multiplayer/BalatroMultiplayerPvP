-- Plain Lua test: the version mismatch lines come out of the real en-us strings
-- through a localize that looks keys up the way the game does (a "variable" key in
-- misc.v_dictionary, a plain key in misc.dictionary).
-- Run from the repo root: luajit tests/unit/version_message_test.lua
PVP = {}
local en = dofile("localization/en-us.lua")
G = { localization = en }

local function fill(text, vars)
	return (text:gsub("#(%d+)#", function(n)
		return tostring(vars[tonumber(n)])
	end))
end

function localize(args, misc_type)
	if type(args) == "table" and args.type == "variable" then
		local text = G.localization.misc.v_dictionary[args.key]
		return text and fill(text, args.vars) or "ERROR"
	end
	local text = G.localization.misc[misc_type or "dictionary"][args]
	return text or "ERROR"
end

dofile("lib/version_gate.lua")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local line = PVP.VersionGate.message({ our = "1.0.3", their = "1.0.4" })
check(
	"mismatch line names both versions",
	line,
	"A player runs MultiplayerPvP 1.0.4, you run 1.0.3.\nEveryone in a game needs the same version."
)
check("refused line is found", PVP.VersionGate.refused_message() ~= "ERROR", true)

if failures > 0 then os.exit(1) end
