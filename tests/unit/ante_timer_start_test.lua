-- Plain Lua test for the waiting side's start of the Ante timer (networking/action_handlers.lua):
-- a second start while its own timer runs is dropped in code, not only hidden in the UI.
-- Run from the repo root: luajit tests/unit/ante_timer_start_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

-- action_handlers.lua needs the whole game to load, so load just these two functions from it.
local function slice(text, header)
	local start = assert(text:find(header, 1, true), "function not found: " .. header)
	local _, finish = text:find("\nend\r?\n", start)
	return text:sub(start, finish)
end
local file = assert(io.open("networking/action_handlers.lua", "r"))
local text = file:read("*a")
file:close()
local chunk = slice(text, "local function action_start_ante_timer(p)")
	.. slice(text, "function PVP.ACTIONS.start_ante_timer()")
	.. "return action_start_ante_timer\n"

local sent, state
local function setup(timer_started)
	sent = {}
	state = {}
	G = {
		GAME = { round_resets = { ante = 1 }, current_round = { hands_left = 4 } },
		SETTINGS = { GAMESPEED = 1 },
		E_MANAGER = { add_event = function() end },
	}
	Event = function(t) return t end
	Client = { send = function(msg) sent[#sent + 1] = msg end }
	PVP = {
		config = { timersfx = 3 },
		GAME = { timer = 90, timer_started = timer_started, nemesis_timer_started = false },
		UTILS = {
			timer_start_held_back = function() return false end,
		},
		ACTIONS = {},
		timer_is_local = function() return false end,
		is_pvp_boss = function() return false end,
		is_layer_active = function() return false end,
	}
	local handler = assert((loadstring or load)(chunk))()
	PVP.ACTIONS.announce_ante_timer = function(time) sent[#sent + 1] = { action = "startAnteTimer", time = time } end
	return handler
end

local handler = setup(false)
handler({ time = 90, fromNemesis = false })
check("first start sets the timer flag", PVP.GAME.timer_started, true)

handler = setup(true)
PVP.GAME.timer = 40
handler({ time = 90, fromNemesis = false })
check("second own start leaves the timer alone", PVP.GAME.timer, 40)

setup(true)
PVP.ACTIONS.start_ante_timer()
check("second own start broadcasts nothing", #sent, 0)

setup(false)
PVP.ACTIONS.start_ante_timer()
check("first own start broadcasts", #sent, 1)
check("first own start sets the flag", PVP.GAME.timer_started, true)

handler = setup(true)
handler({ time = 55, fromNemesis = true })
check("the opponent's start still arrives", PVP.GAME.nemesis_timer_started, true)

if failures > 0 then
	os.exit(1)
end
