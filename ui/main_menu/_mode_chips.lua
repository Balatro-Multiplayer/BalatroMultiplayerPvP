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
	nemesis = 0,
	royale = 1,
	teams = 2,
	smallworld = 3,
	vanilla = 4,
	balanced = 5,
	expanded = 6,
	mlba = 7,
	smallworld_ranked = 8,
	manhunt = 9,
	party = 10,
}

-- A gamemode's colour is its chip's background. The ruleset colours tell the Ranked rulesets
-- apart, as their chips all share the gold-on-grey look.
PVP.MODE_COLOUR = {
	nemesis = "8D2A23",
	royale = "4E3381",
	teams = "F28A3C",
	smallworld = "334461",
	vanilla = "439A4F",
	balanced = "B95B08",
	expanded = "B95C96",
	mlba = "4B71E4",
	smallworld_ranked = "45967F",
	manhunt = "B52D2D",
	party = "EFC03C",
}

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
		[R.SMALLWORLD] = PVP.MODE_CHIP_ROW.smallworld_ranked,
	}
	return PVP.mode_chip_sprite(rows[ruleset_key] or PVP.MODE_CHIP_ROW.nemesis, size)
end
