FNSJ.simulate_mp_defensive_joker = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.t_chips) end
end

FNSJ.simulate_mp_taxes = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.extra.mult) end
end

FNSJ.simulate_mp_pacifist = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global and not PVP.is_pvp_boss() then
		FN.SIM.x_mult(joker_obj.ability.extra.x_mult)
	end
end

FNSJ.simulate_mp_conjoined_joker = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global and PVP.is_pvp_boss() then
		FN.SIM.x_mult(joker_obj.ability.extra.x_mult)
	end
end

FNSJ.simulate_mp_hanging_chad = function(joker_obj, context)
	if context.cardarea == G.play and context.repetition then
		if context.other_card == context.scoring_hand[1] and not context.other_card.debuff then
			FN.SIM.add_reps(joker_obj.ability.extra)
		end
		if context.other_card == context.scoring_hand[2] and not context.other_card.debuff then
			FN.SIM.add_reps(joker_obj.ability.extra)
		end
	end
end

FNSJ.simulate_mp_lets_go_gambling = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local rand = pseudorandom("gambling") -- Must reuse same pseudorandom value:
		local exact_xmult, min_xmult, max_xmult =
			FN.SIM.get_probabilistic_extremes(rand, joker_obj.ability.extra.odds, joker_obj.ability.extra.xmult, 1)
		local exact_money, min_money, max_money =
			FN.SIM.get_probabilistic_extremes(rand, joker_obj.ability.extra.odds, joker_obj.ability.extra.dollars, 0)

		FN.SIM.add_dollars(exact_money, min_money, max_money)
		FN.SIM.x_mult(exact_xmult, min_xmult, max_xmult)
	end
end

FNSJ.simulate_mp_seltzer = function(joker_obj, context)
	if context.cardarea == G.play and context.repetition then FN.SIM.add_reps(1) end
end

FNSJ.simulate_mp_bloodstone = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_suit(context.other_card, "Hearts") and not context.other_card.debuff then
			local exact_xmult, min_xmult, max_xmult = FN.SIM.get_probabilistic_extremes(
				pseudorandom("nopeagain"),
				joker_obj.ability.extra.odds,
				joker_obj.ability.extra.Xmult,
				1
			)
			FN.SIM.x_mult(exact_xmult, min_xmult, max_xmult)
		end
	end
end

-- The engine already rolls on every retrigger, which is how the mp version plays.
FNSJ.simulate_mp_reserved_parking = function(joker_obj, context)
	return FNSJ.simulate_reserved_parking(joker_obj, context)
end
