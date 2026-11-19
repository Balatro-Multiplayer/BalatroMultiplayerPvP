-- Plain Lua test for lib/ante_timer.lua: after an Ante timer run-out the timer starts
-- again by itself, until the timered player has no lives left.
-- Run from the repo root: luajit tests/unit/ante_timer_restart_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local failed, announced
local function setup(lives, forgiveness)
	failed, announced = 0, {}
	PVP = {
		UTILS = {
			timer_base = function()
				return 150
			end,
		},
		LOBBY = { config = { timer_forgiveness = forgiveness or 0 } },
		GAME = {
			lives = lives,
			timer = 0,
			timer_consumed = true,
			timers_forgiven = 0,
			nemesis_timer_started = true,
		},
		ACTIONS = {
			fail_timer = function()
				failed = failed + 1
			end,
			announce_ante_timer_restart = function(time, rejoined)
				table.insert(announced, time)
				announced.rejoined = rejoined
			end,
			announce_ante_timer = function(time)
				announced.start = time
			end,
		},
	}
	dofile("lib/ante_timer.lua")
end

setup(3)
PVP.AnteTimer.on_run_out()
check("run-out costs a life", failed, 1)
check("timer restarts at the base time", PVP.GAME.timer, 150)
check("restarted timer can tick again", PVP.GAME.timer_consumed, false)
check("timered side stays timered", PVP.GAME.nemesis_timer_started, true)
check("opponent is told the restart", announced[1], 150)

setup(1)
PVP.AnteTimer.on_run_out()
check("last life lost: life cost", failed, 1)
check("last life lost: timer stays out", PVP.GAME.timer_consumed, true)
check("last life lost: no restart sent", #announced, 0)

setup(1, 1)
PVP.AnteTimer.on_run_out()
check("forgiven run-out costs no life", failed, 0)
check("forgiven run-out restarts", PVP.GAME.timer_consumed, false)
check("forgiveness is used up", PVP.GAME.timers_forgiven, 1)

setup(2)
PVP.GAME.timer_started = true
PVP.GAME.nemesis_timer_started = false
PVP.GAME.timer = 12
PVP.AnteTimer.receive_restart(150)
check("waiting side resets its copy", PVP.GAME.timer, 150)
check("waiting side ticks again", PVP.GAME.timer_consumed, false)

setup(2)
PVP.GAME.timer_started = false
PVP.GAME.nemesis_timer_started = false
PVP.GAME.timer = 150
PVP.GAME.timer_consumed = false
PVP.AnteTimer.receive_restart(40)
check("a restart after the timer stopped is ignored", PVP.GAME.timer, 150)

-- A player who rejoins in the middle of the timer gets it from the opponent.
setup(2)
PVP.GAME.timer = 77
PVP.AnteTimer.on_opponent_back()
check("timered side resends the running timer", announced[1], 77)
check("timered side marks the resend as rejoined", announced.rejoined, true)

setup(2)
PVP.GAME.nemesis_timer_started = false
PVP.GAME.timer_started = true
PVP.GAME.timer = 88
PVP.AnteTimer.on_opponent_back()
check("waiting side resends its start", announced.start, 88)

setup(2)
PVP.GAME.nemesis_timer_started = false
PVP.GAME.timer = 150
PVP.AnteTimer.on_opponent_back()
check("no timer running: nothing resent", announced[1] == nil and announced.start == nil, true)

setup(2)
PVP.GAME.nemesis_timer_started = false
PVP.GAME.timer = 77
PVP.AnteTimer.receive_restart(60, true)
check("a rejoined waiting player picks the timer up", PVP.GAME.timer_started, true)
check("rejoined waiting player gets the time", PVP.GAME.timer, 60)

-- Teams: PVP.GAME.lives is the team's shared pool (the referee mirrors the pool onto every
-- teammate through pvp_player_lives), so the pool's last life stops the restart too.
setup(1)
PVP.LOBBY.config.team_based = true
PVP.AnteTimer.on_run_out()
check("teams, last team life: life cost", failed, 1)
check("teams, last team life: no restart sent", #announced, 0)

setup(2)
PVP.LOBBY.config.team_based = true
PVP.AnteTimer.on_run_out()
check("teams, lives left in the pool: restart sent", #announced, 1)

if failures > 0 then
	os.exit(1)
end
