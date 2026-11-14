-- Under pvp_timer, losing the round to the clock melts ice cream by chip_mod * unused hands.
local old_ice_cream_calculate = G.P_CENTERS.j_ice_cream.calculate or function(self, card, context) end
SMODS.Joker:take_ownership("j_ice_cream", {
	calculate = function(self, card, context)
		-- calculate runs every frame on every on-screen joker; keep the clock check
		-- gated behind the cheap context field test.
		if context.mp_pvp_loss and not context.blueprint and PVP.has_pvp_clock() then
			local hands_decrease = context.mp_hands_left or 1
			local chips_decrease = card.ability.extra.chip_mod * hands_decrease
			if card.ability.extra.chips - chips_decrease <= 0 then
				SMODS.destroy_cards(card, nil, nil, true)
				return {
					message = localize("k_melted_ex"),
					colour = G.C.CHIPS,
				}
			else
				card.ability.extra.chips = card.ability.extra.chips - chips_decrease
				return {
					message = localize({ type = "variable", key = "a_chips_minus", vars = { chips_decrease } }),
					colour = G.C.CHIPS,
				}
			end
		end
		return old_ice_cream_calculate(self, card, context)
	end,
}, true)
