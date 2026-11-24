SMODS.Atlas({
	key = "loyalty_card_sandbox",
	path = "j_loyalty_card_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "loyalty_card_sandbox",

	unlocked = true,
	discovered = true,
	no_collection = PVP.SANDBOX.no_collection,
	blueprint_compat = true,
	rarity = 2,
	cost = 5,
	atlas = "loyalty_card_sandbox",
	config = { extra = { Xmult = 6, every = 4, loyalty_remaining = 4, poker_hand = "???" }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return {
			vars = {
				card.ability.extra.poker_hand,
				math.abs(card.ability.extra.every - card.ability.extra.loyalty_remaining),
				card.ability.extra.loyalty_remaining,
			},
		}
	end,
	add_to_deck = function(self, card, from_debuff)
		local _poker_hands = {}
		for handname, _ in pairs(G.GAME.hands) do
			if SMODS.is_poker_hand_visible(handname) then _poker_hands[#_poker_hands + 1] = handname end
		end
		card.ability.extra.poker_hand = pseudorandom_element(_poker_hands, "loyalty_card_sandbox")
	end,
	calculate = function(self, card, context)
		if context.before and context.main_eval then
			if context.scoring_name == card.ability.extra.poker_hand then
				-- Played the loyal hand - decrease loyalty_remaining
				if card.ability.extra.loyalty_remaining > 0 then
					card.ability.extra.loyalty_remaining = card.ability.extra.loyalty_remaining - 1
				end
			else
				-- Played a different hand - relationship broken, reset loyalty
				card.ability.extra.loyalty_remaining = card.ability.extra.every
				return {
					message = localize("k_reset"),
					colour = G.C.RED,
				}
			end
		end
		if context.joker_main then
			if not context.blueprint then
				if card.ability.extra.loyalty_remaining == 0 then
					local eval = function(card)
						return card.ability.extra.loyalty_remaining == 0 and not G.RESET_JIGGLES
					end
					juice_card_until(card, eval, true)
				end
			end
			if card.ability.extra.loyalty_remaining == 0 then
				card.ability.extra.loyalty_remaining = card.ability.extra.every
				return {
					xmult = card.ability.extra.Xmult,
				}
			end
		end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
