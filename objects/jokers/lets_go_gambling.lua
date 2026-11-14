SMODS.Atlas({
	key = "lets_go_gambling",
	path = "j_lets_go_gambling.png",
	px = 71,
	py = 95,
})

MPAPI.Joker({
	key = "lets_go_gambling",
	atlas = "lets_go_gambling",
	rarity = 2,
	cost = 6,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = true,
	config = { extra = { odds = 4, xmult = 4, dollars = 10, nemesis_odds = 4, nemesis_dollars = 10 } },
	-- Shows a display-only copy on the opponent's board (framework wires add/remove_from_deck).
	phantom = true,
	-- The Nemesis' misfire dollars are the server's (pvp.effect gambling, applied by pvp_api/effects_net.lua).
	loc_vars = function(self, info_queue, card)
		local numerator, denominator =
			SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "j_mp_lets_go_gambling")
		local nem_numerator, nem_denominator =
			SMODS.get_probability_vars(card, 1, card.ability.extra.nemesis_odds, "j_mp_lets_go_gambling_misfire")
		return {
			vars = {
				numerator,
				denominator,
				card.ability.extra.xmult,
				card.ability.extra.dollars,
				nem_numerator,
				nem_denominator,
				card.ability.extra.nemesis_dollars,
			},
		}
	end,
	calculate = function(self, card, context)
		if
			context.cardarea == G.jokers
			and context.joker_main
			and not PVP.is_phantom(card)
		then
			local returns = nil
			if SMODS.pseudorandom_probability(card, "j_mp_lets_go_gambling", 1, card.ability.extra.odds) then
				returns = {}
				returns.x_mult = card.ability.extra.xmult
				returns.dollars = card.ability.extra.dollars
			end
			if
				PVP.is_pvp_boss()
				and SMODS.pseudorandom_probability(
					card,
					"j_mp_lets_go_gambling_misfire",
					1,
					card.ability.extra.nemesis_odds
				)
			then
				returns = returns or {}
				PVP.EffectsNet.send_effect("gambling")
				returns.message = localize("k_oops_ex")
			end
			return returns
		end
	end,
	mp_credits = {
		idea = { "Dr. Monty" },
		art = { "Carter" },
		code = { "Virtualized" },
	},
})
