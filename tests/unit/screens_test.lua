-- Run from the repo root: luajit tests/unit/screens_test.lua
-- pvp_api/ui/screens.lua: the screens tick in their listed order, one failing does not stop the rest, and a
-- repeated error is logged once.
local T = dofile("tests/support/check.lua")
local eq = T.eq

PVP = { READ = {}, UI = {}, NET = {} }
Game = { update = function() end }
sendWarnMessage = function() end
dofile("pvp_api/ui/screens.lua")
local screens = PVP.UI.screens

local order = table.concat(screens.order, ",")
eq(order, "away,blind_start,finish,pending_death,pvp_blind,reconnect,run,target,timer,trap", "the screens' order")
for i, name in ipairs(screens.order) do
	if name == "blind_start" then eq(screens.order[i + 3], "pvp_blind", "entry ticks before blind") end
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
PVP.NET.view = "the view"
PVP.READ.view = { follow_run = function(view) steps[#steps + 1] = "follow " .. view end }
PVP.UI.only = { update = function() steps[#steps + 1] = "screen" end }
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

T.done("screens_test")
