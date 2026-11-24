SMODS.Atlas({
	key = "photograph_sandbox",
	path = "j_photograph_sandbox.png",
	px = 71,
	py = 95,
})
SMODS.Joker({
	key = "photograph_sandbox",
	no_collection = PVP.SANDBOX.no_collection,

	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	atlas = "photograph_sandbox",
	rarity = 1,
	cost = 5,
	pixel_size = { h = 95 / 1.2 },
	config = { extra = { xmult = 4 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.xmult } }
	end,
	calculate = function(self, card, context)
		if context.individual and context.cardarea == G.play then
			local face_count = 0
			for i = 1, #context.scoring_hand do
				if context.scoring_hand[i]:is_face() then face_count = face_count + 1 end
			end

			if face_count == 1 and context.other_card:is_face() then
				return {
					xmult = card.ability.extra.xmult,
				}
			end
		end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
