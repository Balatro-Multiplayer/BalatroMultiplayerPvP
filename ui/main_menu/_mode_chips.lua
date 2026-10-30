-- Chip art and name plate colour for each gamemode and ruleset, shared by the Find Game
-- (find_game.lua) and Create Lobby / Practice (game_select.lua) pages. The leading underscore
-- makes load_mp_dir load this file before them.
SMODS.Atlas({
	key = "game_mode_chips",
	path = "game_mode_chips.png",
	atlas_table = "ANIMATION_ATLAS",
	frames = 21,
	px = 34,
	py = 34,
})

PVP.MODE_CHIP_ROW = {
	expanded = 0,
	balanced = 1,
	vanilla = 2,
	mlba = 3,
	smallworld = 4,
	nemesis = 5,
	royale = 6,
	teams = 7,
	manhunt = 8,
	speedlatro = 9,
	party = 10,
}

PVP.MODE_COLOUR = {
	expanded = "B95C96",
	balanced = "B95B08",
	vanilla = "439A4F",
	mlba = "4B71E4",
	smallworld = "45967F",
	nemesis = "B52D2D",
	royale = "DFCA81",
	teams = "A84024",
	manhunt = "B52D2D",
	speedlatro = "575757",
	party = "EFC03C",
}

-- Teams has no art yet, so it borrows the Nemesis chip and colour.
-- Remove these 2 lines once it has its own.
PVP.MODE_CHIP_ROW.teams = PVP.MODE_CHIP_ROW.nemesis
PVP.MODE_COLOUR.teams = PVP.MODE_COLOUR.nemesis

-- Plain Sprite, not AnimatedSprite: AnimatedSprite free-runs its column animation, and this
-- icon is meant to sit static.
function PVP.mode_chip_sprite(row, size)
	size = size or 1.1
	return Sprite(0, 0, size, size, G.ANIMATION_ATLAS["mp_game_mode_chips"], { x = 0, y = row })
end

-- A ruleset's art, shared by the Ranked pillars and the Ruleset vote's tiles
-- (pvp_api/setup.lua).
function PVP.ruleset_chip_sprite(ruleset_key, size)
	local R = PVP.RulesetKey
	local rows = {
		[R.VANILLA] = PVP.MODE_CHIP_ROW.vanilla,
		[R.BALANCED] = PVP.MODE_CHIP_ROW.balanced,
		[R.EXPANDED] = PVP.MODE_CHIP_ROW.expanded,
		[R.MAJORLEAGUE] = PVP.MODE_CHIP_ROW.mlba,
		[R.SMALLWORLD] = PVP.MODE_CHIP_ROW.smallworld,
	}
	return PVP.mode_chip_sprite(rows[ruleset_key] or PVP.MODE_CHIP_ROW.nemesis, size)
end
