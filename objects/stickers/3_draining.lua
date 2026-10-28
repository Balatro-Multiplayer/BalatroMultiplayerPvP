SMODS.Sticker({
	key = "sticker_draining",
	atlas = "alt_stickers",
	pos = { x = 2, y = 0 },
	badge_colour = HEX("A13333"),
	default_compat = false,
	needs_enable_flag = true,
	calculate = function(self, card, context)
		if card and PVP.is_phantom(card) then return end
		if context.joker_main then return {
			x_mult = 0.75,
		} end
	end,
})
