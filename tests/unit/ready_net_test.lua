-- Run from the repo root: luajit tests/unit/ready_net_test.lua
-- The shell around lib/ready_view.lua with stubbed MPAPI and
-- dispatch_action: who starts a blind, from what, and when Ready is pressed again.
local requests, dispatched, replay, handlers, state, current, lobby, resends, refreshes, logs

local function make_lobby(id, is_host, players)
	local l = {
		mod_id = "pvp",
		player_id = id,
		host_id = "u1",
		is_host = is_host,
		_game = { started = { run_id = "r-abc" } },
	}
	function l:get_players()
		local list = {}
		for _, p in ipairs(players or { "u1", "u2" }) do
			list[#list + 1] = { id = p }
		end
		return list
	end
	return l
end

local function setup(game, opts)
	opts = opts or {}
	requests, dispatched, replay, handlers = {}, {}, {}, {}
	resends, refreshes, logs = 0, 0, {}
	state = nil
	PVP = {
		id = "pvp",
		GAME = game,
		match_log = function(level, text)
			logs[#logs + 1] = { level = level, text = text }
		end,
		BlindStartNet = {
			resend = function()
				resends = resends + 1
			end,
		},
		EnemyScoreNet = {
			refresh = function()
				refreshes = refreshes + 1
			end,
		},
		RLOG = {
			record = function(op, value)
				replay[#replay + 1] = { op, value }
			end,
		},
		current_target_id = function()
			return "u2"
		end,
		dispatch_action = function(name, params)
			dispatched[#dispatched + 1] = { name = name, params = params }
		end,
	}
	dofile("lib/pending_death.lua")
	dofile("lib/_state_value.lua")
	dofile("lib/ready_view.lua")
	G = {
		STAGE = "run",
		STAGES = { RUN = "run" },
		STATE = "blind_select",
		STATES = { BLIND_SELECT = "blind_select" },
		GAME = { round_resets = { ante = 2 }, blind_on_deck = "Boss" },
	}
	lobby = make_lobby(opts.id or "u1", opts.is_host ~= false, opts.players)
	current = lobby
	MPAPI = {
		OPCODE = { READY_BLIND = "ready_blind" },
		get_current_lobby = function()
			return current
		end,
		get_state = function()
			return state
		end,
		on_state = function(_, fn)
			handlers[#handlers + 1] = fn
		end,
		request = function(kind, payload, on_result)
			requests[#requests + 1] = { kind = kind, payload = payload, on_result = on_result }
		end,
	}
	localize = function(key)
		return key
	end
	attention_text = function() end
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/ready_net.lua")
end

local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

local failures = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function push_state(round, ready, first, players)
	return {
		runId = "r-abc",
		round = round,
		ready = ready or {},
		out = {},
		lastStart = { roundId = round, firstPlayer = first or "u1", players = players or { "u1", "u2" } },
	}
end

-- Seeds the record with round 2 already started, then pushes round 3.
local function seed_and_push(first, players)
	state = push_state(2)
	handlers[1](state)
	state = push_state(3, nil, first, players)
	handlers[1](state)
end

test("first player: records the round, starts the blind with the server's id and no hand count", function()
	setup({})
	seed_and_push("u1")
	equal(PVP.GAME.round_id, 3)
	equal(#dispatched, 1)
	equal(dispatched[1].name, "startBlind")
	equal(dispatched[1].params.firstPlayer, "u1")
	equal(dispatched[1].params.startingHands, nil)
end)

test("a started blind shows the hands the server has for the opponent", function()
	setup({})
	seed_and_push("u1")
	equal(refreshes, 1)
end)

test("a rejoin or a snapshot sends the round's blind_start again, and a start does not", function()
	setup({ ready_intent = false })
	state = push_state(2)
	PVP.ReadyNet.on_connected()
	equal(resends, 1)
	PVP.ReadyNet.on_snapshot()
	PVP.ReadyNet.update()
	equal(resends, 2)
	setup({})
	seed_and_push("u1")
	equal(resends, 0)
end)

test("the first player is the server's id for either side, with no host/guest translation", function()
	setup({}, { id = "u2", is_host = false })
	seed_and_push("u1")
	equal(dispatched[1].params.firstPlayer, "u1")
	setup({}, { id = "u2", is_host = false })
	seed_and_push("u2")
	equal(dispatched[1].params.firstPlayer, "u2")
end)

test("a lobby of three or more passes the server's first player on unchanged", function()
	setup({}, { players = { "u1", "u2", "u3" } })
	seed_and_push("u3", { "u1", "u2", "u3" })
	equal(dispatched[1].params.firstPlayer, "u3")
end)

test("no first player from the server is nil, not a sentinel", function()
	setup({})
	state = push_state(2)
	handlers[1](state)
	state = push_state(3)
	state.lastStart.firstPlayer = nil
	handlers[1](state)
	equal(#dispatched, 1)
	equal(dispatched[1].params.firstPlayer, nil)
end)

test("a player who was not ready at the start does not start the blind", function()
	setup({}, { id = "u2", is_host = false })
	seed_and_push("u1", { "u1" })
	equal(#dispatched, 0)
end)

test("a player in the start's list starts the blind", function()
	setup({}, { id = "u2", is_host = false })
	seed_and_push("u1", { "u1", "u2" })
	equal(#dispatched, 1)
end)

test("a start with no player list is an error: logged, and no blind starts", function()
	setup({}, { id = "u2", is_host = false })
	state = push_state(2)
	handlers[1](state)
	state = push_state(3)
	state.lastStart.players = nil
	handlers[1](state)
	equal(#dispatched, 0)
	assert(#logs >= 1 and logs[#logs].text:find("error", 1, true), "the missing list must be logged")
end)

test("an eliminated player does not start the blind", function()
	setup({ eliminated = true })
	seed_and_push("u1")
	equal(#dispatched, 0)
end)

test("a player who is not in the start does not start the blind", function()
	setup({}, { id = "u9", is_host = false })
	seed_and_push("u1")
	equal(#dispatched, 0)
end)

test("on_state and the deferred resync reading the same push start it once", function()
	setup({})
	seed_and_push("u1")
	PVP.ReadyNet.on_snapshot()
	PVP.ReadyNet.update()
	equal(#dispatched, 1)
end)

test("a second start during the countdown is ignored: the round id stays, the log says so", function()
	setup({})
	seed_and_push("u1")
	equal(PVP.GAME.round_id, 3)
	equal(#dispatched, 1)
	PVP.GAME.pvp_countdown_in_progress = true
	logs = {}
	state = push_state(4)
	handlers[1](state)
	equal(PVP.GAME.round_id, 3)
	equal(#dispatched, 1)
	equal(refreshes, 1)
	local said
	for _, l in ipairs(logs) do
		if l.level == "info" and l.text == "[pvp] start of round 4 ignored: countdown running" then said = true end
	end
	equal(said, true)
	-- The ignored start is spent: the next read of the same state starts nothing.
	PVP.GAME.pvp_countdown_in_progress = nil
	handlers[1](state)
	equal(#dispatched, 1)
end)

-- A reconnect in the middle of the countdown wipes PVP.GAME. The countdown ends, hands its round
-- back, and the same state starts the blind again: select_blind is reached exactly once.
local function reconnect_mid_countdown(between)
	setup({})
	local f = assert(io.open("ui/game/timer.lua", "rb"))
	local text = f:read("*a"):gsub("%s*" .. string.char(13) .. "?" .. string.char(10), string.char(10))
	f:close()
	local nl = string.char(10)
	local body = assert(text:match(nl .. "function PVP.UI.start_pvp_countdown%b()" .. ".-" .. nl .. "end" .. nl), "countdown not found")
	local events, selected = {}, 0
	G.CONTROLLER = { locks = {} }
	G.E_MANAGER = { add_event = function(_, e) events[#events + 1] = e end }
	G.FUNCS = { attention_text_realtime = function() end }
	G.C = { MULT = {} }
	G.play = {}
	Event = function(t) return t end
	play_sound = function() end
	PVP.UI = {}
	PVP.DEFAULT_COUNTDOWN_SECONDS = 3
	PVP.LOBBY = { config = { pvp_countdown_seconds = 3 } }
	assert(loadstring(body, "=start_pvp_countdown"))()
	-- The action handler of startBlind, as it runs the countdown.
	PVP.dispatch_action = function(name)
		assert(name == "startBlind")
		if PVP.GAME.pvp_countdown_in_progress then return end
		PVP.UI.start_pvp_countdown(function()
			if PVP.GAME.next_blind_context then selected = selected + 1 end
		end)
	end
	PVP.GAME.next_blind_context = { id = "ctx" }
	state = push_state(2)
	handlers[1](state)
	state = push_state(3)
	handlers[1](state)
	equal(PVP.GAME.pvp_countdown_in_progress, true)
	-- One tick, then the reconnect resets PVP.GAME (the record is module-level and survives).
	table.remove(events, 1).func()
	PVP.GAME = {}
	between()
	local guard = 0
	while #events > 0 and guard < 200 do
		guard = guard + 1
		table.remove(events, 1).func()
	end
	equal(selected, 1)
	equal(G.CONTROLLER.locks.enter_pvp, nil)
end

test("a reconnect in the middle of the countdown still reaches select_blind exactly once", function()
	reconnect_mid_countdown(function() end)
end)

-- The CONNECTED handler reads the state between the reset and the countdown's abort tick: it must
-- not start the blind itself (the round is counted as started) nor spoil the hand-back.
test("a CONNECTED read between the reset and the abort tick still selects exactly once", function()
	reconnect_mid_countdown(function()
		PVP.ReadyNet.on_connected()
		PVP.ReadyNet.on_snapshot()
		PVP.ReadyNet.update()
	end)
end)

test("a snapshot that starts a missed blind does not then press Ready again", function()
	setup({ ready_intent = true })
	state = push_state(2)
	handlers[1](state)
	state = push_state(3)
	PVP.ReadyNet.on_snapshot()
	PVP.ReadyNet.update()
	equal(#dispatched, 1)
	equal(#requests, 0)
end)

test("detached at the first snapshot: CONNECTED seeds the record, so a later start still starts", function()
	setup({})
	current = nil
	state = push_state(2)
	handlers[1](state) -- the first snapshot lands while the lobby is detached
	current = lobby
	PVP.ReadyNet.evaluate() -- what the CONNECTED handler runs
	equal(#dispatched, 0) -- the snapshot's lastStart counts as already started
	state = push_state(3)
	handlers[1](state)
	equal(#dispatched, 1)
	-- And the bridge really does that on CONNECTED.
	local file = assert(io.open("pvp_api/lobby_bridge.lua", "rb"))
	local text = file:read("*a")
	file:close()
	local from = assert(text:find("LobbyEvent.CONNECTED, function()", 1, true))
	local to = text:find("lobby:on(", from + 10, true) or #text
	assert(text:sub(from, to):find("PVP.CONNECTED_ORDER", 1, true), "CONNECTED must run PVP.CONNECTED_ORDER")
	assert(text:find('PVP.CONNECTED_ORDER = { "ReadyNet"', 1, true), "ReadyNet must read first in PVP.CONNECTED_ORDER")
end)

test("a refused Unready keeps the intent the state shows, so one click fixes it", function()
	setup({ ready_intent = false })
	state = { runId = "r-abc", round = 2, ready = { u1 = true }, lastStart = push_state(2).lastStart }
	PVP.ReadyNet.request_unready()
	equal(requests[1].kind, "pvp.unready")
	requests[1].on_result(false, { reason = "timeout" })
	equal(PVP.GAME.ready_intent, true)
	-- A refused Ready while the state shows not ready clears the intent.
	state = push_state(2)
	PVP.ReadyNet.request_ready()
	requests[2].on_result(false, { reason = "not_connected" })
	equal(PVP.GAME.ready_intent, false)
end)

test("Ready on ante 2 with the Boss on deck names the blind", function()
	setup({ ready_intent = true })
	state = push_state(2)
	PVP.ReadyNet.request_ready()
	equal(#requests, 1)
	equal(requests[1].payload.blindKey, "2:Boss")
	equal(requests[1].payload.runId, "r-abc")
	equal(requests[1].payload.roundId, 3)
	equal(requests[1].payload.startingHands, nil)
	G.GAME.round_resets.ante = 5
	G.GAME.blind_on_deck = "Small"
	PVP.ReadyNet.request_ready()
	equal(requests[2].payload.blindKey, "5:Small")
end)

-- A Manhunt voucher lowers the ante after the PvP Boss was set. The Ready names the Boss at
-- the ante the game is on now; the server accepts a Boss at any ante.
test("Ready after the ante was lowered below the PvP start still names the Boss", function()
	setup({ ready_intent = true })
	state = push_state(2)
	G.GAME.round_resets.ante = 1
	PVP.ReadyNet.request_ready()
	equal(requests[1].payload.blindKey, "1:Boss")
end)

test("a not_pvp_blind refusal leaves the player not ready, says so, and presses nothing again", function()
	setup({ ready_intent = true })
	local shown = 0
	attention_text = function()
		shown = shown + 1
	end
	state = push_state(2)
	PVP.ReadyNet.request_ready()
	requests[1].on_result(false, { reason = "not_pvp_blind" })
	equal(PVP.GAME.ready_intent, false)
	equal(shown, 1)
	-- A snapshot and the next frame do not press Ready again: the intent is gone.
	PVP.ReadyNet.on_snapshot()
	PVP.ReadyNet.update()
	equal(#requests, 1)
	-- The button is usable again: a fresh press sends a fresh request.
	PVP.ReadyNet.request_ready()
	equal(#requests, 2)
end)

test("a refusal because the state moved on is quiet", function()
	setup({ ready_intent = true })
	local shown = 0
	attention_text = function()
		shown = shown + 1
	end
	state = push_state(2)
	PVP.ReadyNet.request_ready()
	requests[1].on_result(false, { reason = "round_over" })
	equal(shown, 0)
	PVP.ReadyNet.request_ready()
	requests[2].on_result(false, { reason = "timeout" })
	equal(shown, 1)
end)

local dropped = push_state(2)

test("snapshot shows me not ready while the local Ready is set: a new pvp.ready is sent", function()
	setup({ ready_intent = true })
	state = dropped
	PVP.ReadyNet.on_snapshot()
	equal(#requests, 0) -- deferred to the next frame
	PVP.ReadyNet.update()
	equal(#requests, 1)
	equal(requests[1].kind, "pvp.ready")
	equal(requests[1].payload.runId, "r-abc")
	equal(requests[1].payload.roundId, 3)
	equal(requests[1].payload.startingHands, nil)
	equal(requests[1].payload.blindKey, "2:Boss")
end)

test("no new request when the server still has me ready", function()
	setup({ ready_intent = true })
	state = push_state(2, { u1 = true })
	PVP.ReadyNet.on_snapshot()
	PVP.ReadyNet.update()
	equal(#requests, 0)
end)

test("no new request when I did not press Ready", function()
	setup({ ready_intent = false })
	state = dropped
	PVP.ReadyNet.on_snapshot()
	PVP.ReadyNet.update()
	equal(#requests, 0)
end)

test("no state yet (before the first snapshot) does nothing and does not error", function()
	setup({ ready_intent = true })
	state = nil
	PVP.ReadyNet.on_snapshot()
	PVP.ReadyNet.update()
	handlers[1](nil, nil)
	equal(#requests, 0)
end)

test("the Ready button follows the state and replays record what was shown", function()
	setup({})
	state = push_state(2, { u1 = true })
	PVP.ReadyNet.evaluate()
	equal(PVP.GAME.ready_blind, true)
	state = dropped
	PVP.ReadyNet.evaluate()
	equal(PVP.GAME.ready_blind, false)
	equal(#replay, 2)
	equal(replay[1][2], 1)
	equal(replay[2][2], 0)
	PVP.ReadyNet.evaluate()
	equal(#replay, 2) -- only on a change
end)

-- A crash rejoin mid-round: the new process has no record, so lastStart counts as started and no
-- blind starts, but every fact of the round in play still names it (PVP.GAME.round_id).
test("a rejoin mid-round (no record, lastStart 3) sets the round id and starts no blind", function()
	setup({})
	state = push_state(3)
	handlers[1](state)
	equal(PVP.GAME.round_id, 3)
	equal(#dispatched, 0)
	handlers[1](state)
	equal(PVP.GAME.round_id, 3)
	equal(#dispatched, 0)
end)

-- A reconnect inside the same process: the record survives (module-level) but the lobby mirror
-- reset wiped PVP.GAME, so the round id must come back from the record that is already held.
test("a reconnect in the same process (record held, round id wiped) restores the round id", function()
	setup({})
	seed_and_push("u1")
	equal(#dispatched, 1)
	PVP.GAME.round_id = nil
	handlers[1](state)
	equal(PVP.GAME.round_id, 3)
	equal(#dispatched, 1)
end)

test("a state of another run than the lobby's does not set the round id", function()
	setup({})
	seed_and_push("u1")
	PVP.GAME.round_id = nil
	lobby._game.started = { run_id = "r-next" }
	state.runId = "r-other"
	handlers[1](state)
	equal(PVP.GAME.round_id, nil)
	equal(#dispatched, 1)
end)

test("a rejoin where I was not in the start does not take its round id", function()
	setup({}, { id = "u9", is_host = false })
	state = push_state(3)
	handlers[1](state)
	equal(PVP.GAME.round_id, nil)
	equal(#dispatched, 0)
end)

test("a run with no start yet leaves the round id nil", function()
	setup({})
	state = push_state(0)
	state.lastStart = nil
	handlers[1](state)
	equal(PVP.GAME.round_id, nil)
	equal(#dispatched, 0)
end)

test("a start after the adopted round still sets the new round id and starts the blind", function()
	setup({})
	state = push_state(3)
	handlers[1](state)
	state = push_state(4)
	handlers[1](state)
	equal(PVP.GAME.round_id, 4)
	equal(#dispatched, 1)
end)

os.exit(failures == 0 and 0 or 1)
