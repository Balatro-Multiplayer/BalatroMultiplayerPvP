SMODS.Atlas({
	key = "order_sandbox",
	path = "j_order_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "order_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 3,
	cost = 8,
	atlas = "order_sandbox",
	config = { extra = { Xmult = 3, Xmult_mod = 0.5, type = "Straight" }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.Xmult_mod, card.ability.extra.Xmult } }
	end,
	calculate = function(self, card, context)
		if context.before and context.main_eval and not context.blueprint then
			if next(context.poker_hands[card.ability.extra.type]) then
				-- Played a Straight - increase Xmult
				card.ability.extra.Xmult = card.ability.extra.Xmult + card.ability.extra.Xmult_mod
				return {
					message = localize("k_upgrade_ex"),
					colour = G.C.RED,
				}
			else
				-- Didn't play a Straight - reset to base value
				card.ability.extra.Xmult = 3
				return {
					message = localize("k_reset"),
					colour = G.C.RED,
				}
			end
		end
		if context.joker_main and next(context.poker_hands[card.ability.extra.type]) then
			return {
				xmult = card.ability.extra.Xmult,
			}
		end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
