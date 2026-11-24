SMODS.Atlas({
	key = "castle_sandbox",
	path = "j_castle_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "castle_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	atlas = "castle_sandbox",
	blueprint_compat = true,
	perishable_compat = false,
	rarity = 2,
	cost = 6,
	config = { extra = { chips = 0, chip_mod = 10, suit = nil }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		local suit = card.ability.extra.suit or G.GAME.current_round.castle_card.suit or "Spades"
		return {
			vars = {
				string.upper(localize(suit, "suits_plural")),
				colours = { G.C.SUITS[suit] },
				card.ability.extra.chips,
				card.ability.extra.chip_mod,
			},
		}
	end,
	calculate = function(self, card, context)
		if
			context.discard
			and not context.blueprint
			and not context.other_card.debuff
			and context.other_card:is_suit(card.ability.extra.suit)
		then
			card.ability.extra.chips = card.ability.extra.chips + card.ability.extra.chip_mod
			return {
				message = localize("k_upgrade_ex"),
				colour = G.C.CHIPS,
			}
		end
		if context.joker_main then return {
			chips = card.ability.extra.chips,
		} end
	end,
	add_to_deck = function(self, card, from_debuff)
		if card.ability.extra.suit == nil then card.ability.extra.suit = G.GAME.current_round.castle_card.suit end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
