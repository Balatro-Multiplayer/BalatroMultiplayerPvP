-- Run from the repo root: luajit tests/unit/blind_save_point_test.lua
-- lib/run_save.lua: a PvP blind's save is numbered by the API and taken in a queued event, and a
-- load makes the blind screen expect the view's hands.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local numbered, taken, directly = 0, {}, 0
local lobby = nil
local queued = {}
local hooks
PVP = { id = "MultiplayerPvP", GAME = {}, LOBBY = { code = "ABCD" } }
function PVP.in_session() return true end
function PVP.is_pvp_boss() return true end
function PVP.reset_game_states() PVP.GAME = {} end
MPAPI = {
	run_save = {
		register_state = function(_, given) hooks = given end,
		start_save_point = function() numbered = numbered + 1 return numbered end,
		at_save_point = function(save_point) taken[#taken + 1] = save_point end,
		take = function() directly = directly + 1 end,
	},
	get_current_lobby = function() return lobby end,
}
G = { STATE = 1, STATE_COMPLETE = false, STATES = { SELECTING_HAND = 1 }, E_MANAGER = { add_event = function(_, event) queued[#queued + 1] = event end } }
function Event(fields) return fields end
sendWarnMessage = function() end
Game = {}
function Game:update_selecting_hand() G.STATE_COMPLETE = true end
dofile("lib/run_save.lua")

-- Off with no lobby.
Game:update_selecting_hand(0)
eq(numbered, 0, "no save point outside a lobby")
eq(#queued, 0, "nothing queued outside a lobby")

-- On in a lobby, with no setting needed.
lobby = { code = "ABCD" }
G.STATE_COMPLETE = false
Game:update_selecting_hand(0)
eq(numbered, 1, "the screen is numbered when the pick-a-hand is built")
eq(#queued, 1, "the save is queued, not taken at once")
eq(#taken + directly, 0, "nothing is taken before the event runs")
queued[1].func()
eq(taken[1], 1, "the event takes the save of that number")
eq(directly, 0, "the API's take is never called directly")

local expected = 0
PVP.pvp_blind_reader = { hands_source_loaded = function() expected = expected + 1; return { kind = "from server" } end }
hooks.load({ lives = 3 })
eq(expected, 1, "a load makes the blind wait for the view's hands")
eq(PVP.GAME.lives, 3, "and puts the saved match state back")

print(string.format("blind_save_point_test: ok (%d checks)", checks))
