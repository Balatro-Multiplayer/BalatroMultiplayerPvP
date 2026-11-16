-- Run from the repo root: lua5.4 tests/unit/preview_buttons_test.lua
-- Load the actual Preview init and interface with minimal game stubs; check that
-- score and money previews switch on independently.
G = {
	UIT = { C = "C", R = "R", T = "T" },
	C = { RED = "red", MONEY = "money", UI = { TEXT_LIGHT = "light" } },
	FUNCS = {},
}
Game = { start_up = function() end }
PVP = {
	INTEGRATIONS = {},
	in_session = function()
		return true
	end,
	UTILS = {
		get_preview_cfg = function()
			return "Calc Score"
		end,
	},
}
dofile("compatibility/Preview/InitPreview.lua")
dofile("compatibility/Preview/InterfacePreview.lua")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local function preview(score, money)
	PVP.INTEGRATIONS.Preview = score
	PVP.INTEGRATIONS.PreviewMoney = money
	local ids = {}
	for _, button in ipairs(FN.PRE.get_calculate_score_button().nodes[1].nodes) do
		table.insert(ids, button.config.id)
	end
	return (FN.PRE.in_play() and "on" or "off") .. ": " .. table.concat(ids, ", ")
end

check("score only", preview(true, false), "on: calculate_score_button")
check("money only", preview(false, true), "on: calculate_money_button")
check("both", preview(true, true), "on: calculate_score_button, calculate_money_button")
check("neither", preview(false, false), "off: ")

if failures > 0 then os.exit(1) end
