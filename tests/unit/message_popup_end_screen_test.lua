-- Plain Lua test: closing a message popup after your match is over reopens the end screen.
-- Run from the repo root: luajit tests/unit/message_popup_end_screen_test.lua
PVP = { UI = {}, UTILS = {}, GAME = {} }
G = {
	STAGE = 2,
	STAGES = { RUN = 2, MAIN_MENU = 1 },
	STATE = 1,
	STATES = { SELECTING_HAND = 1, GAME_OVER = 4, NEW_ROUND = 19 },
	UIT = { T = 1, R = 2, C = 3, O = 4, B = 5 },
	C = { UI = {} },
	SETTINGS = {},
	FUNCS = {},
}
dofile("lib/string_utils.lua")
dofile("ui/node_builders.lua")

local opened, calls
function create_UIBox_generic_options(args)
	return args
end
function DynaText(t)
	return t
end
G.FUNCS.overlay_menu = function(args)
	opened = args
end
G.FUNCS.exit_overlay_menu = function()
	calls[#calls + 1] = "exit"
end
G.FUNCS.overlay_endgame_menu = function()
	calls[#calls + 1] = "endgame"
end

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

-- Shows the popup, then presses its Back. Returns what Back did and whether Esc is off.
local function show_and_close(show)
	opened, calls = nil, {}
	show()
	local back = opened.definition.back_func or "exit_overlay_menu"
	G.FUNCS[back]({})
	return calls[1], (opened.config and opened.config.no_esc) == true
end

local function popup()
	PVP.UI.UTILS.overlay_message("Them left the lobby.")
end
local function countdown()
	PVP.UI.UTILS.overlay_message_countdown("Them disconnected.", { display = "30" })
end

for _, case in ipairs({
	{ "mid-match", G.STATES.SELECTING_HAND, {}, "exit", false },
	{ "loser's end screen", G.STATES.GAME_OVER, {}, "endgame", true },
	{ "winner's end screen", G.STATES.NEW_ROUND, { won = true }, "endgame", true },
	{ "eliminated", G.STATES.NEW_ROUND, { eliminated = true }, "endgame", true },
}) do
	local name, state, game, back, no_esc = case[1], case[2], case[3], case[4], case[5]
	G.STATE, PVP.GAME = state, game
	for kind, show in pairs({ message = popup, countdown = countdown }) do
		local did, esc_off = show_and_close(show)
		check(name .. " " .. kind .. ": Back", did, back)
		check(name .. " " .. kind .. ": Esc off", esc_off, no_esc)
	end
end

-- Outside a run (main menu, lobby) Back just closes it.
G.STAGE, G.STATE, PVP.GAME = G.STAGES.MAIN_MENU, G.STATES.GAME_OVER, {}
check("main menu: Back", (show_and_close(popup)), "exit")

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
