SMODS.Joker({
	key = "gofish_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = true,
	rarity = 2,
	cost = 6,
	atlas = "ec_jokers_sandbox",
	pos = { x = 9, y = 2 },

	config = { extra = { fished = false }, mp_sticker_extra_credit = true },

	loc_vars = function(self, info_queue, card)
		local current_rank = G.GAME.current_round.fish_rank and G.GAME.current_round.fish_rank.rank or "Ace"
		return { vars = { current_rank } }
	end,

	calculate = function(self, card, context)
		if context.first_hand_drawn and not context.blueprint then
			card.ability.extra.fished = false
			juice_card_until(card, function()
				return not card.ability.extra.fished
			end, true)
		elseif context.before and not context.blueprint and not card.ability.extra.fished then
			for _, scoring_card in ipairs(context.scoring_hand) do
				if scoring_card.base.value == G.GAME.current_round.fish_rank.rank and not scoring_card.debuff then
					card.ability.extra.fish = card.ability.extra.fish or {}
					card.ability.extra.fish[#card.ability.extra.fish + 1] = scoring_card
					card.ability.extra.fished = true
				end
			end
		elseif context.after and not context.blueprint and card.ability.extra.fish then
			for _, target in ipairs(card.ability.extra.fish) do
				SMODS.destroy_cards(target)
			end
			card.ability.extra.fish = nil
		elseif context.end_of_round then
			card.ability.extra.fished = true
		end
	end,

	mp_credits = {
		code = { "CampfireCollective", "steph" },
		art = { "bishopcorrigan" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
