SMODS.Joker({
	key = "tuxedo_sandbox",
	no_collection = PVP.sandbox_no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,

	rarity = 2,
	cost = 5,
	atlas = "ec_jokers_sandbox",
	pos = { x = 4, y = 2 },

	config = { extra = { reps = 1 }, mp_sticker_extra_credit = true },

	loc_vars = function(self, info_queue, card)
		local current_suit = G.GAME.current_round.tuxedo_card and G.GAME.current_round.tuxedo_card.suit or "Spades"
		return { vars = { localize(current_suit, "suits_singular"), colours = { G.C.SUITS[current_suit] } } }
	end,

	calculate = function(self, card, context)
		if
			context.cardarea == G.play
			and context.repetition
			and context.other_card:is_suit(G.GAME.current_round.tuxedo_card.suit)
		then
			return {
				message = localize("k_again_ex"),
				repetitions = card.ability.extra.reps,
				card = card,
			}
		elseif
			context.repetition
			and context.cardarea == G.hand
			and context.other_card:is_suit(G.GAME.current_round.tuxedo_card.suit)
		then
			if next(context.card_effects[1]) or #context.card_effects > 1 then
				return {
					message = localize("k_again_ex"),
					repetitions = card.ability.extra.reps,
					card = card,
				}
			end
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "DottyKitty" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
