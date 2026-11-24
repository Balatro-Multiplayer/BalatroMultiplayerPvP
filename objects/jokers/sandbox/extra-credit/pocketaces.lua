-- Pocket Aces - Extra Credit Joker ported to Sandbox
-- Gives $ at end of round, played Aces increase payout, resets each Ante

SMODS.Joker({
	key = "pocketaces_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = true,
	perishable_compat = true,
	rarity = 2,
	cost = 7,
	atlas = "ec_jokers_sandbox",
	pos = { x = 5, y = 0 },
	config = { extra = { money = 0, m_gain = 2 }, mp_sticker_extra_credit = true },

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.money, card.ability.extra.m_gain } }
	end,

	calc_dollar_bonus = function(self, card)
		local thunk = card.ability.extra.money
		if G.GAME.blind.boss then card.ability.extra.money = 0 end
		return thunk
	end,

	calculate = function(self, card, context)
		if
			context.individual
			and context.cardarea == G.play
			and context.other_card:get_id() == 14
			and not context.blueprint
		then
			card.ability.extra.money = card.ability.extra.money + card.ability.extra.m_gain
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "Wingcap" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
