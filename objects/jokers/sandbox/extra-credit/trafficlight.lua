-- Traffic Light - Extra Credit Joker ported to Sandbox
-- X2.5 Mult, decreases X1 each hand played, resets after X0.5

SMODS.Joker({
	key = "trafficlight_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	rarity = 2,
	cost = 5,
	atlas = "ec_jokers_sandbox",
	pos = { x = 7, y = 1 },
	config = { extra = { Xmult = 2.5, Xmult_mod = 1 }, mp_sticker_extra_credit = true },

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.Xmult, card.ability.extra.Xmult_mod } }
	end,

	calculate = function(self, card, context)
		if context.cardarea == G.jokers and context.joker_main then
			return {
				message = localize({ type = "variable", key = "a_xmult", vars = { card.ability.extra.Xmult } }),
				Xmult_mod = card.ability.extra.Xmult,
			}
		elseif context.after and not context.blueprint then
			card.ability.extra.Xmult = card.ability.extra.Xmult - card.ability.extra.Xmult_mod

			if card.ability.extra.Xmult < 0.5 then
				card.ability.extra.Xmult = 2.5
				return {
					message = "Go!",
					colour = G.C.GREEN,
				}
			elseif card.ability.extra.Xmult == 1.5 then
				return {
					message = localize({
						type = "variable",
						key = "a_xmult_minus",
						vars = { card.ability.extra.Xmult_mod },
					}),
					colour = G.C.FILTER,
				}
			elseif card.ability.extra.Xmult == 0.5 then
				return {
					message = localize({
						type = "variable",
						key = "a_xmult_minus",
						vars = { card.ability.extra.Xmult_mod },
					}),
					colour = G.C.RED,
				}
			end
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "Wingcap" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
