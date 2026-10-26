local function next_taxes_total_mult_gain(card)
	local sells = PVP.GAME.enemy.sells_per_ante[G.GAME.round_resets.ante] or 0

	-- If PvP hasn't been reached for the first time, accumulate sells from previous Antes
	if G.GAME.round_resets.ante <= PVP.LOBBY.config.pvp_start_round then
		for i = 1, G.GAME.round_resets.ante - 1 do
			sells = sells + (PVP.GAME.enemy.sells_per_ante[i] or 0)
		end
	end

	return sells * card.ability.extra.mult_gain
end

SMODS.Atlas({
	key = "taxes",
	path = "j_taxes.png",
	px = 71,
	py = 95,
})

MPAPI.Joker({
	key = "taxes",
	atlas = "taxes",
	rarity = 1,
	cost = 5,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = false,
	config = { extra = { mult_gain = 4, mult = 0 } },
	loc_vars = function(self, info_queue, card)
		PVP.UTILS.add_nemesis_info(info_queue)
		return { vars = { card.ability.extra.mult_gain, card.ability.extra.mult } }
	end,
	calculate = function(self, card, context)
		-- §18.2: opponent sold a card, told to us via MPAPI.broadcast_opponent_context
		-- (overrides/game.lua's Card:sell_card) -- was previously its own bespoke
		-- receive handler (action_sold_joker).
		if context.opponent_selling_card then
			if PVP.is_byed() then
				return
			end
			local target = PVP.current_target_id()
			if target and context.from ~= target then
				return
			end
			PVP.GAME.enemy.sells = PVP.GAME.enemy.sells + 1
			PVP.GAME.enemy.sells_per_ante[G.GAME.round_resets.ante] = (PVP.GAME.enemy.sells_per_ante[G.GAME.round_resets.ante] or 0)
				+ 1
			return
		end
		if context.cardarea == G.jokers and context.joker_main then
			return {
				mult = card.ability.extra.mult,
			}
		elseif
			context.cardarea == G.jokers
			and context.setting_blind
			and not context.blueprint
			and context.blind.key == "bl_mp_nemesis"
		then
			card.ability.extra.mult = card.ability.extra.mult + next_taxes_total_mult_gain(card)
			return {
				message = localize("k_filed_ex"),
			}
		end
	end,
	mp_credits = {
		idea = { "Zwei" },
		art = { "DottyKitty" },
		code = { "Virtualized" },
	},
})
