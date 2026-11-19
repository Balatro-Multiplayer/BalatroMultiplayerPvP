-- Vanilla Reserved Parking, except a miss still counts as a trigger, so Mime and Red Seal retrigger a held face card
-- and every trigger rolls again. SMODS.score_card only collects a held card's retriggers, and only runs the next one,
-- when the pass before it did something; vanilla returns nothing on a miss, so a miss cancels every retrigger.
SMODS.Joker({
	key = "reserved_parking",
	no_collection = true,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 1,
	cost = 6,
	pos = { x = 6, y = 13 },
	config = { extra = { odds = 2, dollars = 1 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		local numerator, denominator = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "parking")
		return { key = "j_reserved_parking", vars = { card.ability.extra.dollars, numerator, denominator } }
	end,
	calculate = function(self, card, context)
		if
			context.individual
			and context.cardarea == G.hand
			and not context.end_of_round
			and context.other_card:is_face()
		then
			if not SMODS.pseudorandom_probability(card, "parking", 1, card.ability.extra.odds) then
				-- A silent effect: it shows, pays and wiggles nothing, but SMODS counts it as calculated.
				return { func = function() end, no_juice = true }
			end
			if context.other_card.debuff then
				return {
					message = localize("k_debuffed"),
					colour = G.C.RED,
					card = card,
				}
			end
			G.GAME.dollar_buffer = (G.GAME.dollar_buffer or 0) + card.ability.extra.dollars
			G.E_MANAGER:add_event(Event({
				func = function()
					G.GAME.dollar_buffer = 0
					return true
				end,
			}))
			return {
				dollars = card.ability.extra.dollars,
				card = card,
			}
		end
	end,
})
