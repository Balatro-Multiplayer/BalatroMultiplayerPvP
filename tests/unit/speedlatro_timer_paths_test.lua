-- Run from the repo root: luajit tests/unit/speedlatro_timer_paths_test.lua
-- The Speedlatro/Chaos clock has two paths. No lobby (singleplayer): the layer ticks its own seconds,
-- refills them and ends the run at zero, as before. In a lobby: it shows the server's personal
-- countdown and ticks, refills and ends nothing.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local lobby_code, personal, clock_state, pvp_boss = nil, nil, "none", false
local removed = 0

MPAPI = { Layer = function() end }
Game = { update = function() end }
new_round = function() end
end_round = function() end
function localize(key) return key end
function UIBox() return { remove = function() removed = removed + 1 end } end
function DynaText() return { colours = {} } end
G = {
	STAGE = 1,
	STAGES = { RUN = 1 },
	STATE = 0,
	STATES = { GAME_OVER = 9 },
	UIT = {},
	C = { CLEAR = "clear", WHITE = "white" },
	CONTROLLER = { locks = {} },
	FUNCS = {},
	GAME = { chips = 0, round_resets = { blind = "boss" }, blind = { get_type = function() return "Boss" end } },
	P_BLINDS = { bl_small = "small", bl_big = "big" },
}
SMODS = { Gradients = { mp_speedlatro_timer_accelerated = "gradient" } }
PVP = {
	NET = {}, READ = {},
	LOBBY = {},
	GAME = { enemy = { score = 0 } },
	SCORE = { from_game_value = function(v) return v end, greater = function() return false end },
	RULES = {
		is_layer_active = function() return true end,
		current = function() return { timer_speedup_multiplier = 2 } end,
	},
	UTILS = { is_pvp_blind = function() return pvp_boss end },
	UI = { timer = {
		clock = function() return clock_state end,
		personal = function() return personal end,
	} },
}
dofile("pvp_api/read/timer.lua")
dofile("layers/speedlatro_timer.lua")

local function reset(code)
	PVP.LOBBY.code = code
	PVP.UI.speedlatro_timer = nil
	G.STATE = 0
	personal, clock_state, pvp_boss = nil, "none", false
end

-- No lobby: local tick, 2x while timed, refills, run-out ends the run.
reset(nil)
Game:update(1)
eq(PVP.UI.speedlatro_timer.real, 146, "no lobby: ticks 1 s per second")
eq(PVP.UI.speedlatro_timer.display, "146.00", "no lobby: shows the local seconds")
clock_state = "against me"
Game:update(1)
eq(PVP.UI.speedlatro_timer.real, 144, "no lobby: 2x while timed")
G.FUNCS.mp_update_speedlatro_timer({ config = { object = { colours = {} } } })
local object = { colours = {} }
G.FUNCS.mp_update_speedlatro_timer({ config = { object = object } })
eq(object.colours[1], "gradient", "no lobby: accelerated colour while timed")
clock_state = "none"
new_round()
eq(PVP.UI.speedlatro_timer.real, 73.5, "no lobby: a blind refills to half")
end_round()
eq(PVP.UI.speedlatro_timer.real, 147, "no lobby: a Boss refills to the full base")
PVP.UI.speedlatro_timer.real = 0.5
Game:update(1)
eq(PVP.UI.speedlatro_timer.real, 0, "no lobby: stops at zero")
eq(G.STATE, G.STATES.GAME_OVER, "no lobby: zero ends the run")

-- In a lobby: shows the server's countdown, ticks and ends nothing.
reset("ABCD")
personal = { seconds = 80, rate = 2, clock = "running" }
Game:update(1)
eq(PVP.UI.speedlatro_timer.display, "80.00", "lobby: shows the personal countdown")
local before = PVP.UI.speedlatro_timer.real
Game:update(5)
eq(PVP.UI.speedlatro_timer.real, before, "lobby: no local tick")
new_round()
end_round()
eq(PVP.UI.speedlatro_timer.real, before, "lobby: no local refill")
personal = { seconds = 0, rate = 2, clock = "running" }
Game:update(1)
eq(G.STATE, 0, "lobby: a run-out ends nothing here")
personal = nil
Game:update(1)
eq(PVP.UI.speedlatro_timer.display, "k_timer_none", "lobby: no countdown in the view shows the none text, not 0.00")
personal = { seconds = 80, rate = 2, clock = "running" }
object = { colours = {} }
G.FUNCS.mp_update_speedlatro_timer({ config = { object = object } })
eq(object.colours[1], "gradient", "lobby: accelerated colour from the rate")
personal = { seconds = 80, rate = 1, clock = "running" }
G.FUNCS.mp_update_speedlatro_timer({ config = { object = object } })
eq(object.colours[1], "white", "lobby: no gradient at rate 1")

-- The box pulses only while I am timed or timing (main: timer_started or nemesis_timer_started),
-- never for a personal clock alone; the gradient's own-clock path is "I am timing".
local file = assert(io.open("ui/game/timer.lua", "r"))
local ui_text = file:read("*a")
file:close()
local box = ui_text:match("function G%.FUNCS%.set_timer_box%(e%)(.-)\nend")
T.checks = T.checks + 1
assert(box and box:find("if PVP.UI.timer.timed() then", 1, true), "set_timer_box does not pulse on timed()")
T.checks = T.checks + 1
assert(not box:find("personal_runs", 1, true), "set_timer_box still pulses for a personal clock alone")
T.checks = T.checks + 1
assert(ui_text:find('local own_clock = PVP.UI.timer.timing()', 1, true), "the pulse gradient does not use timing()")

T.done("speedlatro_timer_paths_test")
