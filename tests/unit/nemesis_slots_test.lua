-- Run from the repo root: luajit tests/unit/nemesis_slots_test.lua
-- lib/phantom.lua: PVP.NEMESIS.create_slots rebuilds the Nemesis areas, and the trap row is drawn again
-- in the new area right after the ante's Nemesis is set.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local steps = {}
local function area_stub()
	local area = { T = { x = 0, y = 0 }, states = {}, cards = {} }
	function area:hard_set_T() end
	function area:remove() steps[#steps + 1] = "area removed" end
	return area
end

SMODS = {
	get_card_areas = function() return {} end,
	get_probability_vars = function() end,
	DrawStep = function() end,
}
Card = { can_sell_card = function() end, calculate_joker = function() end, should_draw_base_shader = function() end }
Game = { delete_run = function() end }
CardArea = setmetatable({ align_cards = function() end }, { __call = function() return area_stub() end })
math.pi = math.pi
PVP = {
	UI = { trap_row = { refresh = function() steps[#steps + 1] = "trap row refreshed" end } },
	LOBBY = { code = "ABCD" },
	config = {},
	NEMESIS = {
		is_phantom = function() return false end,
		clear_ante = function() steps[#steps + 1] = "ante cleared" end,
		init_ante = function() steps[#steps + 1] = "ante set" end,
	},
}

dofile("lib/phantom.lua")

local sizes = { consumeable_W = 4, consumeable_H = 1, joker_W = 5, joker_H = 1 }

-- In a lobby: the areas are rebuilt, the ante's Nemesis is set, and only then is the trap row drawn.
steps = {}
PVP.NEMESIS.create_slots(sizes)
eq(steps[1], "ante cleared", "the old rows go first")
eq(steps[#steps - 1], "ante set", "the ante's Nemesis is set")
eq(steps[#steps], "trap row refreshed", "then the trap row is drawn in the new area")
eq(PVP.NEMESIS.consumeables ~= nil and PVP.NEMESIS.jokers ~= nil, true, "both rows exist")

-- Outside a lobby there are no rows, so nothing is drawn.
PVP.LOBBY.code = nil
steps = {}
PVP.NEMESIS.create_slots(sizes)
eq(PVP.NEMESIS.jokers, nil, "no row outside a lobby")
for _, step in ipairs(steps) do eq(step ~= "trap row refreshed", true, "no trap row drawn outside a lobby") end

T.done("nemesis_slots_test")
