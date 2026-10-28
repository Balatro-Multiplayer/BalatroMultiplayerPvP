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

-- The Nemesis layout values, in the order of the config option cycle. The setting is a display choice
-- of this player only: it is saved in the PvP config and never sent to other players.
PVP.NEMESIS_LAYOUT = {
	STANDARD = "standard",
	MIRRORED = "mirrored",
	CLASSIC = "classic",
}
PVP.NEMESIS_LAYOUT_ORDER = {
	PVP.NEMESIS_LAYOUT.STANDARD,
	PVP.NEMESIS_LAYOUT.MIRRORED,
	PVP.NEMESIS_LAYOUT.CLASSIC,
}

-- The chosen layout. An unknown or missing saved value reads as Standard.
function PVP.get_nemesis_layout()
	for _, layout in ipairs(PVP.NEMESIS_LAYOUT_ORDER) do
		if PVP.config.nemesis_layout == layout then return layout end
	end
	return PVP.NEMESIS_LAYOUT.STANDARD
end

-- Position of the chosen layout in the option cycle.
function PVP.nemesis_layout_index()
	local layout = PVP.get_nemesis_layout()
	for index, value in ipairs(PVP.NEMESIS_LAYOUT_ORDER) do
		if value == layout then return index end
	end
end

-- Standard: each Nemesis row mirrors the x and width of the player's row below it.
local function place_standard_layout()
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

-- Mirrored: the rows swap places and keep their own widths. The Nemesis consumable row starts at the left
-- edge of the player's joker row, the Nemesis joker row ends at the right edge of the player's consumable row.
local function place_mirrored_layout()
	local jokers, consumeables = PVP.nemesis_jokers, PVP.nemesis_consumeables
	if consumeables then
		consumeables.T.x = G.jokers.T.x
		consumeables.T.y = G.jokers.T.y - PVP.NEMESIS_SLOT_GAP - consumeables.T.h
		consumeables:hard_set_T()
	end
	if jokers then
		jokers.T.x = G.consumeables.T.x + G.consumeables.T.w - jokers.T.w
		jokers.T.y = G.consumeables.T.y - PVP.NEMESIS_SLOT_GAP - jokers.T.h
		jokers:hard_set_T()
	end
end

-- Mirrored seen across a table: after the vanilla alignment, every card in a Nemesis row swaps to the
-- opposite side of the row (the reverse display order, the stored order is untouched) and turns 180 degrees.
-- Tooltips follow the card's position only, so they stay upright.
local align_cards_ref = CardArea.align_cards
function CardArea:align_cards()
	align_cards_ref(self)
	if (self ~= PVP.nemesis_jokers and self ~= PVP.nemesis_consumeables) or not self.cards then return end
	if PVP.get_nemesis_layout() ~= PVP.NEMESIS_LAYOUT.MIRRORED then return end
	for _, card in ipairs(self.cards) do
		if not card.states.drag.is and not card.disable_align then
			card.T.x = 2 * self.T.x + self.T.w - card.T.x - card.T.w
			card.T.r = card.T.r + math.pi
		end
	end
end

-- Classic shows Standard until its own placement exists.
local NEMESIS_LAYOUT_PLACERS = {
	[PVP.NEMESIS_LAYOUT.STANDARD] = place_standard_layout,
	[PVP.NEMESIS_LAYOUT.MIRRORED] = place_mirrored_layout,
	[PVP.NEMESIS_LAYOUT.CLASSIC] = place_standard_layout,
}

-- Called from set_screen_positions, and again when the setting changes. All placement of the Nemesis
-- cards goes through here.
function PVP.place_nemesis_slots()
	NEMESIS_LAYOUT_PLACERS[PVP.get_nemesis_layout()]()
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
