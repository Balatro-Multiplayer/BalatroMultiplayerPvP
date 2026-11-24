SMODS.Joker({
	key = "farmer_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,

	rarity = 1,
	cost = 6,
	atlas = "ec_jokers_sandbox",
	pos = { x = 9, y = 1 },

	config = { extra = { dollars = 2 }, mp_sticker_extra_credit = true },

	loc_vars = function(self, info_queue, card)
		local current_suit = G.GAME.current_round.farmer_card and G.GAME.current_round.farmer_card.suit or "Spades"
		return {
			vars = {
				card.ability.extra.dollars,
				localize(current_suit, "suits_singular"),
				colours = { G.C.SUITS[current_suit] },
			},
		}
	end,

	calculate = function(self, card, context)
		if
			context.cardarea == G.hand
			and context.end_of_round
			and context.individual
			and not context.repetition
			and context.other_card:is_suit(G.GAME.current_round.farmer_card.suit)
		then
			delay(0.15)
			return {
				dollars = 2,
				card = context.other_card,
			}
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "HonuKane" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
