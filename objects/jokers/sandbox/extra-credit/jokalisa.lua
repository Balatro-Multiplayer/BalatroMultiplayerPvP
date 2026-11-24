SMODS.Joker({
	key = "jokalisa_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = false,

	rarity = 3,
	cost = 8,
	atlas = "ec_jokers_sandbox",
	pos = { x = 3, y = 3 },

	config = {
		extra = {
			Xmult = 1,
			Xmult_mod = 0.1,
		},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.Xmult, card.ability.extra.Xmult_mod } }
	end,

	calculate = function(self, card, context)
		local contains = function(table_, value)
			for _, v in pairs(table_) do
				if v == value then return true end
			end
			return false
		end

		if context.before and not context.blueprint then
			local enhanced = {}
			for i = 1, #context.scoring_hand do
				for k, v in pairs(SMODS.get_enhancements(context.scoring_hand[i])) do
					if v then
						if not contains(enhanced, k) then enhanced[#enhanced + 1] = k end
					end
				end
			end
			if #enhanced > 0 then
				card.ability.extra.Xmult = card.ability.extra.Xmult + (card.ability.extra.Xmult_mod * #enhanced)
				return {
					message = localize({ type = "variable", key = "a_xmult", vars = { card.ability.extra.Xmult } }),
					card = card,
					colour = G.C.RED,
				}
			end
		elseif context.cardarea == G.jokers and context.joker_main and card.ability.extra.Xmult > 1 then
			return {
				message = localize({ type = "variable", key = "a_xmult", vars = { card.ability.extra.Xmult } }),
				Xmult_mod = card.ability.extra.Xmult,
			}
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "R3venantR3mnant" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
