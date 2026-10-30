SMODS.Sticker({
	key = "sticker_unreliable",
	atlas = "alt_stickers",
	pos = { x = 1, y = 0 },
	badge_colour = HEX("7CA39A"),
	default_compat = false,
	needs_enable_flag = true,
})

local calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context)
	if self.ability.mp_sticker_unreliable and G.GAME.current_round.hands_left == 0 then
		if not PVP.is_phantom(self) then return end
	end
	return calculate_joker_ref(self, context)
end
