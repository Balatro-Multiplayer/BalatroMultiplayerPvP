SMODS.Joker({
	key = "golden_ticket_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 2,
	cost = 5,
	pos = { x = 5, y = 3 },
	config = { extra = { dollars = 5, odds = 2 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = G.P_CENTERS.m_gold
		local numerator, denominator =
			SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "j_mp_golden_ticket_sandbox")
		return { vars = { card.ability.extra.dollars, numerator, denominator } }
	end,
	calculate = function(self, card, context)
		if
			context.individual
			and context.cardarea == G.play
			and SMODS.has_enhancement(context.other_card, "m_gold")
		then
			if SMODS.pseudorandom_probability(card, "j_mp_golden_ticket_sandbox", 1, card.ability.extra.odds) then
				G.GAME.dollar_buffer = (G.GAME.dollar_buffer or 0) + card.ability.extra.dollars
				return {
					dollars = card.ability.extra.dollars,
					func = function()
						G.E_MANAGER:add_event(Event({
							func = function()
								G.GAME.dollar_buffer = 0
								return true
							end,
						}))
					end,
				}
			end
		end
	end,
	in_pool = function(self, args)
		return true
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
