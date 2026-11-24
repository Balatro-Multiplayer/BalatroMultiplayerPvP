SMODS.Atlas({
	key = "steel_joker_sandbox",
	path = "j_steel_joker_sandbox.png",
	px = 71,
	py = 95,
})
SMODS.Joker({
	key = "steel_joker_sandbox",
	no_collection = PVP.SANDBOX.no_collection,

	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 2,
	cost = 7,
	atlas = "steel_joker_sandbox",
	config = { extra = { repetitions = 1 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = G.P_CENTERS.m_steel
	end,
	calculate = function(self, card, context)
		if
			context.repetition
			and context.cardarea == G.play
			and SMODS.has_enhancement(context.other_card, "m_steel")
		then
			return {
				repetitions = card.ability.extra.repetitions,
			}
		end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
