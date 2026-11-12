SMODS.Stake({
	name = "Spectral Stake",
	unlocked = true,
	key = "spectral",
	applied_stakes = { "planet" },
	atlas = "sandbox_stakes",
	pos = { x = 1, y = 0 },
	sticker_pos = { x = 3, y = 1 },
	modifiers = function()
		G.GAME.modifiers.enable_perishables_in_shop = true -- orange
		G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1 -- yeehaw
	end,
	colour = HEX("000000"),
	above_stake = "planet",
})
