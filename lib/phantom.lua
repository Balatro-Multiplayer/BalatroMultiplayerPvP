local get_card_areas_ref = SMODS.get_card_areas
function SMODS.get_card_areas(_type, _context)
	if _type == "jokers" and PVP.shared then
		local t = get_card_areas_ref(_type, _context)
		table.insert(t, PVP.shared)
		return t
	end
	return get_card_areas_ref(_type, _context)
end

-- Register this showcase (PVP.shared) with the synced-object framework so `phantom = true`
-- jokers spawn their display copies here, and install the masking patches
-- (find_card / poll_edition / Card:remove) that hide phantom cards from real gameplay.
if MPAPI and MPAPI.configure_phantom then
	MPAPI.configure_phantom({
		area = function()
			return PVP.shared
		end,
	})
end
