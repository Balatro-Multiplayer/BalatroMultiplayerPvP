-- Run from the repo root: luajit tests/unit/out_of_cards_test.lua
-- ui/game/game_state.lua: running out of cards in a PvP blind ends the blind with one handScored of 0 hands.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local reported = {}
PVP = {
	UI = {},
	LOBBY = { connected = true, code = "ABCD", config = {} },
	GAME = {},
	ACTIONS = { play_hand = function(chips, hands_left) reported[#reported + 1] = { chips = chips, hands_left = hands_left } end },
	is_practice_mode = function() return false end,
	is_pvp_boss = function() return true end,
	is_mp_or_practice = function() return true end,
	in_session = function() return true end,
}
Game = {
	update_draw_to_hand = function() end,
	update_hand_played = function() end,
	update_new_round = function() end,
	update_selecting_hand = function() end,
	update_shop = function() end,
	update_blind_select = function() end,
	start_run = function() end,
}
Blind = { set_blind = function() end }
Event = function(args) return args end
G = {
	STATES = { SELECTING_HAND = 1, HAND_PLAYED = 2, NEW_ROUND = 3, DRAW_TO_HAND = 4 },
	STATE = 1,
	STATE_COMPLETE = true,
	GAME = { chips = 50, current_round = { hands_left = 3 }, round_resets = { hands = 4 } },
	hand = { cards = {} },
	deck = { cards = {} },
	play = { cards = {} },
	E_MANAGER = { add_event = function(_, event) event.func() end },
}
function attention_text() end
function localize(key) return key end

dofile("ui/game/game_state.lua")

-- No cards left anywhere: the blind ends on its own, with hands 0.
Game.update_selecting_hand(G, 0)
eq(G.GAME.current_round.hands_left, 0, "the hands are used up")
eq(G.STATE, G.STATES.HAND_PLAYED, "the hand is closed out")
Game.update_hand_played(G, 0)
eq(#reported, 1, "the score is reported once")
eq(reported[1].hands_left, 0, "with no hands left")
eq(reported[1].chips, 50, "and the score")

print(string.format("out_of_cards_test: ok (%d checks)", checks))
