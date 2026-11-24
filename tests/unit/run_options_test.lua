-- Run from the repo root: luajit tests/unit/run_options_test.lua
-- ui/pvp_run_options.lua: the pause menu's Forfeit button is always pressable in a PvP run, closes the
-- overlay first, and leaves "once per run" to the finish screen.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local calls
local plain_buttons, gated_buttons
PVP = {
	NET = {}, READ = {}, GAME = {},
	PRACTICE = { is_on = function() return false end },
	UI = {
		contest = { offered = function() return false end },
		run_options = {},
		show_contest_modal = function() calls[#calls + 1] = "contest_modal" end,
		-- The status gate the old button read: off once I am out.
		finish = {
			can_forfeit = function() return false end,
			waiting = function() return false end,
			forfeit = function() calls[#calls + 1] = "forfeit" end,
			vote = function() end,
		},
	},
	LOBBY = {},
}
G = {
	UIT = { R = "R", C = "C" },
	C = { BLUE = "blue", RED = "red" },
	SETTINGS = {},
	FUNCS = {
		exit_overlay_menu = function() calls[#calls + 1] = "exit_overlay" end,
		go_to_menu = function() calls[#calls + 1] = "menu" end,
	},
}
love = { timer = { getTime = function() return 0 end } }
localize = function(key) return "t:" .. key end
function UIBox_button(config)
	plain_buttons[#plain_buttons + 1] = config.button
	return { button = config.button }
end
MPAPI = {
	get_current_lobby = function() return nil end,
	pause_menu_extra_rows = function() return {} end,
	disableable_button = function(config)
		gated_buttons[config.button] = config.enabled
		return { node = { button = config.button } }
	end,
}
function create_UIBox_generic_options(options) return options end
dofile("ui/pvp_run_options.lua")

local function build()
	plain_buttons, gated_buttons = {}, {}
	PVP.UI.run_options.build()
end
local function has(list, name)
	for _, entry in ipairs(list) do
		if entry == name then return true end
	end
	return false
end

-- the button
build()
eq(gated_buttons.mp_pvp_forfeit, nil, "Forfeit is not a gated button: no status turns it off")
eq(has(plain_buttons, "mp_pvp_forfeit"), true, "Forfeit is always pressable")

-- the press
calls = {}
G.FUNCS.mp_pvp_forfeit()
eq(calls[1], "exit_overlay", "the overlay closes first")
eq(calls[2], "forfeit", "then the forfeit goes to the finish screen")
G.FUNCS.mp_pvp_forfeit()
eq(calls[3], "exit_overlay", "a second press closes the overlay again")
eq(calls[4], "forfeit", "and leaves once-per-run to the finish screen")

-- practice and contest keep their branches
calls = {}
PVP.PRACTICE.is_on = function() return true end
G.FUNCS.mp_pvp_forfeit()
eq(calls[2], "menu", "practice goes to the menu")
eq(#calls, 2, "and sends no forfeit")
PVP.PRACTICE.is_on = function() return false end
PVP.UI.contest.offered = function() return true end
calls = {}
G.FUNCS.mp_pvp_forfeit()
eq(calls[2], "contest_modal", "a matchmade match asks first")
eq(#calls, 2, "and sends no forfeit yet")

T.done("run_options_test")
