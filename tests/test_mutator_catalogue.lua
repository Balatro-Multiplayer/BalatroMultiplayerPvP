-- Presentation contract only: layer effects and actual rendering need the game.
-- Run from the PvP root with Lua or LuaJIT.
local passed = 0
local function check(value, message)
	assert(value, message)
	passed = passed + 1
end

local expected = {
	{ "economy", "no_interest", "spartan", "discard_tax", "frugal", "inflation", "pricey_packs" },
	{
		"constraints",
		"shrinking_hand",
		"shared_pockets",
		"flipped_cards",
		"debuff_played_cards",
		"all_eternal",
	},
	{
		"pool",
		"bigger_shop",
		"gambling_opportunity",
		"no_uncommons",
		"no_red_seals",
		"smallworld",
	},
	{ "scoring", "glass_cannon", "score_instability", "chip_cap" },
	{ "chaos", "eeeee", "polymorph_spam" },
	{ "balance", "wraith_rework", "dice_patch" },
	{ "content", "sandbox_rotation", "sandbox_retired", "sandbox_extra_credit" },
}

PVP = {}
MPAPI = { Layers = {} }
-- Supply known layer names, without loading or simulating their gameplay hooks.
for _, column in ipairs(expected) do
	for index = 2, #column do
		MPAPI.Layers[column[index]] = {}
	end
end
dofile("lib/mutators.lua")
dofile("layers/zz_mutator_catalogue.lua")
local dictionary = dofile("localization/en-us.lua").misc.dictionary
check(#PVP.MUTATOR_CATEGORIES == #expected, "seven columns")
local total = 0
for index, column in ipairs(expected) do
	local category = column[1]
	check(PVP.MUTATOR_CATEGORIES[index] == category, "column order: " .. category)
	check(type(dictionary["k_solo_category_" .. category]) == "string", "localized heading: " .. category)
	local actual = PVP.mutators_in(category)
	check(#actual == #column - 1, "column size: " .. category)
	for row, definition in ipairs(actual) do
		check(definition.key == column[row + 1], "row order: " .. category .. "/" .. row)
		total = total + 1
	end
end
local registered = 0
for _ in pairs(PVP.MUTATORS) do
	registered = registered + 1
end
check(total == 26 and registered == total, "all 26 mutators appear exactly once")
for key in pairs(PVP.RETIRED_MUTATORS) do
	check(not PVP.MUTATORS[key], "retired recipe absent from wall: " .. key)
end
check(PVP.MUTATORS.sandbox_rotation.implied_by == "sandbox", "Sandbox inheritance preserved")
check(PVP.MUTATORS.sandbox_extra_credit.implied_by == "sandbox", "Extra Credit inheritance preserved")
print("Mutator catalogue: " .. passed .. " checks passed")
