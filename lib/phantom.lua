local get_card_areas_ref = SMODS.get_card_areas
function SMODS.get_card_areas(_type, _context)
	if _type == "jokers" and PVP.nemesis_jokers then
		local t = get_card_areas_ref(_type, _context)
		table.insert(t, PVP.nemesis_jokers)
		return t
	end
	return get_card_areas_ref(_type, _context)
end

-- Gap between the bottom of the Nemesis slots and the top of the player's own rows, in game units.
PVP.NEMESIS_SLOT_GAP = 1

local function remove_nemesis_slots()
	for _, key in ipairs({ "nemesis_jokers", "nemesis_consumeables" }) do
		if PVP[key] then
			PVP[key]:remove()
			PVP[key] = nil
		end
	end
end

local function new_nemesis_row(width, height)
	return CardArea(0, 0, width, height, {
		card_limit = 0,
		type = "joker",
		highlight_limit = 1,
		fixed_limit = true,
		no_card_count = true,
	})
end

-- Called from Game:start_run with the vanilla area sizes. The rows exist only in a live lobby.
function PVP.create_nemesis_slots(card_area_sizes)
	remove_nemesis_slots()
	if not PVP.LOBBY.code then return end
	PVP.nemesis_jokers = new_nemesis_row(card_area_sizes.joker_W, card_area_sizes.joker_H)
	PVP.nemesis_consumeables = new_nemesis_row(card_area_sizes.consumeable_W, card_area_sizes.consumeable_H)
end

-- Called from set_screen_positions: each Nemesis row mirrors the x and width of the player's row below it.
function PVP.place_nemesis_slots()
	local pairs_to_place = {
		{ PVP.nemesis_jokers, G.jokers },
		{ PVP.nemesis_consumeables, G.consumeables },
	}
	for _, pair in ipairs(pairs_to_place) do
		local nemesis_row, own_row = pair[1], pair[2]
		if nemesis_row then
			nemesis_row.T.x = own_row.T.x
			nemesis_row.T.y = own_row.T.y - PVP.NEMESIS_SLOT_GAP - nemesis_row.T.h
			nemesis_row:hard_set_T()
		end
	end
end

-- Register the Nemesis joker row with the synced-object framework so `phantom = true`
-- jokers spawn their display copies here, and install the masking patches
-- (find_card / poll_edition / Card:remove) that hide phantom cards from real gameplay.
if MPAPI and MPAPI.configure_phantom then
	MPAPI.configure_phantom({
		area = function()
			return PVP.nemesis_jokers
		end,
	})
end
