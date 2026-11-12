-- Appended, not inserted above White: existing numeric stake IDs must not move.
SMODS.Stake({
	name = "White- Stake",
	key = "white_minus",
	unlocked = true,
	applied_stakes = { "white" },
	-- `atlas = false`, not `{ mod = false }`: SMODS prefixes the atlas for any table here.
	prefix_config = { atlas = false, applied_stakes = { mod = false } },
	atlas = "chips",
	pos = { x = 0, y = 0 },
	sticker_pos = { x = 0, y = 0 },
	colour = G.C.WHITE,
	modifiers = function()
		G.GAME.modifiers.mp_white_minus = true
	end,
})
