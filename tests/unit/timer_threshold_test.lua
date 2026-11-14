-- Run from the repo root: luajit tests/unit/timer_threshold_test.lua
-- lib/timer_threshold.lua: what the timer box text says under a ruleset's display threshold.
PVP = { UTILS = {} }
local threshold = 180
PVP.current_ruleset = function()
	return { timer_display_threshold = threshold }
end
dofile("lib/timer_threshold.lua")
local text = PVP.UTILS.timer_display_text

local failures = 0
local function check(name, got, want)
	if got == want then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": got " .. tostring(got) .. ", want " .. tostring(want))
	end
end

check("standing ante time above the threshold shows the threshold", text(400, false), "180")
check("running time above the threshold shows its own time", text(400, true), "400")
check("standing ante time under the threshold shows its own time", text(120, false), "120")
check("the PvP allowance above the threshold is not clamped", text(400, false, true), "400")
check("the PvP allowance under 10 shows tenths", text(9.5, false, true), "9.5")
threshold = 0
check("no threshold: the time as is", text(400, false), "400")

if failures > 0 then os.exit(1) end
print("all passed")
