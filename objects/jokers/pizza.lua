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
	-- The other players get { amount, ante }: discards for the ante after the PvP blind
	-- (lib/pizza.lua). A plain number is an older message, added at once.
	receive = function(self, context)
		local data = context.data
		local discards, ante = data, nil
		if type(data) == "table" then
			discards, ante = data.amount, data.ante
		end
		discards = tonumber(discards)
		if not discards or discards <= 0 then return end
		PVP.RLOG.record(MPAPI.OPCODE.NET_PIZZA, discards, "action:netPizza,discards:" .. tostring(discards))
		PVP.PIZZA.receive(discards, tonumber(ante))
	end,
	calculate = function(self, card, context)
		if context.blueprint or PVP.is_phantom(card) then return end
		-- The ante of the PvP blind, kept on the card (and in its save) for the message below.
		if context.setting_blind and PVP.is_pvp_boss() then
			card.ability.extra.pvp_ante = G.GAME.round_resets.ante
		end
		if context.mp_end_of_pvp then
			PVP.PIZZA.add_discards(card.ability.extra.discards)
			-- Both count for the ante after the PvP blind; the eater's ante-up has already run here.
			local ante = card.ability.extra.pvp_ante and card.ability.extra.pvp_ante + 1 or PVP.PIZZA.my_ante()
			card:remove_from_deck()
			card:start_dissolve({ G.C.RED }, nil, 1.6)
			return {
				send = { amount = card.ability.extra.discards_nemesis, ante = ante },
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
