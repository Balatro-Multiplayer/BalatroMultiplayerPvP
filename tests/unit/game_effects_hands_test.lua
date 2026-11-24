-- Run from the repo root: luajit tests/unit/game_effects_hands_test.lua
-- pvp_api/game_effects.lua: a PvP blind starts with the opponent's hands unknown, never my own.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

PVP = {
	Score = { ZERO = 0 },
	GAME = { enemy = { hands = 2 } },
	UI = { start_pvp_countdown = function() end },
	OPPONENT_SIGNALS = { starting_hands = function(round_resets) return round_resets.hands end },
	mirror_players = function() end,
}
G = { GAME = { round_resets = { hands = 4 } } }
dofile("pvp_api/game_effects.lua")

PVP.game_effects.start_pvp_blind()
eq(PVP.GAME.enemy.hands, nil, "the opponent's hands are unknown at the start, not my 4 and not last blind's 2")

print("game_effects_hands_test: ok (" .. checks .. " checks)")
