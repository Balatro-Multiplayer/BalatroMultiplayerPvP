SMODS.Atlas({
	key = "penny_pincher",
	path = "j_penny_pincher.png",
	px = 71,
	py = 95,
})

MPAPI.Joker({
	key = "penny_pincher",
	atlas = "penny_pincher",
	rarity = 1,
	cost = 4,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = true,
	perishable_compat = true,
	config = { extra = { dollars = 1, nemesis_dollars = 3 } },
	loc_vars = function(self, info_queue, card)
		PVP.UTILS.add_nemesis_info(info_queue)
		return { vars = { card.ability.extra.dollars, card.ability.extra.nemesis_dollars } }
	end,
	in_pool = function(self)
		return PVP.GAME.pincher_unlock -- do NOT replace this with G.GAME.round_resets.ante >= 3, order sets ante to 0
	end,
	-- The opponent's shop spending is recorded once, outside any joker
	-- (pvp_api/actions/opponent_context.lua); Penny Pincher only reads it.
	calc_dollar_bonus = function(self, card)
		local money = PVP.OPPONENT_RECORD.pincher_payout(
			PVP.GAME.enemy.spent_in_shop,
			PVP.GAME.pincher_index,
			card.ability.extra.nemesis_dollars,
			card.ability.extra.dollars
		)
		if money > 0 then return money end
	end,
	mp_credits = {
		idea = { "Nxkoozie" },
		art = { "Coo29" },
		code = { "Virtualized" },
	},
})
