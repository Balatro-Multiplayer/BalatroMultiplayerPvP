SMODS.Atlas({
	key = "hit_the_road_sandbox",
	path = "j_hit_the_road_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "hit_the_road_sandbox",
	no_collection = PVP.SANDBOX.no_collection,

	unlocked = true,
	discovered = true,

	blueprint_compat = true,
	rarity = 3,
	cost = 8,
	atlas = "hit_the_road_sandbox",
	config = { extra = { xmult_gain = 0.75, xmult = 1 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.xmult_gain, card.ability.extra.xmult } }
	end,
	calculate = function(self, card, context)
		if
			context.discard
			and not context.blueprint
			and not context.other_card.debuff
			and context.other_card:get_id() == 11
		then
			card.ability.extra.xmult = card.ability.extra.xmult + card.ability.extra.xmult_gain
			return {
				message = localize({ type = "variable", key = "a_xmult", vars = { card.ability.extra.xmult } }),
				colour = G.C.RED,
				remove = true,
			}
		end
		if context.joker_main then return {
			xmult = card.ability.extra.xmult,
		} end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
