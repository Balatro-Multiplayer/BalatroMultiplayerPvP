-- Run from the repo root: luajit tests/unit/timer_gradient_test.lua
-- ui/game/timer.lua: the mp_timer_accelerated gradient updates every frame from boot, before
-- pvp_api (PVP.current_run_id, PVP.TimerNet) has loaded, with a ruleset already in the config.
local gradients = {}
G = { C = { WHITE = { 1, 1, 1, 1 }, IMPORTANT = { 1, 0, 0, 1 } }, FUNCS = {}, TIMERS = { REAL = 0 } }
mix_colours = function(a)
	return a
end
SMODS = {
	Gradient = function(def)
		gradients[def.key] = def
	end,
}
local lobby = nil
MPAPI = {
	get_current_lobby = function()
		return lobby
	end,
}
PVP = { UI = {}, GAME = {}, LOBBY = { config = { ruleset = "ruleset_mp_standard" } } }
dofile("ui/game/timer.lua")
local gradient = gradients["timer_accelerated"]
gradient.interpolation = "linear"

local failures = 0
local function check(name, got, want)
	if got == want then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": got " .. tostring(got) .. ", want " .. tostring(want))
	end
end

local ok, err = pcall(gradient.update, gradient, 0)
check("no lobby at boot: the update reads no net", ok, true)
if not ok then print("     " .. tostring(err)) end

lobby = { player_id = "p1" }
PVP.clocks_rules = function()
	return nil
end
PVP.UI.timer_box = function()
	return { kind = "seconds", seconds = 0.5 }
end
ok, err = pcall(gradient.update, gradient, 0)
check("in a lobby: the update runs", ok, true)
if not ok then print("     " .. tostring(err)) end
check("in a lobby: the pulse colour is set", type(gradient[1]), "number")

if failures > 0 then os.exit(1) end
print("all passed")
