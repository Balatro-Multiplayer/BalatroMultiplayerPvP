-- The Nemesis consumable row: face-down, display-only copies of the traps I planted that the ante's
-- Nemesis holds. They are read from the net's view (pvp_api/read/trap.lua), which lists only the
-- traps I own or hold, and drawn in PVP.NEMESIS.consumeables.
PVP.UI.trap_row = PVP.UI.trap_row or {}

local function add_display_card(area, trap)
	local card = Card(area.T.x + area.T.w / 2, area.T.y, G.CARD_W, G.CARD_H, nil, G.P_CENTERS[trap.key])
	-- Both facings: Card:draw reads sprite_facing, Card:hover reads facing.
	card.facing = "back"
	card.sprite_facing = "back"
	card.ability.mp_trap_display = true
	card.ability.mp_trap_row_id = trap.id
	card.states.click.can = false
	card.states.drag.can = false
	-- stay_flipped: emplace otherwise turns a face-down card face-up.
	area:emplace(card, nil, true)
end

-- My view of a fire: the card flips face-up and dissolves where it sits.
local function flip_and_dissolve(card)
	card.ability.mp_trap_row_dissolving = true
	card.states.hover.can = false
	card:flip()
	card:juice_up(0.8, 0.5)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0.9,
		blockable = false,
		func = function()
			card:start_dissolve()
			return true
		end,
	}))
end

-- Make the row match my traps on the Nemesis. The cards are never added to the deck, so they neither
-- calculate nor count for any effect. With no trap list in the view the row stays as it is.
function PVP.UI.trap_row.refresh()
	local area = PVP.NEMESIS.consumeables
	local view = PVP.NET.view
	local traps = PVP.READ.trap.traps(view)
	if not (area and traps) then return end
	local row = PVP.READ.trap.row(traps, view.me, PVP.NEMESIS.ante_ids())
	local wanted = {}
	for _, trap in ipairs(row.shown) do
		wanted[trap.id] = true
	end
	local shown = {}
	local stale = {}
	for _, card in ipairs(area.cards) do
		local id = card.ability.mp_trap_row_id
		-- Phantom jokers share the Nemesis area in Classic: only trap display cards belong to the trap row.
		if card.ability.mp_trap_display and not card.ability.mp_trap_row_dissolving then
			if wanted[id] and not shown[id] then
				shown[id] = true
			else
				stale[#stale + 1] = card
			end
		end
	end
	for _, card in ipairs(stale) do
		if row.fired[card.ability.mp_trap_row_id] then
			flip_and_dissolve(card)
		else
			area:remove_card(card)
			card:remove()
		end
	end
	for _, trap in ipairs(row.shown) do
		if not shown[trap.id] then
			add_display_card(area, trap)
		end
	end
end

-- The traps in the row are all mine, so the hover reads their name and text. Vanilla shows no tooltip on a
-- face-down card, so the hover reads as face-up for the length of the call; the sprite stays face-down.
local card_hover_ref = Card.hover
function Card:hover()
	local ability = self.ability
	if ability and ability.mp_trap_display then
		local facing = self.facing
		self.facing = "front"
		card_hover_ref(self)
		self.facing = facing
		return
	end
	return card_hover_ref(self)
end
