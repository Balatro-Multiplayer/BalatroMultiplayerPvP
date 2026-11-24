SMODS.Joker({
	key = "werewolf_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = true,

	rarity = 2,
	cost = 5,
	atlas = "ec_jokers_sandbox",
	pos = { x = 1, y = 2 },

	config = {
		extra = {},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = G.P_CENTERS.m_wild
		return { vars = {} }
	end,

	calculate = function(self, card, context)
		if context.before and not context.blueprint then
			local thunk = 0
			local contains = function(table_, value)
				for _, v in pairs(table_) do
					if v == value then return true end
				end
				return false
			end

			for k, v in ipairs(context.full_hand) do
				if contains(SMODS.get_enhancements(v), true) and v.config.center.key ~= "m_wild" then
					thunk = thunk + 1
					v:set_ability(G.P_CENTERS.m_wild, nil, true)
					G.E_MANAGER:add_event(Event({
						func = function()
							v:juice_up()
							return true
						end,
					}))
				end
			end
			if thunk > 0 then return {
				message = "Awooo!",
				colour = G.C.PURPLE,
			} end
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "bishopcorrigan", "splatter_proto" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
