-- Plain Lua test: the PvP Bloodstone tooltip asks SMODS.get_probability_vars for its odds, so the
-- odds shown on another player's Bloodstone leave out this player's own Oops! All 6s.
-- Run from the repo root: luajit tests/unit/bloodstone_odds_test.lua
local def
SMODS = {}
function SMODS.Joker(t)
	def = t
end
-- Stands in for SMODS plus the lib/phantom.lua wrap: this player holds one Oops! All 6s, which
-- doubles the numerator, except on a Phantom (opponent) joker.
function SMODS.get_probability_vars(trigger_obj, base_numerator, base_denominator)
	if trigger_obj and trigger_obj.ability and trigger_obj.ability.mp_phantom then
		return base_numerator, base_denominator
	end
	return base_numerator * 2, base_denominator
end
G = { GAME = { probabilities = { normal = 2 } } }

assert(loadfile("objects/jokers/standard/bloodstone.lua"))()

local failures = 0
local function check(name, got, want)
	if tostring(got) ~= tostring(want) then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end
local function shown(ability)
	ability.extra = { odds = 2, Xmult = 1.5 }
	local vars = def.loc_vars(def, {}, { ability = ability }).vars
	return vars[1] .. " in " .. vars[2], vars[3]
end

check("own Bloodstone keeps Oops", shown({}), "2 in 2")
check("opponent's Phantom Bloodstone leaves out Oops", shown({ mp_phantom = true }), "1 in 2")
check("Xmult is still the third var", select(2, shown({})), 1.5)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
