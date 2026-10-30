local get_card_areas_ref = SMODS.get_card_areas
function SMODS.get_card_areas(_type, _context)
	if _type == "jokers" and PVP.nemesis_jokers then
		local t = get_card_areas_ref(_type, _context)
		table.insert(t, PVP.nemesis_jokers)
		return t
	end
	return get_card_areas_ref(_type, _context)
end

-- The eternal sticker alone does not stop a sale: Steamodded ignores it on jokers that are not eternal-compatible.
local can_sell_card_ref = Card.can_sell_card
function Card:can_sell_card(context)
	if PVP.is_phantom(self) then return false end
	return can_sell_card_ref(self, context)
end

-- Gap between the bottom of the Nemesis slots and the top of the player's own rows, in game units.
PVP.NEMESIS_SLOT_GAP = 0.25

local function remove_nemesis_slots()
	PVP.clear_ante_nemesis()
	PVP.TRAP_ROW.reset()
	local removed = {}
	for _, key in ipairs({ "nemesis_jokers", "nemesis_jokers_hidden", "nemesis_consumeables" }) do
		-- In the Classic layout the joker and consumable keys name one shared area: remove it once.
		if PVP[key] and not removed[PVP[key]] then
			removed[PVP[key]] = true
			PVP[key]:remove()
		end
		PVP[key] = nil
	end
	PVP.run_nemesis_layout = nil
end

local function place_area(area, x, y)
	area.T.x = x
	area.T.y = y
	area:hard_set_T()
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
	-- Fixed for the run: a change of the setting applies from the next run.
	PVP.run_nemesis_layout = PVP.get_nemesis_layout()
	if PVP.run_nemesis_layout == PVP.NEMESIS_LAYOUT.CLASSIC then
		-- One row for the Phantom jokers and the face-down Trap cards. Both keys name it, so the code that
		-- fills "the joker row" and "the trap row" needs no second path.
		PVP.nemesis_jokers = new_nemesis_row(card_area_sizes.consumeable_W / 2, card_area_sizes.consumeable_H)
		PVP.nemesis_consumeables = PVP.nemesis_jokers
	else
		PVP.nemesis_jokers = new_nemesis_row(card_area_sizes.joker_W, card_area_sizes.joker_H)
		PVP.nemesis_consumeables = new_nemesis_row(card_area_sizes.consumeable_W, card_area_sizes.consumeable_H)
	end
	-- Phantom jokers of players who are not the ante's Nemesis wait here: kept in memory, never drawn,
	-- never in the joker calculation, and parked off-screen so the cursor cannot hit them.
	PVP.nemesis_jokers_hidden = new_nemesis_row(card_area_sizes.joker_W, card_area_sizes.joker_H)
	PVP.nemesis_jokers_hidden.states.visible = false
	place_area(PVP.nemesis_jokers_hidden, -100, -100)
	PVP.init_ante_nemesis()
end

-- Leaving a run frees every CardArea, so drop the Nemesis slots with it: the ante Nemesis refresh must not
-- sort the cards of dead rows on the menu.
local delete_run_ref = Game.delete_run
function Game:delete_run()
	remove_nemesis_slots()
	return delete_run_ref(self)
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

-- An unknown or missing saved value reads as Standard.
function PVP.nemesis_layout_index()
	for index, layout in ipairs(PVP.NEMESIS_LAYOUT_ORDER) do
		if PVP.config.nemesis_layout == layout then return index end
	end
	return 1
end

function PVP.get_nemesis_layout()
	return PVP.NEMESIS_LAYOUT_ORDER[PVP.nemesis_layout_index()]
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
			place_area(nemesis_row, own_row.T.x, own_row.T.y - PVP.NEMESIS_SLOT_GAP - nemesis_row.T.h)
		end
	end
end

-- Classic: the Nemesis area sits one row below the consumables, on their right half, at half their width.
local function place_classic_layout()
	local area = PVP.nemesis_jokers
	if not area then return end
	place_area(area, G.consumeables.T.x + G.consumeables.T.w / 2, G.consumeables.T.y + G.consumeables.T.h + 0.4)
end

-- Mirrored: the rows swap places and keep their own widths. The Nemesis consumable row starts at the left
-- edge of the player's joker row, the Nemesis joker row ends at the right edge of the player's consumable row.
local function place_mirrored_layout()
	local jokers, consumeables = PVP.nemesis_jokers, PVP.nemesis_consumeables
	if consumeables then
		place_area(consumeables, G.jokers.T.x, G.jokers.T.y - PVP.NEMESIS_SLOT_GAP - consumeables.T.h)
	end
	if jokers then
		place_area(
			jokers,
			G.consumeables.T.x + G.consumeables.T.w - jokers.T.w,
			G.consumeables.T.y - PVP.NEMESIS_SLOT_GAP - jokers.T.h
		)
	end
end

-- Mirrored seen across a table: after the vanilla alignment, every card in a Nemesis row swaps to the
-- opposite side of the row (the reverse display order, the stored order is untouched) and turns 180 degrees.
-- Tooltips follow the card's position only, so they stay upright.
local align_cards_ref = CardArea.align_cards
function CardArea:align_cards()
	align_cards_ref(self)
	if (self ~= PVP.nemesis_jokers and self ~= PVP.nemesis_consumeables) or not self.cards then return end
	-- Turned cards follow the live setting, so a switch between Standard and Mirrored applies at once.
	local mirrored = PVP.run_nemesis_layout ~= PVP.NEMESIS_LAYOUT.CLASSIC
		and PVP.get_nemesis_layout() == PVP.NEMESIS_LAYOUT.MIRRORED
	if not mirrored then return end
	for _, card in ipairs(self.cards) do
		if not card.states.drag.is and not card.disable_align then
			card.T.x = 2 * self.T.x + self.T.w - card.T.x - card.T.w
			card.T.r = card.T.r + math.pi
		end
	end
end

local NEMESIS_LAYOUT_PLACERS = {
	[PVP.NEMESIS_LAYOUT.STANDARD] = place_standard_layout,
	[PVP.NEMESIS_LAYOUT.MIRRORED] = place_mirrored_layout,
}

-- Called from set_screen_positions, and again when the setting changes. All placement of the Nemesis
-- cards goes through here.
function PVP.place_nemesis_slots()
	if PVP.run_nemesis_layout == PVP.NEMESIS_LAYOUT.CLASSIC then return place_classic_layout() end
	-- A switch to Classic mid-run has no area built for it, so it shows as Standard until the next run.
	local layout = PVP.get_nemesis_layout()
	if layout == PVP.NEMESIS_LAYOUT.CLASSIC then layout = PVP.NEMESIS_LAYOUT.STANDARD end
	NEMESIS_LAYOUT_PLACERS[layout]()
end

-- A Trap card in the shared Nemesis area is display only: it never calculates, even though the area is
-- in the joker calculation for its Phantom jokers.
local calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context)
	if self.ability and self.ability.mp_trap_display then return nil end
	return calculate_joker_ref(self, context)
end

-- Classic look: a Phantom joker in the shared Nemesis area draws the old phantom shader ("voucher") in
-- place of the base shader. This is a look only: no edition, badge, sticker or sell value is involved.
local function has_classic_phantom_look(card)
	return PVP.run_nemesis_layout == PVP.NEMESIS_LAYOUT.CLASSIC and card.area == PVP.nemesis_jokers and PVP.is_phantom(card)
end

local should_draw_base_shader_ref = Card.should_draw_base_shader
function Card:should_draw_base_shader()
	-- The base shader also draws the dissolve, so a dissolving card keeps it.
	if has_classic_phantom_look(self) and not (self.dissolve and self.dissolve > 0) then return false end
	return should_draw_base_shader_ref(self)
end

SMODS.DrawStep({
	key = "mp_classic_phantom_look",
	order = 20,
	func = function(self)
		if not has_classic_phantom_look(self) then return end
		self.children.center:draw_shader("voucher", nil, self.ARGS.send_to_shader)
	end,
	conditions = { vortex = false, facing = "front" },
})

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
