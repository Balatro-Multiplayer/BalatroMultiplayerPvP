-- Plain Lua test for pvp_api/opponent_net.lua over a fake MPAPI: what each action's request carries, when
-- nothing is sent (practice, no lobby, a crash rejoin's catch-up) and the apply gate.
-- Run from the repo root: luajit tests/unit/opponent_net_test.lua
local requests, logs, listeners, state, lobby, dollars

local passed, failed = 0, 0
local function equal(got, want, what)
	assert(got == want, ("%s: got %s, wanted %s"):format(what or "value", tostring(got), tostring(want)))
end

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("ok   " .. name)
	else
		failed = failed + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function setup(opts)
	opts = opts or {}
	requests, logs, listeners, state, dollars = {}, {}, {}, {}, 0
	lobby = {
		mod_id = "pvp",
		player_id = "me",
		_nakama = true,
		_holding = false,
		_game = { started = { run_id = "run1" } },
	}
	if opts.no_lobby then lobby = nil end
	MPAPI = {
		get_current_lobby = function()
			return lobby
		end,
		request = function(kind, payload, on_result)
			requests[#requests + 1] = { kind = kind, payload = payload, on_result = on_result }
		end,
		get_state = function(key)
			return state[key]
		end,
		on_state = function(key, fn)
			listeners[key] = fn
		end,
	}
	PVP = {
		id = "pvp",
		SP = { practice = opts.practice or false },
		match_log = function(_, text)
			logs[#logs + 1] = text
		end,
		GAME = {},
	}
	G = {
		STATES = { BLIND_SELECT = 1, SHOP = 2, SELECTING_HAND = 3, HAND_PLAYED = 4 },
		STATE = 2,
		GAME = { round_resets = { ante = 2 } },
	}
	ease_dollars = function(amount)
		dollars = dollars + amount
	end
	dofile("pvp_api/_net_basics.lua")
	dofile("lib/opponent_record.lua")
	dofile("pvp_api/opponent_net.lua")
end

local function log_has(text)
	for _, line in ipairs(logs) do
		if line:find(text, 1, true) then return true end
	end
	return false
end

local function keys(payload)
	local out = {}
	for key in pairs(payload) do
		out[#out + 1] = key
	end
	table.sort(out)
	return table.concat(out, ",")
end

test("a sell is one request with the run and the ante, and no sequence number", function()
	setup()
	PVP.OpponentNet.report_sell()
	equal(#requests, 1)
	equal(requests[1].kind, "pvp.sell")
	equal(requests[1].payload.runId, "run1")
	equal(requests[1].payload.ante, 2)
	equal(keys(requests[1].payload), "ante,runId")
end)

test("every action goes out at once, without waiting for the answer to the one before", function()
	setup()
	PVP.OpponentNet.report_sell()
	PVP.OpponentNet.report_sell()
	PVP.OpponentNet.send_request("pvp.effect", { kind = "pizza" })
	equal(#requests, 3)
	equal(requests[3].kind, "pvp.effect")
	equal(keys(requests[3].payload), "kind,runId")
end)

test("a sell with no ante is not sent", function()
	setup()
	G.GAME.round_resets.ante = nil
	PVP.OpponentNet.report_sell()
	equal(#requests, 0)
	assert(log_has("no ante"))
end)

test("shop: a spend carries the spend; a skip is a skipped slot", function()
	setup()
	PVP.OpponentNet.report_shop(9)
	equal(requests[1].kind, "pvp.shop")
	equal(keys(requests[1].payload), "runId,spent")
	equal(requests[1].payload.spent, 9)
	PVP.OpponentNet.report_skip()
	equal(requests[2].kind, "pvp.shop")
	equal(keys(requests[2].payload), "runId,skipped")
	equal(requests[2].payload.skipped, true)
end)

test("shop: leaving without spending sends the spend as an explicit 0", function()
	setup()
	PVP.OpponentNet.report_shop(0)
	equal(keys(requests[1].payload), "runId,spent")
	equal(requests[1].payload.spent, 0)
end)

test("B3: a spend that is not a number from 0 up is sent without a spend, never as 0", function()
	for _, bad in ipairs({ 0 / 0, -3, math.huge, "x", true }) do
		setup()
		PVP.OpponentNet.report_shop(bad)
		equal(#requests, 1, "request for " .. tostring(bad))
		equal(keys(requests[1].payload), "runId", "payload for " .. tostring(bad))
		assert(log_has("not a number"))
	end
end)

test("a refusal is logged and the request is not repeated here", function()
	setup()
	PVP.OpponentNet.report_sell()
	requests[1].on_result(false, { reason = "over_cap" })
	equal(#requests, 1)
end)

test("catch-up: nothing is sent while the replay runs, and sending resumes after attach", function()
	setup()
	PVP.OpponentNet.begin_catch_up()
	PVP.OpponentNet.report_sell()
	PVP.OpponentNet.report_shop(3)
	PVP.OpponentNet.report_skip()
	equal(#requests, 0)
	PVP.OpponentNet.end_catch_up()
	PVP.OpponentNet.report_sell()
	equal(#requests, 1)
end)

test("catch-up: aborted stops the replay mode", function()
	setup()
	PVP.OpponentNet.begin_catch_up()
	PVP.OpponentNet.abort_catch_up()
	PVP.OpponentNet.report_sell()
	equal(#requests, 1)
end)

test("catch-up: end_catch_up gives the carried records without a run the live run", function()
	setup()
	PVP.GAME.opponent_applied = { runId = nil, index = 3 }
	PVP.GAME.traps_applied = { runId = "other", index = 1 }
	PVP.GAME.pincher_pending = { items = {} }
	PVP.OpponentNet.begin_catch_up()
	PVP.OpponentNet.end_catch_up()
	equal(PVP.GAME.opponent_applied.runId, "run1")
	equal(PVP.GAME.opponent_applied.index, 3)
	equal(PVP.GAME.traps_applied.runId, "other")
	equal(PVP.GAME.pincher_pending.runId, "run1")
end)

test("catch-up: a whole-log catch-up with no run yet takes the run from pvp.round", function()
	setup()
	lobby._game = nil
	state["pvp.round"] = { runId = "run7" }
	PVP.GAME.opponent_applied = {}
	PVP.OpponentNet.end_catch_up()
	equal(PVP.GAME.opponent_applied.runId, "run7")
end)

test("a playback in practice sends nothing", function()
	setup({ practice = true })
	PVP.OpponentNet.report_sell()
	PVP.OpponentNet.report_shop(3)
	PVP.OpponentNet.report_skip()
	equal(#requests, 0)
end)

test("nothing is sent with no lobby, a detached lobby or another mod's lobby", function()
	setup({ no_lobby = true })
	PVP.OpponentNet.report_sell()
	setup()
	lobby._holding = true
	PVP.OpponentNet.report_sell()
	setup()
	lobby.mod_id = "other"
	PVP.OpponentNet.report_sell()
	setup()
	lobby._game = nil
	PVP.OpponentNet.report_sell()
	equal(#requests, 0)
end)

test("can_apply: only at blind select, shop or selecting a hand, and only in a live attached run", function()
	setup()
	G.STATE = G.STATES.SHOP
	equal(PVP.OpponentNet.can_apply(), true)
	G.STATE = G.STATES.BLIND_SELECT
	equal(PVP.OpponentNet.can_apply(), true)
	G.STATE = G.STATES.SELECTING_HAND
	equal(PVP.OpponentNet.can_apply(), true)
	G.STATE = G.STATES.HAND_PLAYED
	equal(PVP.OpponentNet.can_apply(), false, "scoring")
	G.STATE = G.STATES.SHOP
	PVP.OpponentNet.begin_catch_up()
	equal(PVP.OpponentNet.can_apply(), false, "during catch-up")
	PVP.OpponentNet.end_catch_up()
	equal(PVP.OpponentNet.can_apply(), true, "after attach")
	lobby._holding = true
	equal(PVP.OpponentNet.can_apply(), false, "detached")
end)

test("can_apply: false in practice", function()
	setup({ practice = true })
	equal(PVP.OpponentNet.can_apply(), false)
end)

test("on_connected(fn) registers a listener that runs at every on_connected()", function()
	setup()
	local calls = 0
	PVP.OpponentNet.on_connected(function()
		calls = calls + 1
	end)
	equal(calls, 0)
	PVP.OpponentNet.on_connected()
	PVP.OpponentNet.on_connected()
	equal(calls, 2)
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
