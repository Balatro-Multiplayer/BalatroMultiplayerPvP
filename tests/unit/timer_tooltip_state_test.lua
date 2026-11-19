-- Plain Lua test for PVP.UI.timer_tooltip_state (ui/game/timer.lua): which hover hint the
-- timer box shows in each state.
-- Run from the repo root: luajit tests/unit/timer_tooltip_state_test.lua
PVP = { UI = {}, GAME = {} }

-- timer.lua needs the whole game to load, so load just the state table and function.
local file = assert(io.open("ui/game/timer.lua", "r"))
local text = file:read("*a")
file:close()
local start = assert(text:find("PVP.UI.TimerTip = {", 1, true))
local _, finish = assert(text:find("function PVP.UI.timer_tooltip_state()", start, true))
local _, stop = assert(text:find("\nend\r?\n", finish))
assert((loadstring or load)(text:sub(start, stop)))()

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local can_act = false
function PVP.UI.cam_timer_opponent()
	return can_act
end

local Tip = PVP.UI.TimerTip
local function state(game, acts)
	PVP.GAME = game
	can_act = acts or false
	return PVP.UI.timer_tooltip_state()
end

check("no time left", state({ timer = 0, timer_started = true }, true), Tip.EXPIRED)
check("no timer value counts as run out", state({}), Tip.EXPIRED)
check("the opponent's timer runs for you", state({ timer = 30, nemesis_timer_started = true }, true), Tip.NEMESIS_RUNNING)
check("you can start their timer", state({ timer = 30 }, true), Tip.CAN_START)
check("you can pause the timer you started", state({ timer = 30, timer_started = true }, true), Tip.CAN_PAUSE)
check("your timer runs and you cannot act", state({ timer = 30, timer_started = true }), Tip.RUNNING)
check("nothing to do", state({ timer = 30 }), Tip.IDLE)

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
