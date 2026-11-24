-- Run from the repo root: luajit tests/unit/screens_send_test.lua
-- Every input the screens send, with a stub net that records send(kind, body): the kinds and the body
-- field names are the server's (nakama/src/lobby/pvp/parts/{entry,pvp_blind,timer}.ts).
local T = dofile("tests/support/check.lua")
local eq, same = T.eq, T.same

local sent, waiting = {}, {}
local net
net = {
	view = nil,
	send = function(kind, body)
		if not net.view then return nil end
		sent[#sent + 1] = { kind = kind, body = body }
		return #sent
	end,
	waiting = function(kind) return waiting[kind] == true end,
	latest_waiting = function() return nil end,
	server_now = function() return 0 end,
	add_view_listener = function() end,
}

local dispatched
PVP = {
	READ = {},
	NET = net,
	GAME = {},
	LOBBY = { in_session = function() return true end },
	SCORE = { ZERO = "0", from_game_value = function(value) return tostring(value) end },
	PRACTICE = { is_on = function() return false end },
	RULES = { is_layer_active = function() return true end },
	UTILS = { timer_display_text = function() return "t" end, is_pvp_blind = function() return true end },
	UI = { timer = {}, boss_select_button = function() return nil end, lobby_options = { refresh_team_pickers = function() end }, match = {
		start_pvp_blind = function(on_selected, on_missed)
			dispatched = { name = "startBlind", params = { on_selected = on_selected, on_missed = on_missed } }
		end,
	} },
}
Game = { update = function() end }
G = {
	STAGES = { RUN = 1 },
	STAGE = 1,
	STATES = { SELECTING_HAND = 1, BLIND_SELECT = 2 },
	STATE = 1,
	GAME = {
		pvp_net = { runId = "run1", inboxDone = 0, totals = {} },
		round_resets = { ante = 2, hands = 4 },
		current_round = { hands_left = 4 },
	},
	hand = { highlighted = { {} } },
	play = { cards = {} },
}
function localize(key) return key end
function sendWarnMessage() end

for _, file in ipairs({
	"read/_view", "read/blind_start", "read/pvp_blind", "read/timer", "ui/blind_start", "ui/pvp_blind", "ui/timer",
}) do
	dofile("pvp_api/" .. file .. ".lua")
end
dofile("lib/run_totals.lua")

local function last() return sent[#sent] end

-- Ready press, from an open blind.
net.view = {
	me = "a",
	players = { a = {}, b = {} },
	onlyMine = { inboxNewest = 0 },
	timers = { timerButton = "pvp", deadlines = {} },
	match = { run = { id = "run1", currentPvpBlind = { stage = "waiting", blindKey = "2:Boss", players = { a = "not ready", b = "ready" } } } },
}
eq(PVP.UI.blind_start.press_ready({}), true, "the press asks for Ready")
eq(last().kind, "ready", "ready: kind")
same(last().body, { ready = true, blindKey = "2:Boss" }, "ready: body")

-- Team.
PVP.UI.blind_start.pick_team("HUNTER")
eq(last().kind, "team", "team: kind")
same(last().body, { team = "HUNTER" }, "team: body")
waiting.team = true
local before = #sent
PVP.UI.blind_start.pick_team("RUNNER")
eq(#sent, before, "team: no press while a pick is unconfirmed")
waiting.team = nil

-- blindStart goes out once select_blind ran, not before.
net.view.match.run.currentPvpBlind = { stage = "playing", blindKey = "2:Boss", players = { a = { stage = "not entered" }, b = { stage = "not entered" } } }
G.STATE = G.STATES.BLIND_SELECT
G.GAME.blind_on_deck = "Boss"
PVP.UI.boss_select_button = function() return {} end
before = #sent
PVP.UI.blind_start.update()
eq(dispatched and dispatched.name, "startBlind", "entry: the blind is started")
eq(#sent, before, "blindStart: nothing sent before select_blind ran")
dispatched.params.on_selected()
eq(#sent, before, "blindStart: nothing sent when select_blind ran either")
-- It goes out at the first pick-a-hand, with the hands after the blind's own gains (Burglar +3).
G.STATE = G.STATES.SELECTING_HAND
G.STATE_COMPLETE = false
G.GAME.current_round.hands_left = 7
G.GAME.chips = 0
PVP.UI.pvp_blind.update()
eq(#sent, before, "blindStart: not before the pick-a-hand is built")
eq(PVP.UI.pvp_blind.may_play(), false, "no Play before the blindStart went out")
G.STATE_COMPLETE = true
PVP.UI.pvp_blind.update()
eq(last().kind, "blindStart", "blindStart: kind")
same(last().body, { blindKey = "2:Boss", handsLeft = 7, score = "0" }, "blindStart: body")
eq(#sent, before + 1, "blindStart: sent")
PVP.UI.pvp_blind.update()
eq(#sent, before + 1, "blindStart: once per blind")
eq(PVP.UI.pvp_blind.may_play(), true, "Play once it went out")
G.GAME.current_round.hands_left = 4

-- Timer: start, pause, spend, animating.
G.STATE = G.STATES.SELECTING_HAND
PVP.UI.timer.press()
eq(last().kind, "timerStart", "timerStart: kind")
same(last().body, { timer = "pvp" }, "timerStart: body")
net.view.timers = { timerButton = "none", deadlines = { { kind = "pvp", endsAt = 100000, by = "a", against = {} } } }
PVP.UI.timer.press()
eq(last().kind, "timerPause", "timerPause: kind")
same(last().body, {}, "timerPause: body")
eq(PVP.UI.timer.clock(), "mine", "clock: my own running timer")
eq(type(PVP.UI.timer.seconds()), "number", "clock: the seconds shown")
net.view.timers.deadlines[1].by = "b"
net.view.timers.deadlines[1].against = { "a" }
eq(PVP.UI.timer.clock(), "against me", "clock: an opponent's timer against me")
net.view.timers.deadlines[1].kind = "personal"
eq(PVP.UI.timer.clock(), "none", "clock: a personal timer of another is not shown")
net.view.timers.deadlines = {}
eq(PVP.UI.timer.seconds(), nil, "clock: no seconds with no timer")
net.view.timers.deadlines = { { kind = "pvp", endsAt = 100000, by = "a", against = {} } }
PVP.UI.timer.spend()
eq(last().kind, "paidPreviews", "paidPreviews: kind")
same(last().body, { total = 1 }, "paidPreviews: body")
G.CONTROLLER = { locked = true, locks = {} }
G.SETTINGS = {}
G.GAME.STOP_USE = 0
PVP.UI.timer.update()
eq(last().kind, "animating", "animating: kind")
same(last().body, { on = true }, "animating: body")

-- A spend that cannot be sent is not counted.
-- (match_net.send answers nil only with no view or no run.)
net.view = nil
before = #sent
PVP.UI.timer.spend()
eq(#sent, before, "no spend is sent with no view")
eq(G.GAME.pvp_net.totals.paidPreviews, 1, "and its total is not raised")
local run = G.GAME.pvp_net
G.GAME.pvp_net = { totals = {} }
net.view = { me = "a" }
PVP.UI.timer.spend()
eq(G.GAME.pvp_net.totals.paidPreviews, nil, "with no run id the total is not raised either")
G.GAME.pvp_net = run
net.view = {
	me = "a", players = { a = {} }, timers = { deadlines = {} },
	match = { run = { id = "run1", currentPvpBlind = { stage = "playing", blindKey = "2:Boss", players = { a = { stage = "not entered" } } } } },
}
PVP.UI.timer.spend()
same(last().body, { total = 2 }, "the next spend carries the next total")

-- handPlayed and handScored.
local body = PVP.UI.pvp_blind.play_body()
same(body, { blindKey = "2:Boss", handsLeft = 3 }, "handPlayed: body")
PVP.UI.pvp_blind.send_hand_played(body)
eq(last().kind, "handPlayed", "handPlayed: kind")
same(last().body, { blindKey = "2:Boss", handsLeft = 3 }, "handPlayed: sent body")
PVP.UI.pvp_blind.hand_scored("1500", 3)
eq(last().kind, "handScored", "handScored: kind")
same(last().body, { blindKey = "2:Boss", handsLeft = 3, score = "1500" }, "handScored: body")

T.done("screens_send_test")
