SMODS.Atlas({
	key = "player_blind_chip",
	path = "player_blind_row.png",
	atlas_table = "ANIMATION_ATLAS",
	frames = 21,
	px = 34,
	py = 34,
})

SMODS.Atlas({
	key = "player_blind_col",
	path = "blind_col.png",
	atlas_table = "ANIMATION_ATLAS",
	frames = 21,
	px = 34,
	py = 34,
})

MPAPI.Blind({
	key = "nemesis",
	dollars = 5,
	mult = 1, -- Jen's Almanac crashes the game if the mult is 0
	boss_colour = G.C.MULTIPLAYER,
	boss = { min = 1, max = 10 },
	atlas = "player_blind_chip",
	discovered = true,
	in_pool = function(self)
		return false
	end,
})

function PVP.is_pvp_boss()
	if not G.GAME or not G.GAME.blind or not G.GAME.blind.config.blind then return false end
	return G.GAME.blind.config.blind.key == "bl_mp_nemesis" or G.GAME.blind.pvp
end
