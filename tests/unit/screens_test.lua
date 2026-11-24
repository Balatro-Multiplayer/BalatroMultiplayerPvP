-- Run from the repo root: luajit tests/unit/screens_test.lua
-- pvp_api/screens.lua: the screens tick in their listed order, one failing does not stop the rest, and a
-- repeated error is logged once.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

PVP = { match_net = {} }
Game = { update = function() end }
sendWarnMessage = function() end
dofile("pvp_api/screens.lua")
local screens = PVP.match_net.screens

local order = table.concat(screens.order, ",")
eq(order, "away_screen,entry_screen,finish_screen,pending_death_screen,pvp_blind_screen,reconnect_screen,run_screen,target_screen,timer_screen,trap_screen", "the screens' order")
for i, name in ipairs(screens.order) do
	if name == "entry_screen" then eq(screens.order[i + 3], "pvp_blind_screen", "entry ticks before blind") end
end

local ran, logs = {}, {}
local modules = {
	a = { update = function() ran[#ran + 1] = "a" end },
	b = { update = function() error("boom") end },
	c = { update = function() ran[#ran + 1] = "c" end },
}
local function log(text) logs[#logs + 1] = text end
screens.tick({ "a", "b", "c" }, modules, log)
eq(table.concat(ran, ","), "a,c", "listed order, and a failing screen does not stop the next")
eq(#logs, 1, "the failure is logged")
screens.tick({ "a", "b", "c" }, modules, log)
eq(#logs, 1, "the same error again is not logged again")
modules.b.update = function() error("another") end
screens.tick({ "a", "b", "c" }, modules, log)
eq(#logs, 2, "another error is logged")

-- Each frame a new run clears the marks before any screen runs.
local steps = {}
PVP.match_net.view = "the view"
PVP.view = { follow_run = function(view) steps[#steps + 1] = "follow " .. view end }
PVP.only = { update = function() steps[#steps + 1] = "screen" end }
local listed = screens.order
screens.order = { "only" }
Game:update(0)
screens.order = listed
eq(table.concat(steps, ","), "follow the view,screen", "the run is followed before the screens")

-- No screen clears its own marks per run: that is follow_run's job.
local files = io.popen("git ls-files pvp_api")
for path in files:lines() do
	if path:match("%.lua$") and not path:match("_view%.lua$") then
		local text = io.open(path):read("*a")
		eq(text:match("changed%(\"[^\"]* run\"") == nil, true, path .. " has no run reset of its own")
	end
end
files:close()

print("screens_test: ok (" .. checks .. " checks)")
