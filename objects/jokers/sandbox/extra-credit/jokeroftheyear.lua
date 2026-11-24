SMODS.Joker({
	key = "jokeroftheyear_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,

	rarity = 3,
	cost = 9,
	atlas = "ec_jokers_sandbox",
	pos = { x = 5, y = 3 },

	config = {
		extra = {
			reps = 1,
		},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		return {}
	end,

	calculate = function(self, card, context)
		if context.cardarea == G.play and context.repetition and #context.scoring_hand == 5 then
			return {
				message = localize("k_again_ex"),
				repetitions = card.ability.extra.reps,
				card = card,
			}
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "neatoqueen" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
