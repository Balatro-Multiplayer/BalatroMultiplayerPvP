-- this is kinda strange but we can just override the logic for pvp only rather than re-implementing it again, bc if we don't return anything, it'll run the normal logic

SMODS.Joker({
	key = "bloodstone",
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	perishable_compat = true,
	eternal_compat = true,
	rarity = 2,
	cost = 7,
	pos = { x = 0, y = 8 },
	no_collection = true,
	config = { extra = { odds = 2, Xmult = 1.5 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		-- Through SMODS so an opponent's Bloodstone shows its odds without this player's Oops! All 6s.
		local numerator, denominator = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "j_bloodstone")
		return {
			key = "j_bloodstone",
			vars = {
				numerator,
				denominator,
				card.ability.extra.Xmult,
			},
		}
	end,
	calculate = function(self, card, context)
		if PVP.is_pvp_boss() then
			if not context.blueprint then
				if context.before then
					G.GAME.round_resets.mp_bloodstone = G.GAME.round_resets.mp_bloodstone or {}
					G.GAME.round_resets.mp_bloodstone[PVP.order_round_based(true)] = G.GAME.round_resets.mp_bloodstone[PVP.order_round_based(
						true
					)] or {}
					G.GAME.round_resets.mp_bsindex = 0
				end
			end
			if context.individual and context.cardarea == G.play then
				if context.other_card:is_suit("Hearts") then
					local stored_queue = G.GAME.round_resets.mp_bloodstone[PVP.order_round_based(true)]
					G.GAME.round_resets.mp_bsindex = G.GAME.round_resets.mp_bsindex + 1 -- increment before indexing
					stored_queue[G.GAME.round_resets.mp_bsindex] = stored_queue[G.GAME.round_resets.mp_bsindex]
						or pseudorandom("bloodstone" .. PVP.order_round_based(true))
					if
						stored_queue[G.GAME.round_resets.mp_bsindex]
						< G.GAME.probabilities.normal / card.ability.extra.odds
					then
						return {
							x_mult = card.ability.extra.Xmult,
							card = card,
						}
					end
				end
			end
		elseif context.individual and context.cardarea == G.play then
			if
				context.other_card:is_suit("Hearts")
				and pseudorandom("bloodstone") < G.GAME.probabilities.normal / card.ability.extra.odds
			then
				return {
					x_mult = card.ability.extra.Xmult,
					card = card,
				}
			end
		end
	end,
})
