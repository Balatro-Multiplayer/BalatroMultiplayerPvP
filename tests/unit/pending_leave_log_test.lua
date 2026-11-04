-- Plain LuaJIT test: Leave from the Pending death screen writes the end event
-- before the lobby is left; Leave from any other end screen does not.
-- Run from the repo root: luajit tests/unit/pending_leave_log_test.lua
local noop = function() end
local calls = {}
local function note(name)
	return function(...)
		calls[#calls + 1] = name
		return ...
	end
end
local ended
local lobby = { leave = note("lobby_leave") }
PVP = { GAME = {}, UI = {}, RLOG = {} }
function PVP.RLOG.end_run(outcome)
	calls[#calls + 1] = "end_run"
	ended = outcome
end
G = { FUNCS = { exit_overlay_menu = noop, go_to_menu = note("go_to_menu") }, SETTINGS = {} }
MPAPI = {
	get_current_lobby = function()
		return lobby
	end,
}

dofile("ui/game/leave.lua")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

PVP.GAME.pending_death_screen = true
G.FUNCS.mp_pvp_leave_from_game()
check("pending leave: end event first, then lobby leave", table.concat(calls, ","), "end_run,lobby_leave,go_to_menu")
check("pending leave: result is pending", ended and ended.result, "pending")
check("pending leave: last life is lost", ended and ended.lives, 0)

calls, ended = {}, nil
PVP.GAME.pending_death_screen = false
G.FUNCS.mp_pvp_leave_from_game()
check("normal end screen leave writes no end event", table.concat(calls, ","), "lobby_leave,go_to_menu")

os.exit(failures == 0 and 0 or 1)
