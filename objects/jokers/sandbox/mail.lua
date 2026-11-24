-- Pausing this because baby steps
SMODS.Atlas({
	key = "mail_sandbox",
	path = "j_mail_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "mail_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 1,
	cost = 4,
	atlas = "mail_sandbox",
	config = { extra = { dollars = 5, rank = nil, card_id = nil }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		local rank = card.ability.extra.rank or (G.GAME.current_round.mail_card or {}).rank or "Ace"
		return {
			vars = {
				card.ability.extra.dollars,
				localize(rank, "ranks"),
			},
		}
	end,
	add_to_deck = function(self, card, from_debuff)
		-- Don't overwrite rank/card_id if card is re-added after debuff
		if card.ability.extra.rank == nil then
			card.ability.extra.rank = G.GAME.current_round.mail_card.rank
			card.ability.extra.card_id = G.GAME.current_round.mail_card.id
		end
	end,
	calculate = function(self, card, context)
		if
			context.discard
			and not context.other_card.debuff
			and context.other_card:get_id() == card.ability.extra.card_id
		then
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
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
