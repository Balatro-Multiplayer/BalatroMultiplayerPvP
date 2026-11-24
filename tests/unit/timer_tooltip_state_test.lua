-- Plain Lua test for PVP.READ.timer.tip (pvp_api/read/timer.lua): which hover hint the
-- timer box shows in each state.
-- Run from the repo root: luajit tests/unit/timer_tooltip_state_test.lua
PVP = { NET = {}, READ = {}, UI = {} }
dofile("pvp_api/read/timer.lua")
local reader = PVP.READ.timer
local Tip = reader.Tip

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

check("no time left", reader.tip(0, "mine", true, true), Tip.EXPIRED)
check("no clock shown is not run out", reader.tip(nil, "none", false, false), Tip.IDLE)
check("an opponent's clock runs on you", reader.tip(30, "against me", false, true), Tip.AGAINST_ME)
check("you can start their timer", reader.tip(30, "none", false, true), Tip.CAN_START)
check("you can pause the timer you started", reader.tip(30, "mine", true, true), Tip.CAN_PAUSE)
check("your timer runs and you cannot act", reader.tip(30, "mine", true, false), Tip.RUNNING)
check("nothing to do", reader.tip(30, "none", false, false), Tip.IDLE)
check("a press is blocked while a player is away", reader.tip(nil, "none", false, false, true), Tip.BLOCKED)
check("blocked yields to a clock running on you", reader.tip(30, "against me", false, false, true), Tip.AGAINST_ME)
check("blocked yields to a button that works", reader.tip(30, "mine", true, true, true), Tip.CAN_PAUSE)

local seen = {}
for _, value in pairs(Tip) do
	check("state " .. value .. " is unique", seen[value], nil)
	seen[value] = true
end

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
