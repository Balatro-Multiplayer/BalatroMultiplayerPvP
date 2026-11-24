SMODS.Atlas({
	key = "faceless_sandbox",
	path = "j_faceless_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "faceless_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 1,
	cost = 4,
	atlas = "faceless_sandbox",
	config = { extra = { dollars = 15 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.dollars } }
	end,
	calculate = function(self, card, context)
		if context.discard and context.other_card == context.full_hand[#context.full_hand] then
			local jacks = 0
			local queens = 0
			local kings = 0

			for _, discarded_card in ipairs(context.full_hand) do
				local rank = discarded_card:get_id()
				if rank == 11 then jacks = jacks + 1 end
				if rank == 12 then queens = queens + 1 end
				if rank == 13 then kings = kings + 1 end
			end

			if jacks >= 1 and queens >= 1 and kings >= 1 then
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
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
