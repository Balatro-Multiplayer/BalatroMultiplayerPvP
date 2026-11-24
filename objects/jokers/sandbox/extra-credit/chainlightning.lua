SMODS.Joker({
	key = "chainlightning_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,

	rarity = 3,
	cost = 9,
	atlas = "ec_jokers_sandbox",
	pos = { x = 2, y = 3 },

	config = {
		extra = {
			Xmult = 1,
			Xmult_mod = 0.1,
			total = 0,
			so_far = 0,
		},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.Xmult, card.ability.extra.Xmult_mod } }
	end,

	calculate = function(self, card, context)
		if context.before then
			card.ability.extra.Xmult = 1
			card.ability.extra.total = card.ability.extra.total + 1
			card.ability.extra.so_far = 0
		elseif
			context.cardarea == G.play
			and context.individual
			and context.other_card.config.center.key == "m_mult"
		then
			local thunk = card.ability.extra.Xmult
			card.ability.extra.so_far = card.ability.extra.so_far + 1

			if card.ability.extra.so_far == card.ability.extra.total then
				card.ability.extra.Xmult = card.ability.extra.Xmult + card.ability.extra.Xmult_mod
				card.ability.extra.so_far = 0
			end

			if thunk > 1 then return {
				x_mult = thunk,
				card = card,
			} end
		elseif context.after then
			card.ability.extra.total = 0
			card.ability.extra.Xmult = 1
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
