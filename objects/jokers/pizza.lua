SMODS.Atlas({
	key = "pizza",
	path = "j_pizza.png",
	px = 71,
	py = 95,
})

MPAPI.Joker({
	key = "pizza",
	atlas = "pizza",
	rarity = 1,
	cost = 4,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = false,
	perishable_compat = true,
	config = { extra = { discards = 2, discards_nemesis = 1 } },
	-- Shows a display-only copy on the opponent's board (framework wires add/remove_from_deck).
	phantom = true,
	loc_vars = function(self, info_queue, card)
		PVP.UTILS.add_nemesis_info(info_queue)
		return { vars = { card.ability.extra.discards, card.ability.extra.discards_nemesis } }
	end,
	-- Opponent receives the discard count directly: gains discards this round (was action_eat_pizza).
	receive = function(self, context)
		local discards = context.data
		PVP.RLOG.record(MPAPI.OPCODE.NET_PIZZA, discards, "action:netPizza,discards:" .. tostring(discards))
		PVP.GAME.pizza_discards = PVP.GAME.pizza_discards + discards
		G.GAME.round_resets.discards = G.GAME.round_resets.discards + discards
		ease_discard(discards)
	end,
	calculate = function(self, card, context)
		if context.mp_end_of_pvp and not context.blueprint and not PVP.is_phantom(card) then
			PVP.GAME.pizza_discards = PVP.GAME.pizza_discards + card.ability.extra.discards
			G.GAME.round_resets.discards = G.GAME.round_resets.discards + card.ability.extra.discards
			ease_discard(card.ability.extra.discards)
			card:remove_from_deck()
			card:start_dissolve({ G.C.RED }, nil, 1.6)
			return {
				send = card.ability.extra.discards_nemesis,
				message = localize("k_eaten_ex"),
				colour = G.C.RED,
			}
		end
	end,
	mp_credits = {
		idea = { "Virtualized" },
		art = { "TheTrueRaven" },
		code = { "Virtualized" },
	},
})
