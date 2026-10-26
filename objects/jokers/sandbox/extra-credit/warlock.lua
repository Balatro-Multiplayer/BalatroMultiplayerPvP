-- Warlock - Extra Credit Joker ported to Sandbox
-- Lucky Cards have chance to be destroyed and spawn a Spectral Card

SMODS.Joker({
	key = "warlock_sandbox",
	no_collection = PVP.sandbox_no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	enhancement_gate = "m_lucky",
	rarity = 2,
	cost = 7,
	atlas = "ec_jokers_sandbox",
	pos = { x = 6, y = 0 },
	config = { extra = { odds = 7, succeed = false }, mp_sticker_extra_credit = true },

	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = G.P_CENTERS.m_lucky
		local num, denom = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "j_mp_warlock_sandbox")
		return { vars = { num, denom } }
	end,

	calculate = function(self, card, context)
		if
			context.cardarea == G.play
			and context.individual
			and SMODS.get_enhancements(context.other_card)["m_lucky"] == true
		then
			if SMODS.pseudorandom_probability(card, "j_mp_warlock_sandbox", 1, card.ability.extra.odds) then
				card.ability.extra.succeed = true
			end
		end

		if context.cardarea == G.jokers and context.after and card.ability.extra.succeed then
			card.ability.extra.succeed = false

			if #G.consumeables.cards < G.consumeables.config.card_limit then
				-- Find and destroy a random lucky card from the played hand
				local lucky_cards = {}
				for _, played_card in ipairs(context.scoring_hand or {}) do
					if SMODS.get_enhancements(played_card)["m_lucky"] then table.insert(lucky_cards, played_card) end
				end

				if #lucky_cards > 0 then
					local target = pseudorandom_element(lucky_cards, pseudoseed("warlock_target"))
					G.E_MANAGER:add_event(Event({
						func = function()
							play_sound("tarot1")
							target.T.r = -0.2
							target:juice_up(0.3, 0.4)
							return true
						end,
					}))

					SMODS.destroy_cards(target)

					G.E_MANAGER:add_event(Event({
						trigger = "after",
						delay = 0.4,
						func = function()
							local spectral =
								pseudorandom_element(G.P_CENTER_POOLS.Spectral, pseudoseed("warlock_spectral"))
							SMODS.add_card({ set = "Spectral", key = spectral.key })
							return true
						end,
					}))

					return {
						message = localize("k_plus_spectral"),
						colour = G.C.SECONDARY_SET.Spectral,
					}
				end
			end
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "DottyKitty" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
