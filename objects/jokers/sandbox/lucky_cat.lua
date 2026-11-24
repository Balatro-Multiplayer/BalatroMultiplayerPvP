SMODS.Atlas({
	key = "lucky_cat_sandbox",
	path = "j_lucky_cat_sandbox.png",
	px = 71,
	py = 95,
})
SMODS.Joker({
	key = "lucky_cat_sandbox",

	unlocked = true,
	discovered = true,
	no_collection = PVP.SANDBOX.no_collection,
	atlas = "lucky_cat_sandbox",
	blueprint_compat = true,
	perishable_compat = false,
	rarity = 2,
	cost = 6,
	config = { extra = { Xmult_gain = 0.25, Xmult = 1 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = G.P_CENTERS.m_lucky

		return { vars = { card.ability.extra.Xmult_gain, card.ability.extra.Xmult } }
	end,
	calculate = function(self, card, context)
		if
			context.individual
			and context.cardarea == G.play
			and context.other_card.lucky_trigger
			and not context.blueprint
		then
			card.ability.extra.Xmult = card.ability.extra.Xmult + card.ability.extra.Xmult_gain
			if SMODS.pseudorandom_probability(card, "j_lucky_cat_mp_sandbox", 1, 4) then
				context.other_card:set_ability("m_glass", nil, true)
			end
			return {
				message = localize("k_upgrade_ex"),
				colour = G.C.MULT,
				message_card = card,
			}
		end
		if context.joker_main then return {
			xmult = card.ability.extra.Xmult,
		} end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
