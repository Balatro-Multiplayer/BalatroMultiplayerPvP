-- The Speedlatro layer keeps one local practice clock: it runs only with no lobby code and reports nothing.

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	end
end

local layers = {}
MPAPI = { Layer = function(key, fields) layers[key] = fields end }
PVP = { LOBBY = {}, GAME = {}, SP = { practice = true, playback_gamemode = nil } }
PVP.is_practice_mode = function() return PVP.SP.practice == true end
local layer_active = true
PVP.is_layer_active = function() return layer_active end

G = {
	STAGE = "run",
	STAGES = { RUN = "run" },
	STATE = "shop",
	STATES = { GAME_OVER = "over" },
	UIT = { ROOT = 1, R = 2, O = 3 },
	C = { CLEAR = {}, WHITE = {} },
	deck = {},
	P_BLINDS = { bl_small = "small", bl_big = "big", bl_mp_nemesis = "nemesis" },
	GAME = { round_resets = { blind = "small" }, blind = { get_type = function() return "Small" end } },
}
local removed = 0
UIBox = function() return { remove = function() removed = removed + 1 end } end
DynaText = function() return {} end
Game = {}
function Game:update() end
local rounds_started, rounds_ended = 0, 0
function new_round() rounds_started = rounds_started + 1 end
function end_round() rounds_ended = rounds_ended + 1 end

dofile("layers/speedlatro_timer.lua")
local clock = PVP.PracticeClock

-- Pure arithmetic.
check("layer keeps only the preview delay", layers.speedlatro_timer.preview_calculate_delay, 5)
check("layer has no speedup", layers.speedlatro_timer.timer_speedup_multiplier, nil)
check("tick", clock.tick(10, 0.5), 9.5)
check("tick clamps at 0", clock.tick(0.2, 1), 0)
check("small or big blind keeps the clock", clock.on_new_round(100, true), 100)
check("boss round starts on half", clock.on_new_round(100, false), 73.5)
check("beating a boss refills", clock.on_end_round(5, true), 147)
check("other rounds keep the clock", clock.on_end_round(5, false), 5)
check("display", clock.display(73.5), "73.50")
check("display under ten", clock.display(9.07), "9.07")

-- Outside a lobby the clock runs and ends the run at 0.
Game.update(Game, 1)
check("practice clock created", PVP.speedlatro_timer ~= nil, true)
check("practice clock ticks", PVP.speedlatro_timer.real, 146)
check("practice display", PVP.speedlatro_timer.display, "146.00")
G.GAME.round_resets.blind = "boss"
new_round()
check("boss round resets", PVP.speedlatro_timer.real, 73.5)
G.GAME.blind.get_type = function() return "Boss" end
end_round()
check("boss end refills", PVP.speedlatro_timer.real, 147)
check("round hooks chain", rounds_started == 1 and rounds_ended == 1, true)
PVP.speedlatro_timer.real = 0.5
Game.update(Game, 1)
check("run-out ends the practice run", G.STATE, "over")

-- A replay playback is practice-flagged with no lobby code, but it is not a practice run.
G.STATE = "shop"
PVP.speedlatro_timer = { real = 50, display = "50.00", text = UIBox() }
removed = 0
PVP.SP.playback_gamemode = "gamemode_mp_attrition"
Game.update(Game, 1000)
check("playback removes the practice box", removed, 1)
check("playback has no practice clock", PVP.speedlatro_timer, nil)
check("playback never ends the run", G.STATE, "shop")
PVP.SP.playback_gamemode = nil

-- In a lobby the server owns the clock: the layer removes its box and touches nothing.
PVP.SP.practice = false
G.STATE = "shop"
PVP.speedlatro_timer = { real = 50, display = "50.00", text = UIBox() }
removed = 0
PVP.LOBBY.code = "ABCD"
Game.update(Game, 1)
check("lobby removes the practice box", removed, 1)
check("lobby has no practice clock", PVP.speedlatro_timer, nil)
check("lobby never ends the run", G.STATE, "shop")
Game.update(Game, 1000)
check("lobby does not create a clock", PVP.speedlatro_timer, nil)
check("lobby does not end the run later", G.STATE, "shop")
check("lobby sends no timer value", PVP.GAME.timer, nil)
new_round()
end_round()
check("lobby hooks still chain", rounds_started == 2 and rounds_ended == 2, true)

if failures > 0 then
	os.exit(1)
end
