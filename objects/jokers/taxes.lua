-- The sells of my Nemesis are recorded by the server (pvp.opponent), per ante, as each sell happens; Taxes only
-- reads them (PVP.OpponentNet.nemesis_sells). nil when the server has not said yet: nothing is added then,
-- never a guessed 0.
local function next_taxes_total_mult_gain(card)
	local sells = PVP.OpponentNet.nemesis_sells()
	if sells == nil then
		PVP.match_log("info", "[pvp] Taxes: the Nemesis' sells are not known yet, nothing added")
		return nil
	end
	return PVP.OPPONENT_RECORD.taxes_mult_gain(
		sells,
		G.GAME.round_resets.ante,
		PVP.LOBBY.config.pvp_start_round,
		card.ability.extra.mult_gain
	)
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
			local gain = next_taxes_total_mult_gain(card)
			if gain == nil then return end
			card.ability.extra.mult = card.ability.extra.mult + gain
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
