-- Plain Lua test for PVP.UI.update_matching_skip_timer (ui/game/timer.lua): the old timer's
-- skip time follows how far ahead of the opponent a player has skipped since the last PvP.
-- The function is cut out of timer.lua because the rest of the file needs the game.
-- Run from the repo root: luajit tests/unit/matching_skip_timer_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local src = io.open("ui/game/timer.lua"):read("*a")
local s = src:find("function PVP.UI.update_matching_skip_timer", 1, true)
local _, e = src:find("\r?\nend\r?\n", s)
local chunk = src:sub(s, e)

local function setup(cfg)
	PVP = {
		UI = {},
		LOBBY = { config = { timer = true, timer_increment_seconds = 60 } },
		GAME = { timer = 150, enemy = {} },
		UTILS = {
			timer_display_threshold = function()
				return cfg.threshold or 0
			end,
		},
		is_any_layer_active = function()
			return cfg.layer
		end,
	}
	PVP.UI.restore_timer = function(a)
		PVP.GAME.timer = PVP.GAME.timer + a
	end
	PVP.UI.consume_timer = function(a, _, min)
		if PVP.GAME.timer > min then
			PVP.GAME.timer = math.max(0, PVP.GAME.timer - a)
		end
	end
	load(chunk)()
end
local function own()
	PVP.GAME.skips_before_pvp = (PVP.GAME.skips_before_pvp or 0) + 1
	PVP.UI.update_matching_skip_timer(false)
end
local function opp()
	PVP.GAME.enemy.skips_before_pvp = (PVP.GAME.enemy.skips_before_pvp or 0) + 1
	PVP.UI.update_matching_skip_timer(true)
end

setup({})
own()
check("own skip adds time", PVP.GAME.timer, 210)
opp()
check("opponent catching up takes it back", PVP.GAME.timer, 150)
own()
own()
opp()
check("two ahead, one back", PVP.GAME.timer, 210)

setup({})
opp()
own()
check("opponent first, then own: no change", PVP.GAME.timer, 150)

setup({})
PVP.GAME.timer = 30
PVP.GAME.skips_before_pvp = 1
PVP.GAME.skips_difference = 1
opp()
check("takeback floors at 10", PVP.GAME.timer, 10)

-- A closed gate must still move the baseline, so the next open-gate skip is judged against it.
setup({})
own()
check("own skip: +60", PVP.GAME.timer, 210)
PVP.GAME.timer_started = true
opp()
check("opponent skip with a running timer: no time change", PVP.GAME.timer, 210)
check("baseline followed the closed gate", PVP.GAME.skips_difference, 0)
PVP.GAME.timer_started = false
own()
check("next own skip pays +60 again", PVP.GAME.timer, 270)

setup({})
PVP.GAME.timer_started = true
own()
own()
check("skips during a running timer pay nothing", PVP.GAME.timer, 150)
PVP.GAME.timer_started = false
own()
check("then one more skip pays one increment, not three", PVP.GAME.timer, 210)

setup({ threshold = 30 })
own()
own()
opp()
check("display-threshold ruleset: own skips add, opponent does not take back", PVP.GAME.timer, 270)

setup({ layer = true })
own()
check("pressure or no-animation layer: nothing", PVP.GAME.timer, 150)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
