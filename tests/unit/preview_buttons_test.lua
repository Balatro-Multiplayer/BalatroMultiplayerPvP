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
			return "Calculate Score"
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

-- Describes what the HUD gets: each button's label, and "original" if it uses the original look
local function preview(score, money)
	PVP.INTEGRATIONS.Preview = score
	PVP.INTEGRATIONS.PreviewMoney = money
	if not FN.PRE.in_play() then return "off" end
	local node = FN.PRE.get_calculate_score_button()
	local buttons = node.config.id and { node } or node.nodes[1].nodes
	local described = {}
	for _, button in ipairs(buttons) do
		local label = button.nodes[1].nodes[1].config.text
		table.insert(described, label .. (button.config.shadow and " (original)" or ""))
	end
	return table.concat(described, ", ")
end

check("score only", preview(true, false), "Calculate Score (original)")
check("money only", preview(false, true), "Calculate Money (original)")
check("both", preview(true, true), "Calc Score, Calc Money")
check("neither", preview(false, false), "off")

if failures > 0 then os.exit(1) end
