-- Run from the repo root: luajit tests/unit/action_save_test.lua
-- lib/action_save.lua: a local save after each hand, discard and consumable, once the game is back
-- at "pick a hand" with nothing running; never while scoring, in a pack, or outside a match.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local STATES = {
	SELECTING_HAND = 1,
	HAND_PLAYED = 2,
	DRAW_TO_HAND = 3,
	PLAY_TAROT = 4,
	NEW_ROUND = 5,
	TAROT_PACK = 6,
	SHOP = 7,
	ROUND_EVAL = 8,
	SMODS_BOOSTER_OPENED = 9,
}
local played, discarded, used = 0, 0, 0
local frames = {}
PVP = { LOBBY = { code = "ABCD" }, UTILS = {}, ACTIONS = {} }
function PVP.LOBBY.in_session()
	return true
end
local running, driving, pvp_blind = false, false, false
function PVP.UTILS.is_pvp_blind()
	return pvp_blind
end
MPAPI = {
	get_current_lobby = function()
		return {}
	end,
	playback = {
		_queues_empty = function()
			return not running
		end,
		is_driving = function()
			return driving
		end,
	},
}
sendWarnMessage = function() end
G = {
	STATE = STATES.SELECTING_HAND,
	STATE_COMPLETE = true,
	STATES = STATES,
	FUNCS = {
		play_cards_from_highlighted = function()
			played = played + 1
		end,
		discard_cards_from_highlighted = function()
			discarded = discarded + 1
		end,
	},
	E_MANAGER = { queues = { base = {} } },
}
Card = {}
function Card:use_consumeable()
	used = used + 1
end
Game = {}
function Game:update(dt)
	frames[#frames + 1] = dt
end
dofile("lib/action_save.lua")
local AS = PVP.ACTIONS.save

-- Pure pieces.
eq(AS.phase(1, true, STATES), "ready", "a built pick-a-hand is ready")
eq(AS.phase(1, false, STATES), "in_hand", "a pick-a-hand still building is not ready")
eq(AS.phase(STATES.HAND_PLAYED, true, STATES), "in_hand", "scoring is in the hand")
eq(AS.phase(STATES.TAROT_PACK, true, STATES), "elsewhere", "a booster pack is elsewhere")
eq(AS.phase(STATES.SMODS_BOOSTER_OPENED, true, STATES), "elsewhere", "an opened booster is elsewhere")
eq(AS.phase(STATES.SHOP, true, STATES), "elsewhere", "the shop is elsewhere")
eq(AS.work("empty", false), "idle", "an empty queue is idle")
eq(AS.work("running", false), "busy", "a running event holds the save")
eq(AS.work("empty", true), "busy", "an inbox item in flight holds the save")
eq(AS.step({ in_match = true, phase = "ready", work = "idle" }), "save", "ready and idle saves")
eq(AS.step({ in_match = true, phase = "ready", work = "busy" }), "wait", "ready but busy waits")
eq(AS.step({ in_match = true, phase = "in_hand", work = "idle" }), "wait", "scoring waits")
eq(AS.step({ in_match = true, phase = "elsewhere", work = "idle" }), "drop", "a pack drops the due save")
eq(AS.step({ in_match = false, phase = "ready", work = "idle" }), "drop", "outside a match drops it")

-- Through the game: count the local saves.
local saves = 0
MPAPI.run_save = {
	take_local = function()
		saves = saves + 1
		return true
	end,
}
local function frame()
	Game:update(0.016)
end
local function settle()
	G.STATE, G.STATE_COMPLETE = STATES.SELECTING_HAND, true
	running = false
end

frame()
eq(saves, 0, "nothing is saved with no action")

G.FUNCS.play_cards_from_highlighted()
eq(played, 1, "the play still runs")
G.STATE, G.STATE_COMPLETE = STATES.HAND_PLAYED, true
frame()
eq(saves, 0, "no save while the hand scores")
G.STATE = STATES.DRAW_TO_HAND
running = true
frame()
eq(saves, 0, "no save while events run")
G.STATE, G.STATE_COMPLETE = STATES.SELECTING_HAND, false
frame()
eq(saves, 0, "no save while the pick-a-hand is still building")
settle()
frame()
eq(saves, 1, "one save once back in pick-a-hand with nothing running")
frame()
eq(saves, 1, "and only one")

G.FUNCS.discard_cards_from_highlighted()
eq(discarded, 1, "the discard still runs")
G.STATE = STATES.DRAW_TO_HAND
frame()
settle()
frame()
eq(saves, 2, "a save after a discard")

Card:use_consumeable()
eq(used, 1, "the consumable still runs")
frame()
eq(saves, 3, "a save after a consumable used in pick-a-hand")

G.FUNCS.play_cards_from_highlighted()
G.FUNCS.discard_cards_from_highlighted()
frame()
eq(saves, 4, "two actions before a frame make one save")

-- A consumable used in a pack, or a hand that ends the blind, saves nothing and clears the mark.
G.STATE = STATES.TAROT_PACK
Card:use_consumeable()
frame()
settle()
frame()
eq(saves, 4, "no save for a consumable used in a pack")
G.FUNCS.play_cards_from_highlighted()
G.STATE = STATES.ROUND_EVAL
frame()
settle()
frame()
eq(saves, 4, "a hand that ended the blind leaves no due save for the next one")

-- A rejoin's fast-forward replays hands and discards through the same calls: no save for them.
driving = true
G.FUNCS.play_cards_from_highlighted()
G.FUNCS.discard_cards_from_highlighted()
Card:use_consumeable()
eq(AS.is_due(), false, "a replayed action marks no save")
driving = false

-- In a PvP blind the pick-a-hand already takes the server's save (which keeps the local copy): a
-- hand or discard builds no second one. A consumable has no such arrival and is saved.
pvp_blind = true
G.FUNCS.play_cards_from_highlighted()
G.FUNCS.discard_cards_from_highlighted()
eq(AS.is_due(), false, "a hand or discard in a PvP blind is covered by the server save")
Card:use_consumeable()
eq(AS.is_due(), true, "a consumable in a PvP blind is still saved")
frame()
eq(saves, 5, "that save is taken once back in pick-a-hand")
pvp_blind = false

-- Outside a multiplayer run nothing is marked.
local lobby = nil
MPAPI.get_current_lobby = function()
	return lobby
end
G.FUNCS.play_cards_from_highlighted()
frame()
eq(AS.is_due(), false, "no lobby, no mark")
lobby = {}
PVP.LOBBY.code = nil
G.FUNCS.play_cards_from_highlighted()
eq(AS.is_due(), false, "no lobby code, no mark")
PVP.LOBBY.code = "ABCD"
G.FUNCS.play_cards_from_highlighted()
eq(AS.is_due(), true, "in a lobby the action marks a save")
lobby = nil
frame()
eq(saves, 5, "a lobby that ended before the save drops it")
eq(AS.is_due(), false, "and clears the mark")

-- The inbox holds the save back while an item runs.
lobby = {}
PVP.NET = {
	save_must_wait = function()
		return true
	end,
}
G.FUNCS.play_cards_from_highlighted()
frame()
eq(saves, 5, "no save while the inbox holds it")
PVP.NET = {
	save_must_wait = function()
		return false
	end,
}
frame()
eq(saves, 6, "saved once the inbox lets go")

T.done("action_save_test")
