SMODS.Stake({
	name = "Planet Stake",
	key = "planet",
	unlocked = true,
	applied_stakes = {},
	above_stake = "gold",
	atlas = "sandbox_stakes",
	pos = { x = 0, y = 0 },
	sticker_pos = { x = 3, y = 1 },
	modifiers = function()
		-- green to black
		G.GAME.modifiers.no_blind_reward = G.GAME.modifiers.no_blind_reward or {}
		G.GAME.modifiers.no_blind_reward.Small = true
		G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
		G.GAME.modifiers.enable_eternals_in_shop = true
		-- no blue
		-- purple scaling and rentals
		G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
		G.GAME.modifiers.enable_rentals_in_shop = true -- gold
	end,
	colour = G.C.Planet,
})
