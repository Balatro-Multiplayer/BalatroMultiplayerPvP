SMODS.Joker({
	key = "clowncar_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,

	rarity = 3,
	cost = 7,
	atlas = "ec_jokers_sandbox",
	pos = { x = 6, y = 2 },

	config = { extra = { mult = 44, money = 3 }, mp_sticker_extra_credit = true },

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.mult, card.ability.extra.money } }
	end,

	calculate = function(self, card, context)
		if context.initial_scoring_step then
			ease_dollars(-card.ability.extra.money)
			card_eval_status_text(
				card,
				"jokers",
				nil,
				percent,
				nil,
				{ message = "-$" .. tostring(card.ability.extra.money), colour = G.C.MONEY }
			)
			return {
				mult = card.ability.extra.mult,
			}
		end
	end,

	mp_credits = {
		code = { "CampfireCollective", "steph" },
		art = { "R3venantR3mnant" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
