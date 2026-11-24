SMODS.Joker({
	key = "pyromancer_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,

	rarity = 1,
	cost = 5,
	atlas = "ec_jokers_sandbox",
	pos = { x = 1, y = 3 },

	config = {
		extra = {
			mult = 20,
		},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.mult } }
	end,

	calculate = function(self, card, context)
		if
			context.cardarea == G.jokers
			and context.joker_main
			and G.GAME.current_round.hands_left <= G.GAME.current_round.discards_left
		then
			return {
				message = localize({ type = "variable", key = "a_mult", vars = { card.ability.extra.mult } }),
				mult_mod = card.ability.extra.mult,
			}
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "Wingcap" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
