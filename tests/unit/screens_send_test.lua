-- Run from the repo root: luajit tests/unit/screens_send_test.lua
-- Every input the screens send, with a stub net that records send(kind, body): the kinds and the body
-- field names are the server's (nakama/src/lobby/pvp/parts/{entry,pvp_blind,timer}.ts).
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local function show(value)
	if type(value) ~= "table" then return tostring(value) end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. show(value[key]) end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function same(actual, expected, message) eq(show(actual), show(expected), message) end

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
	match_net = net,
	GAME = {},
	LOBBY = {},
	Score = { ZERO = "0", from_game_value = function(value) return tostring(value) end },
	in_session = function() return true end,
	is_practice_mode = function() return false end,
	is_pvp_boss = function() return true end,
	is_layer_active = function() return true end,
	boss_select_button = function() return nil end,
	refresh_team_pickers = function() end,
	game_effects = {
		start_pvp_blind = function(on_selected, on_missed)
			dispatched = { name = "startBlind", params = { on_selected = on_selected, on_missed = on_missed } }
		end,
	},
	UTILS = { timer_display_text = function() return "t" end },
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
	"_view", "entry_reader", "pvp_blind_reader", "timer_reader", "entry_screen", "pvp_blind_screen", "timer_screen",
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
eq(PVP.entry_screen.press_ready({}), true, "the press asks for Ready")
eq(last().kind, "ready", "ready: kind")
same(last().body, { ready = true, blindKey = "2:Boss" }, "ready: body")

-- Team.
PVP.entry_screen.pick_team("HUNTER")
eq(last().kind, "team", "team: kind")
same(last().body, { team = "HUNTER" }, "team: body")
waiting.team = true
local before = #sent
PVP.entry_screen.pick_team("RUNNER")
eq(#sent, before, "team: no press while a pick is unconfirmed")
waiting.team = nil

-- blindStart goes out once select_blind ran, not before.
net.view.match.run.currentPvpBlind = { stage = "playing", blindKey = "2:Boss", players = { a = { stage = "not entered" }, b = { stage = "not entered" } } }
G.STATE = G.STATES.BLIND_SELECT
G.GAME.blind_on_deck = "Boss"
PVP.boss_select_button = function() return {} end
before = #sent
PVP.entry_screen.update()
eq(dispatched and dispatched.name, "startBlind", "entry: the blind is started")
eq(#sent, before, "blindStart: nothing sent before select_blind ran")
dispatched.params.on_selected()
eq(#sent, before, "blindStart: nothing sent when select_blind ran either")
-- It goes out at the first pick-a-hand, with the hands after the blind's own gains (Burglar +3).
G.STATE = G.STATES.SELECTING_HAND
G.STATE_COMPLETE = false
G.GAME.current_round.hands_left = 7
G.GAME.chips = 0
PVP.pvp_blind_screen.update()
eq(#sent, before, "blindStart: not before the pick-a-hand is built")
eq(PVP.pvp_blind_screen.may_play(), false, "no Play before the blindStart went out")
G.STATE_COMPLETE = true
PVP.pvp_blind_screen.update()
eq(last().kind, "blindStart", "blindStart: kind")
same(last().body, { blindKey = "2:Boss", handsLeft = 7, score = "0" }, "blindStart: body")
eq(#sent, before + 1, "blindStart: sent")
PVP.pvp_blind_screen.update()
eq(#sent, before + 1, "blindStart: once per blind")
eq(PVP.pvp_blind_screen.may_play(), true, "Play once it went out")
G.GAME.current_round.hands_left = 4

-- Timer: start, pause, spend, animating.
G.STATE = G.STATES.SELECTING_HAND
PVP.timer_screen.press()
eq(last().kind, "timerStart", "timerStart: kind")
same(last().body, { timer = "pvp" }, "timerStart: body")
net.view.timers = { timerButton = "none", deadlines = { { kind = "pvp", endsAt = 100000, by = "a", against = {} } } }
PVP.timer_screen.press()
eq(last().kind, "timerPause", "timerPause: kind")
same(last().body, {}, "timerPause: body")
eq(PVP.timer_screen.clock(), "mine", "clock: my own running timer")
eq(type(PVP.timer_screen.seconds()), "number", "clock: the seconds shown")
net.view.timers.deadlines[1].by = "b"
net.view.timers.deadlines[1].against = { "a" }
eq(PVP.timer_screen.clock(), "against me", "clock: an opponent's timer against me")
net.view.timers.deadlines[1].kind = "personal"
eq(PVP.timer_screen.clock(), "none", "clock: a personal timer of another is not shown")
net.view.timers.deadlines = {}
eq(PVP.timer_screen.seconds(), nil, "clock: no seconds with no timer")
net.view.timers.deadlines = { { kind = "pvp", endsAt = 100000, by = "a", against = {} } }
PVP.timer_screen.spend()
eq(last().kind, "paidPreviews", "paidPreviews: kind")
same(last().body, { total = 1 }, "paidPreviews: body")
G.CONTROLLER = { locked = true, locks = {} }
G.SETTINGS = {}
G.GAME.STOP_USE = 0
PVP.timer_screen.update()
eq(last().kind, "animating", "animating: kind")
same(last().body, { on = true }, "animating: body")

-- A spend that cannot be sent is not counted.
-- (match_net.send answers nil only with no view or no run.)
net.view = nil
before = #sent
PVP.timer_screen.spend()
eq(#sent, before, "no spend is sent with no view")
eq(G.GAME.pvp_net.totals.paidPreviews, 1, "and its total is not raised")
local run = G.GAME.pvp_net
G.GAME.pvp_net = { totals = {} }
net.view = { me = "a" }
PVP.timer_screen.spend()
eq(G.GAME.pvp_net.totals.paidPreviews, nil, "with no run id the total is not raised either")
G.GAME.pvp_net = run
net.view = {
	me = "a", players = { a = {} }, timers = { deadlines = {} },
	match = { run = { id = "run1", currentPvpBlind = { stage = "playing", blindKey = "2:Boss", players = { a = { stage = "not entered" } } } } },
}
PVP.timer_screen.spend()
same(last().body, { total = 2 }, "the next spend carries the next total")

-- handPlayed and handScored.
local body = PVP.pvp_blind_screen.play_body()
same(body, { blindKey = "2:Boss", handsLeft = 3 }, "handPlayed: body")
PVP.pvp_blind_screen.send_hand_played(body)
eq(last().kind, "handPlayed", "handPlayed: kind")
same(last().body, { blindKey = "2:Boss", handsLeft = 3 }, "handPlayed: sent body")
PVP.pvp_blind_screen.hand_scored("1500", 3)
eq(last().kind, "handScored", "handScored: kind")
same(last().body, { blindKey = "2:Boss", handsLeft = 3, score = "1500" }, "handScored: body")

print("screens_send_test: ok (" .. checks .. " checks)")
