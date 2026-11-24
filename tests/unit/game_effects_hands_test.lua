-- Run from the repo root: luajit tests/unit/game_effects_hands_test.lua
-- pvp_api/ui/match.lua: a PvP blind starts with the opponent's hands unknown, never my own.
local T = dofile("tests/support/check.lua")
local eq = T.eq

PVP = {
	SCORE = { ZERO = 0 },
	GAME = { enemy = { hands = 2 } },
	UI = { start_pvp_countdown = function() end },
	OPPONENT_SIGNALS = { starting_hands = function(round_resets) return round_resets.hands end },
	LOBBY = { mirror_players = function() end },
}
G = { GAME = { round_resets = { hands = 4 } } }
dofile("pvp_api/ui/match.lua")

PVP.UI.match.start_pvp_blind()
eq(PVP.GAME.enemy.hands, nil, "the opponent's hands are unknown at the start, not my 4 and not last blind's 2")

T.done("game_effects_hands_test")
