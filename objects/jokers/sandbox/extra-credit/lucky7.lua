SMODS.Joker({
	key = "lucky7_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = true,

	rarity = 1,
	cost = 6,
	atlas = "ec_jokers_sandbox",
	pos = { x = 7, y = 3 },

	config = {
		extra = {
			lucky = false,
			checked = false,
		},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = G.P_CENTERS.m_lucky
		return
	end,

	calculate = function(self, card, context)
		if context.before and not context.blueprint then
			local has_seven = false
			for i = 1, #context.scoring_hand do
				if context.scoring_hand[i]:get_id() == 7 and not context.scoring_hand[i].debuff then
					has_seven = true
					break
				end
			end

			-- enh_cache abuse hours. it's fine. it's better than injection.
			-- we're healing.
			if has_seven then
				for i = 1, #context.scoring_hand do
					context.scoring_hand[i].gambling = true
					if SMODS.enh_cache and SMODS.enh_cache.write then
						SMODS.enh_cache:write(context.scoring_hand[i], nil)
					end
				end
			end
		end

		if context.check_enhancement then
			if context.other_card.gambling then return {
				m_lucky = true,
			} end
		end

		if context.after then
			for i = 1, #context.scoring_hand do
				context.scoring_hand[i].gambling = nil
			end
		end
	end,

	mp_credits = {
		code = { "CampfireCollective", "steph" },
		art = { "bishopcorrigan" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
