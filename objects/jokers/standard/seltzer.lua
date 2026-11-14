SMODS.Joker({
	key = "seltzer",
	no_collection = true,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = false,
	rarity = 2,
	cost = 6,
	pos = { x = 3, y = 15 },
	config = { extra = { hands_left = 8 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.hands_left } }
	end,
	calculate = function(self, card, context)
		if context.repetition and context.cardarea == G.play then return {
			repetitions = 1,
		} end
		-- after-hand path runs every blind; mp_pvp_loss only matters under a PvP hand timer,
		-- so the clock check sits behind the cheap context field test.
		if (context.after or (context.mp_pvp_loss and PVP.has_pvp_clock())) and not context.blueprint then
			local hands_decrease = context.mp_pvp_loss and context.mp_hands_left or 1
			if card.ability.extra.hands_left - hands_decrease <= 0 then
				SMODS.destroy_cards(card, nil, nil, true)
				return {
					message = localize("k_drank_ex"),
					colour = G.C.FILTER,
				}
			else
				card.ability.extra.hands_left = card.ability.extra.hands_left - hands_decrease
				return {
					message = card.ability.extra.hands_left .. "",
					colour = G.C.FILTER,
				}
			end
		end
	end,
})

-- Under pvp_timer, losing the round to the clock drinks vanilla seltzer by the number of unused hands.
local old_seltzer_calculate = G.P_CENTERS.j_selzer.calculate or function(self, card, context) end
SMODS.Joker:take_ownership("j_selzer", {
	calculate = function(self, card, context)
		-- calculate runs every frame on every on-screen joker; keep the clock check
		-- gated behind the cheap context field test.
		if context.mp_pvp_loss and not context.blueprint and PVP.has_pvp_clock() then
			local hands_decrease = context.mp_hands_left or 1
			if card.ability.extra - hands_decrease <= 0 then
				SMODS.destroy_cards(card, nil, nil, true)
				return {
					message = localize("k_drank_ex"),
					colour = G.C.FILTER,
				}
			else
				card.ability.extra = card.ability.extra - hands_decrease
				return {
					message = card.ability.extra .. "",
					colour = G.C.FILTER,
				}
			end
		end
		return old_seltzer_calculate(self, card, context)
	end,
}, true)
