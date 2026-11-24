SMODS.Joker({
	key = "hoarder_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = true,

	rarity = 2,
	cost = 5,
	atlas = "ec_jokers_sandbox",
	pos = { x = 9, y = 3 },

	config = {
		extra = 1,

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra } }
	end,

	mp_credits = {
		code = { "CampfireCollective", "steph" },
		art = { "neatoqueen" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
