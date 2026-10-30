-- Mental Prison watches what is on offer at the moment the Nemesis walks away, so there is no
-- seen-state to save: a Wheel of Fortune still in the shop or the pack at that moment was not taken.
-- Leaving the shop is a calculate context; skipping or finishing a pack and rerolling are not
-- (the reroll context only fires after the shop cards are replaced), so those two wrap the
-- vanilla functions and read the area before it is cleared.
function PVP.TRAP.area_holds_wheel(area)
	for _, offered in ipairs(area and area.cards or {}) do
		if offered.config.center.key == "c_wheel_of_fortune" then
			return true
		end
	end
	return false
end

local function fire_mental_prison_if_wheel_left(area)
	local trap = PVP.TRAP.find_planted(PVP.TRAP.KEY.MENTAL_PRISON)
	if trap and PVP.TRAP.area_holds_wheel(area) then
		PVP.TRAP.fire(trap, {})
	end
end

-- Runs for both a skipped pack and a pack whose picks are used up.
local end_consumeable_ref = G.FUNCS.end_consumeable
G.FUNCS.end_consumeable = function(e, delayfac)
	if PVP.in_session() then
		fire_mental_prison_if_wheel_left(G.pack_cards)
	end
	return end_consumeable_ref(e, delayfac)
end

local reroll_shop_ref = G.FUNCS.reroll_shop
G.FUNCS.reroll_shop = function(e)
	if PVP.in_session() then
		fire_mental_prison_if_wheel_left(G.shop_jokers)
	end
	return reroll_shop_ref(e)
end
