-- Run from the repo root: luajit tests/unit/blind_result_test.lua
-- PVP.ACTIONS.blind_result (networking/action_handlers.lua) sends a blind result through the run screen.
local results = {}
G = { GAME = { blind_on_deck = "Small" } }
PVP = {
	ACTIONS = {},
	run_screen = { blind_result = function(...) results[#results + 1] = { ... } end },
	GAME = {},
}
MPAPI = { get_current_lobby = function() return {} end }

-- action_handlers.lua needs the whole game to load, so load just the one function from it.
local function load_function(header)
	local file = assert(io.open("networking/action_handlers.lua", "r"))
	local text = file:read("*a")
	file:close()
	local start = assert(text:find(header, 1, true), "function not found: " .. header)
	local _, finish = text:find("\nend\r?\n", start)
	assert((loadstring or load)(text:sub(start, finish)))()
end
load_function("function PVP.ACTIONS.blind_result(")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

PVP.ACTIONS.blind_result("beaten", "Small")
check("a named blind result is sent", #results, 1)
check("it carries the named blind", results[1][1], "Small")
check("it carries the result", results[1][2], "beaten")

PVP.ACTIONS.blind_result("lost")
check("the blind on deck is used when none is named", results[2][1], "Small")

MPAPI.get_current_lobby = function() return nil end
PVP.ACTIONS.blind_result("lost")
check("nothing is sent outside a lobby", #results, 2)

if failures > 0 then os.exit(1) end
