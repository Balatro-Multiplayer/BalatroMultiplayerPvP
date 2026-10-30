-- Decrease a scored playing card's rank by 1, floored at 2 (mirrors Strength's own
-- rank+1 pattern in card.lua, inverted).
local RANK_SUFFIX = { [10] = "T", [11] = "J", [12] = "Q", [13] = "K", [14] = "A" }
function PVP.TRAP.decrease_rank(playing_card)
	local suit_prefix = string.sub(playing_card.base.suit, 1, 1) .. "_"
	local id = math.max(2, playing_card.base.id - 1)
	local rank_suffix = RANK_SUFFIX[id] or tostring(id)
	playing_card:set_base(G.P_CARDS[suit_prefix .. rank_suffix])
end

-- The trap itself answers only one destroy_card context (fire_once), so a trap that must break
-- several cards marks them with mp_trap_break and the cards answer for themselves.
local calculate_enhancement_ref = Card.calculate_enhancement
function Card:calculate_enhancement(context)
	if self.ability and self.ability.mp_trap_break and context.destroy_card == self and context.cardarea == G.play then
		return { remove = true }
	end
	return calculate_enhancement_ref(self, context)
end

