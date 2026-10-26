-- Preserve the vanilla keys and card behavior; this package only changes odds.
PVP.ReworkCenter("j_8_ball", {
	layers = "dice_patch",
	config = { extra = 3 },
})

PVP.ReworkCenter("j_space", {
	layers = "dice_patch",
	config = { extra = 3 },
})

PVP.ReworkCenter("j_oops", {
	layers = "dice_patch",
	config = { extra = 1.75 },
	loc_key = "j_mp_oops_dice_patch",
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra } }
	end,
	-- Vanilla still multiplies the legacy probability table by 2. SMODS
	-- cancels that factor when calculating listed probabilities, so adjust
	-- the legacy table here rather than applying a second context multiplier.
	add_to_deck = function(self, card)
		for key, value in pairs(G.GAME.probabilities) do
			G.GAME.probabilities[key] = value * card.ability.extra / 2
		end
	end,
	remove_from_deck = function(self, card)
		for key, value in pairs(G.GAME.probabilities) do
			G.GAME.probabilities[key] = value * 2 / card.ability.extra
		end
	end,
})

PVP.ReworkCenter("m_lucky", {
	layers = "dice_patch",
	config = { mult = 20, p_dollars = 20, pvp_money_odds = 10 },
})

-- Vanilla hard-codes Lucky's money denominator in both the roll and tooltip.
-- Route both through the same reworked config, before probability modifiers.
local probability_vars_ref = SMODS.get_probability_vars
function SMODS.get_probability_vars(trigger_obj, numerator, denominator, identifier, from_roll, no_mod)
	if identifier == "lucky_money" and not no_mod and PVP.is_layer_active("dice_patch") then
		denominator = G.P_CENTERS.m_lucky.config.pvp_money_odds or denominator
	end
	return probability_vars_ref(trigger_obj, numerator, denominator, identifier, from_roll, no_mod)
end
