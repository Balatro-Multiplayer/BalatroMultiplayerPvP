-- Run from the repo root: luajit tests/unit/blind_start_net_test.lua
-- pvp.blind_start (pvp_api/blind_start_net.lua) and the hooks that decide what a PvP blind
-- sends: the hand count goes out once, after the blind's setup events ran, and no fake or
-- repeated pvp.hand goes out (ui/game/functions.lua, ui/game/game_state.lua, pvp_api/net.lua).
local requests, current, state, queue, hand_calls, roundnet, rlog, logs

local failures = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. "\n     " .. tostring(err))
	end
end

local function equal(a, b)
	if a ~= b then error("expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

-- Runs events in order; one that returns true leaves the queue after it ran (as in the game, an
-- event is still queued while it runs), and events queued meanwhile go to the end.
local function run_events()
	local guard = 0
	while #queue > 0 do
		guard = guard + 1
		assert(guard < 1000, "event queue never drained")
		local event = queue[1]
		if event.func() then table.remove(queue, 1) end
	end
end

local function noop() end

local function setup(opts)
	opts = opts or {}
	requests, hand_calls, roundnet, rlog, logs = {}, {}, {}, {}, {}
	queue = {}
	state = { ["pvp.round"] = { runId = "r-1", roundId = 7, phase = "playing" } }
	current = {
		mod_id = "pvp",
		player_id = "u1",
		_game = { started = { run_id = "r-1" } },
	}
	PVP = {
		id = "pvp",
		GAME = { round_id = 7 },
		LOBBY = { config = {}, code = "ABCD", connected = true },
		SP = { practice = opts.practice == true },
		UI = {},
		ACTIONS = setmetatable({
			play_hand = function(score, hands)
				hand_calls[#hand_calls + 1] = { score = score, hands = hands }
			end,
		}, {
			__index = function()
				return noop
			end,
		}),
		RLOG = {
			record = function(op, value)
				rlog[#rlog + 1] = { op = op, value = value }
			end,
		},
		RoundNet = {
			hand = function(args)
				roundnet[#roundnet + 1] = args
			end,
			applied_count = function()
				return 0
			end,
		},
		Score = {
			from_game_value = function(s)
				return s
			end,
		},
		match_log = function(level, text)
			logs[#logs + 1] = level .. " " .. text
		end,
		is_practice_mode = function()
			return opts.practice == true
		end,
		is_mp_or_practice = function()
			return true
		end,
		is_pvp_boss = function()
			return opts.pvp_boss ~= false
		end,
		in_session = function()
			return true
		end,
	}
	G = {
		E_MANAGER = {
			queues = { base = queue },
			add_event = function(_, event)
				queue[#queue + 1] = event
			end,
		},
		GAME = {
			current_round = { hands_left = 4, hands_played = 0, discards_used = 0 },
			round_resets = { hands = 4, ante = 2 },
			chips = 0,
			blind_on_deck = "Boss",
			facing_blind = true,
		},
		FUNCS = setmetatable({}, {
			__index = function()
				return noop
			end,
		}),
		STATES = { HAND_PLAYED = "hand_played", NEW_ROUND = "new_round", DRAW_TO_HAND = "draw_to_hand" },
		STAGES = { RUN = "run" },
		STAGE = "run",
		hand = { cards = {}, unhighlight_all = noop },
		deck = { cards = {} },
		play = { cards = {} },
	}
	Event = function(def)
		return def
	end
	localize = function(key)
		return key
	end
	attention_text = noop
	MPAPI = {
		OPCODE = { HAND_RESULT = "hand_result", SET_ANTE_KEY = "set_ante_key" },
		get_current_lobby = function()
			return current
		end,
		get_state = function(key)
			return state[key]
		end,
		request = function(kind, payload)
			requests[#requests + 1] = { kind = kind, payload = payload }
		end,
	}
	dofile("lib/_state_value.lua")
	dofile("lib/round_facts.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/blind_start_net.lua")
end

-- A hands joker the way Skip-Off does it: one event that queues the ease, which queues its own.
local function queue_hands_joker(extra)
	G.E_MANAGER:add_event(Event({
		func = function()
			G.E_MANAGER:add_event(Event({
				func = function()
					G.GAME.current_round.hands_left = G.GAME.current_round.hands_left + extra
					return true
				end,
			}))
			return true
		end,
	}))
end

test("blind_start is sent once, with the hands the setup events left, nested ones included", function()
	setup()
	queue_hands_joker(3)
	PVP.BlindStartNet.start()
	equal(#requests, 0)
	run_events()
	equal(#requests, 1)
	equal(requests[1].kind, "pvp.blind_start")
	equal(requests[1].payload.runId, "r-1")
	equal(requests[1].payload.roundId, 7)
	equal(requests[1].payload.handsLeft, 7)
	PVP.BlindStartNet.start()
	run_events()
	equal(#requests, 1)
end)

test("blind_start carries the chips held then in pvp.hand's wire format, and no loss applied", function()
	setup()
	PVP.Score.from_game_value = function(value)
		return "S:" .. tostring(value)
	end
	G.GAME.chips = 250
	PVP.BlindStartNet.start()
	run_events()
	equal(requests[1].payload.score, "S:250")
	equal(requests[1].payload.timerLossesApplied, 0)
end)

test("the hands are read inside the queued event, not when the hook runs", function()
	setup()
	PVP.BlindStartNet.start()
	G.GAME.current_round.hands_left = 6
	run_events()
	equal(requests[1].payload.handsLeft, 6)
end)

-- Steps the queue past an event that never finishes: only the events queued behind it run.
local function run_behind_stuck_event(frames)
	for _ = 1, frames do
		local event = queue[2]
		if event and event.func() then table.remove(queue, 2) end
	end
end

test("a queue that stays stuck is waited on without a limit: nothing is sent and nothing is logged", function()
	setup()
	queue[1] = { func = noop }
	PVP.BlindStartNet.start()
	run_behind_stuck_event(200)
	equal(#requests, 0)
	equal(#logs, 0)
	equal(#queue, 2)
end)

test("a queue that drains after more than 20 checks still sends exactly one blind_start", function()
	setup()
	queue[1] = { func = noop }
	PVP.BlindStartNet.start()
	run_behind_stuck_event(45)
	equal(#requests, 0)
	table.remove(queue, 1)
	run_events()
	equal(#requests, 1)
	equal(requests[1].payload.handsLeft, 4)
	equal(#logs, 0)
end)

test("permanent non-blocking events in the queue do not hold the send back", function()
	setup()
	queue[1] = { blocking = false, blockable = false, func = noop }
	queue[2] = { blocking = false, blockable = false, func = noop }
	PVP.BlindStartNet.start()
	local own = queue[3]
	assert(own.func())
	equal(#requests, 1)
	equal(requests[1].payload.handsLeft, 4)
end)

test("a blocking setup event queued beside non-blocking ones is still waited on", function()
	setup()
	queue[1] = { blocking = false, blockable = false, func = noop }
	queue[2] = { blocking = true, func = noop }
	PVP.BlindStartNet.start()
	local own = queue[3]
	own.func()
	equal(#requests, 0)
	equal(#queue, 4)
end)

local function waits_then_changes(change)
	setup()
	queue[1] = { func = noop }
	PVP.BlindStartNet.start()
	run_behind_stuck_event(5)
	change()
	run_behind_stuck_event(1)
	table.remove(queue, 1)
	run_events()
	equal(#requests, 0)
	assert(#logs == 1 and logs[1]:find("error", 1, true), "the abandoned send must be logged")
end

test("a round change while waiting sends nothing and is logged", function()
	waits_then_changes(function()
		PVP.GAME.round_id = 8
	end)
end)

test("a run change while waiting sends nothing and is logged", function()
	waits_then_changes(function()
		current._game.started.run_id = "r-2"
	end)
end)

test("a blind change while waiting sends nothing and is logged", function()
	waits_then_changes(function()
		G.GAME.blind_on_deck = "Small"
	end)
end)

test("the blind ending while waiting sends nothing and is logged", function()
	waits_then_changes(function()
		G.GAME.facing_blind = false
	end)
end)

test("an unknown hand count is never sent: logged, and no blind_start goes out", function()
	setup()
	G.GAME.current_round.hands_left = nil
	PVP.BlindStartNet.start()
	run_events()
	equal(#requests, 0)
	assert(#logs >= 1 and logs[#logs]:find("error", 1, true), "the unknown count must be logged")
	G.GAME.current_round.hands_left = "4"
	PVP.BlindStartNet.start()
	run_events()
	equal(#requests, 0)
end)

test("practice sends no blind_start", function()
	setup({ practice = true })
	PVP.BlindStartNet.start()
	run_events()
	equal(#requests, 0)
	equal(#queue, 0)
end)

test("a lobby that is not PvP's sends no blind_start", function()
	setup()
	current.mod_id = "other"
	PVP.BlindStartNet.start()
	run_events()
	equal(#requests, 0)
end)

test("no open run sends no blind_start", function()
	setup()
	current._game = {}
	PVP.BlindStartNet.start()
	run_events()
	equal(#requests, 0)
end)

-- The server's state of this round with `mine` as my entry (nil: no entry).
local function round_state(mine)
	return { runId = "r-1", roundId = 7, phase = "playing", players = { u1 = mine, u2 = { handsLeft = 3 } } }
end

test("a rejoin where the server has no count for me sends the first count again, not the hands left now", function()
	setup()
	PVP.BlindStartNet.start()
	run_events()
	state["pvp.round"] = round_state({ timerLosses = 0, canTime = false })
	G.GAME.current_round.hands_left = 3 -- a PvP-timer run-out took one
	G.GAME.chips = 999
	PVP.BlindStartNet.resend()
	equal(#requests, 2)
	equal(requests[2].payload.handsLeft, 4)
	equal(requests[2].payload.roundId, 7)
	equal(requests[2].payload.timerLossesApplied, 0)
	-- The score is the one first sent, never the chips held now.
	equal(requests[2].payload.score, requests[1].payload.score)
end)

test("the resend follows the server's state, not the local hands_played", function()
	setup()
	PVP.BlindStartNet.start()
	run_events()
	-- A hand played locally but the server still has no count for me: it is sent again.
	G.GAME.current_round.hands_played = 1
	state["pvp.round"] = round_state({ timerLosses = 0, canTime = false })
	PVP.BlindStartNet.resend()
	equal(#requests, 2)
	-- The server has my count: nothing goes out, whatever hands_played says.
	G.GAME.current_round.hands_played = 0
	state["pvp.round"] = round_state({ handsLeft = 4, timerLosses = 0, canTime = false })
	PVP.BlindStartNet.resend()
	equal(#requests, 2)
end)

test("no resend without my entry, for another round, or with nothing sent", function()
	setup()
	PVP.BlindStartNet.resend()
	equal(#requests, 0)
	PVP.BlindStartNet.start()
	run_events()
	state["pvp.round"] = round_state(nil)
	PVP.BlindStartNet.resend()
	equal(#requests, 1)
	state["pvp.round"] = round_state({ timerLosses = 0 })
	PVP.GAME.round_id = 8
	state["pvp.round"].roundId = 8
	PVP.BlindStartNet.resend()
	equal(#requests, 1)
	PVP.GAME.round_id = 7
	state["pvp.round"].roundId = 7
	state["pvp.round"].phase = "resolved"
	PVP.BlindStartNet.resend()
	equal(#requests, 1)
end)

-- The hooks, loaded from the real files with the game's own functions stubbed out.
local function load_game_state()
	local calls = { start = 0, update_hand_played = 0 }
	Game = {
		update_draw_to_hand = function()
			calls.drew = true
		end,
		update_hand_played = function()
			calls.update_hand_played = calls.update_hand_played + 1
		end,
		update_new_round = noop,
		update_selecting_hand = noop,
		update_shop = noop,
		update_blind_select = noop,
		start_run = noop,
	}
	Blind = { set_blind = noop }
	PVP.BlindStartNet = {
		start = function()
			calls.start = calls.start + 1
		end,
	}
	PVP.GAME.asteroids = 0
	dofile("ui/game/game_state.lua")
	return calls
end

test("the first frame of a PvP blind starts the blind_start send, once", function()
	setup()
	local calls = load_game_state()
	Game:update_draw_to_hand(0)
	equal(calls.start, 1)
	equal(calls.drew, true)
	G.STATE_COMPLETE = true
	Game:update_draw_to_hand(0)
	equal(calls.start, 1)
end)

test("a blind that is not the PvP blind starts no blind_start send", function()
	setup({ pvp_boss = false })
	local calls = load_game_state()
	Game:update_draw_to_hand(0)
	equal(calls.start, 0)
end)

test("a hand already played starts no blind_start send", function()
	setup()
	local calls = load_game_state()
	G.GAME.current_round.hands_played = 1
	Game:update_draw_to_hand(0)
	equal(calls.start, 0)
end)

test("deck-out sends exactly one pvp.hand", function()
	setup()
	load_game_state()
	G.GAME.chips = "250"
	G.GAME.current_round.hands_left = 2
	Game:update_selecting_hand(0)
	equal(G.GAME.current_round.hands_left, 0)
	equal(G.STATE, G.STATES.HAND_PLAYED)
	equal(#hand_calls, 0)
	Game:update_hand_played(0)
	run_events()
	equal(#hand_calls, 1)
	equal(hand_calls[1].score, "250")
	equal(hand_calls[1].hands, 0)
end)

test("selecting the PvP blind sends no pvp.hand", function()
	setup()
	local selected = 0
	G.FUNCS = {
		select_blind = function()
			selected = selected + 1
		end,
		skip_blind = noop,
		can_play = noop,
		can_open = noop,
	}
	PVP.RECONNECT_TAIL = nil
	PVP.GAME.ante_key = nil
	dofile("ui/game/functions.lua")
	math.randomseed(1)
	G.FUNCS.select_blind({ config = { ref_table = { key = "bl_mp_nemesis" } } })
	equal(selected, 1)
	equal(#hand_calls, 0)
	equal(#roundnet, 0)
	equal(#requests, 0)
end)

test("a played hand still reaches the server and the replay log", function()
	setup()
	MPAPI.ActionTypes = setmetatable({}, {
		__index = function(_, k)
			return { key = k }
		end,
	})
	G.P_BLINDS = {}
	dofile("pvp_api/net.lua")
	PVP.net_route({ action = "playHand", score = "100", handsLeft = 3 })
	equal(#roundnet, 1)
	equal(roundnet[1].handsLeft, 3)
	equal(#rlog, 1)
	equal(rlog[1].op, "hand_result")
end)

-- networking/action_handlers.lua: the opponent's hand count and score are the server's, never ours.
test("action_start_blind leaves the opponent's hands and score unknown (nil)", function()
	setup()
	local f = assert(io.open("networking/action_handlers.lua", "rb"))
	local text = f:read("*a"):gsub("\r\n", "\n")
	f:close()
	local body = assert(text:match("\nlocal function action_start_blind%b().-\nend\n"), "action_start_blind not found")
	PVP.GAME.enemy = { hands = 7, score = 0 }
	PVP.GAME.round_id = 7
	PVP.Score.ZERO = "0"
	PVP.OPPONENT_SIGNALS = nil
	PVP.TimerNet = { stop = noop }
	PVP.LOBBY.is_host = true
	PVP.UI.start_pvp_countdown = noop
	local start_blind = assert(loadstring(body .. "\nreturn action_start_blind", "=action_start_blind"))()
	start_blind({ firstPlayer = "u2", startingHands = 99 })
	equal(PVP.GAME.enemy.hands, nil)
	equal(PVP.GAME.enemy.score, nil)
	equal(PVP.GAME.enemy.real_score, nil)
	equal(PVP.GAME.enemy.hands_text, "???")
	equal(PVP.GAME.enemy.score_text, "???")
	equal(PVP.GAME.first_player, nil)
end)

-- A second startBlind while the countdown of the first still runs is ignored: two countdowns would
-- select the blind twice, and the second select crashes (the blind select screen is gone).
test("action_start_blind ignores a start while the countdown is running", function()
	setup()
	local f = assert(io.open("networking/action_handlers.lua", "rb"))
	local text = f:read("*a"):gsub("\r\n", "\n")
	f:close()
	local body = assert(text:match("\nlocal function action_start_blind%b().-\nend\n"), "action_start_blind not found")
	PVP.GAME.enemy = { hands = 7, score = 0 }
	PVP.Score.ZERO = "0"
	PVP.TimerNet = { stop = noop }
	local countdowns = 0
	PVP.UI.start_pvp_countdown = function()
		countdowns = countdowns + 1
		PVP.GAME.pvp_countdown_in_progress = true
	end
	local start_blind = assert(loadstring(body .. "\nreturn action_start_blind", "=action_start_blind"))()
	start_blind({ firstPlayer = "u2" })
	start_blind({ firstPlayer = "u2" })
	equal(countdowns, 1)
	PVP.GAME.pvp_countdown_in_progress = nil
	start_blind({ firstPlayer = "u2" })
	equal(countdowns, 2)
end)

-- The Ready button does nothing once the blind is starting (the countdown runs).
test("mp_toggle_ready does nothing while the countdown is running", function()
	setup()
	local f = assert(io.open("ui/game/functions.lua", "rb"))
	local text = f:read("*a"):gsub("\r\n", "\n")
	f:close()
	local body = assert(text:match("\nfunction G.FUNCS.mp_toggle_ready%b().-\nend\n"), "mp_toggle_ready not found")
	local sent = 0
	PVP.ACTIONS = {
		set_location = noop,
		ready_blind = function() sent = sent + 1 end,
		unready_blind = function() sent = sent + 1 end,
	}
	PVP.GAME.ready_intent = false
	PVP.GAME.pvp_countdown_in_progress = true
	G.FUNCS.mp_toggle_ready = nil
	assert(loadstring(body, "=mp_toggle_ready"))()
	G.FUNCS.mp_toggle_ready({})
	equal(sent, 0)
	equal(PVP.GAME.ready_intent, false)
	PVP.GAME.pvp_countdown_in_progress = nil
	G.FUNCS.mp_toggle_ready({})
	equal(sent, 1)
end)

-- A reconnect in this process resets PVP.GAME while the countdown runs: its next tick finds no
-- count. The countdown ends there (no select_blind), and the lock it holds is released.
local function countdown_of(config)
	local f = assert(io.open("ui/game/timer.lua", "rb"))
	local text = f:read("*a"):gsub("%s*" .. string.char(13) .. "?" .. string.char(10), string.char(10))
	f:close()
	local body = assert(text:match(string.char(10) .. "function PVP.UI.start_pvp_countdown%b()" .. ".-" .. string.char(10) .. "end" .. string.char(10)), "start_pvp_countdown not found")
	local events = {}
	G = {
		CONTROLLER = { locks = {} },
		E_MANAGER = { add_event = function(_, e) events[#events + 1] = e end },
		FUNCS = { attention_text_realtime = function() end },
		C = { MULT = {} },
		play = {},
	}
	Event = function(t) return t end
	play_sound = function() end
	PVP = { GAME = {}, LOBBY = { config = config }, UI = {}, DEFAULT_COUNTDOWN_SECONDS = 3, match_log = function(l, t) logs[#logs + 1] = l .. " " .. t end }
	logs = {}
	assert(loadstring(body, "=start_pvp_countdown"))()
	return events
end

local function drain(events, limit)
	local guard = 0
	while #events > 0 and guard < (limit or 100) do
		guard = guard + 1
		local e = table.remove(events, 1)
		e.func()
	end
end

test("a countdown whose PVP.GAME was reset ends without calling the blind start", function()
	local events = countdown_of({ pvp_countdown_seconds = 3 })
	local called = 0
	PVP.UI.start_pvp_countdown(function() called = called + 1 end)
	equal(G.CONTROLLER.locks.enter_pvp, true)
	drain(events, 1)
	PVP.GAME = {}
	drain(events)
	equal(called, 0)
	equal(G.CONTROLLER.locks.enter_pvp, nil)
end)

test("a countdown with no configured seconds says so, counts the default and calls the blind start once", function()
	local events = countdown_of({})
	PVP.DEFAULT_COUNTDOWN_SECONDS = 2
	local called = 0
	PVP.UI.start_pvp_countdown(function() called = called + 1 end)
	equal(PVP.GAME.pvp_countdown, 2)
	equal(#logs, 1)
	drain(events)
	equal(called, 1)
end)

test("the default countdown length lives in core.lua, and the lobby options take it from there", function()
	local f = assert(io.open("core.lua", "rb"))
	local text = f:read("*a")
	f:close()
	assert(text:find("PVP.DEFAULT_COUNTDOWN_SECONDS = 3", 1, true), "default constant missing")
	assert(text:find("pvp_countdown_seconds = PVP.DEFAULT_COUNTDOWN_SECONDS", 1, true), "options must use the constant")
end)

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
