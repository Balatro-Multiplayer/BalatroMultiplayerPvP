-- Double Rainbow - Extra Credit Joker ported to Sandbox
-- Retrigger all Lucky Cards

SMODS.Joker({
	key = "doublerainbow_sandbox",
	no_collection = PVP.sandbox_no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	enhancement_gate = "m_lucky",
	rarity = 2,
	cost = 5,
	atlas = "ec_jokers_sandbox",
	pos = { x = 1, y = 0 },
	config = { extra = 1, mp_sticker_extra_credit = true },

	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = G.P_CENTERS.m_lucky
		return {}
	end,

	calculate = function(self, card, context)
		if
			context.repetition
			and context.cardarea == G.play
			and SMODS.get_enhancements(context.other_card)["m_lucky"] == true
		then
			return {
				message = localize("k_again_ex"),
				repetitions = 1,
				card = card,
			}
		elseif
			context.repetition
			and context.cardarea == G.hand
			and SMODS.get_enhancements(context.other_card)["m_lucky"] == true
		then
			if next(context.card_effects[1]) or #context.card_effects > 1 then
				return {
					message = localize("k_again_ex"),
					repetitions = card.ability.extra,
					card = card,
				}
			end
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "DottyKitty" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
