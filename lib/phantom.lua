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
PVP.NEMESIS_SLOT_GAP = 0.25

local function remove_nemesis_slots()
	PVP.clear_ante_nemesis()
	PVP.TRAP_ROW.reset()
	for _, key in ipairs({ "nemesis_jokers", "nemesis_jokers_hidden", "nemesis_consumeables" }) do
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
	-- Phantom jokers of players who are not the ante's Nemesis wait here: kept in memory, never drawn,
	-- never in the joker calculation, and parked off-screen so the cursor cannot hit them.
	PVP.nemesis_jokers_hidden = new_nemesis_row(card_area_sizes.joker_W, card_area_sizes.joker_H)
	PVP.nemesis_jokers_hidden.states.visible = false
	PVP.nemesis_jokers_hidden.T.x = -100
	PVP.nemesis_jokers_hidden.T.y = -100
	PVP.nemesis_jokers_hidden:hard_set_T()
	PVP.init_ante_nemesis()
end

-- Where a copy from this sender lives: the visible row for the ante's Nemesis, the hidden store for the rest.
function PVP.nemesis_phantom_area(from)
	if PVP.is_ante_nemesis(from) then return PVP.nemesis_jokers end
	return PVP.nemesis_jokers_hidden
end

local function move_phantoms(from_area, to_area, wants_visible)
	local moving = {}
	for _, card in ipairs(from_area.cards) do
		if PVP.is_phantom(card) and PVP.is_ante_nemesis(card.ability.mp_phantom_from) == wants_visible then
			moving[#moving + 1] = card
		end
	end
	for _, card in ipairs(moving) do
		from_area:remove_card(card)
		to_area:emplace(card)
	end
end

-- Show only the ante Nemesis's Phantom jokers; the rest wait in the hidden store.
function PVP.sort_phantoms_by_ante_nemesis()
	move_phantoms(PVP.nemesis_jokers, PVP.nemesis_jokers_hidden, false)
	move_phantoms(PVP.nemesis_jokers_hidden, PVP.nemesis_jokers, true)
end

-- Called from set_screen_positions: each Nemesis row mirrors the x and width of the player's row below it.
function PVP.place_nemesis_slots()
	local rows_to_place = {
		{ nemesis_row = PVP.nemesis_jokers, own_row = G.jokers },
		{ nemesis_row = PVP.nemesis_consumeables, own_row = G.consumeables },
	}
	for _, place in ipairs(rows_to_place) do
		local nemesis_row, own_row = place.nemesis_row, place.own_row
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
		area = function(from)
			return PVP.nemesis_phantom_area(from)
		end,
	})
end
