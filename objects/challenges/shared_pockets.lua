-- Effect lives in layers/shared_pockets.lua (via rules.custom -> mp_shared_pockets).
SMODS.Challenge({
	key = "shared_pockets",
	rules = {
		custom = {
			{ id = "mp_shared_pockets" },
		},
	},
	restrictions = {
		banned_cards = {
			{ id = "j_stencil" },
		},
	},
	apply = function(self)
		PVP.RULES.setup_shared_pockets()
	end,
	unlocked = function(self)
		return true
	end,
})
