-- Plain Lua test for the fire and lost reports of pvp_api/traps_net.lua with the real lib/trap_utils.lua over a
-- fake MPAPI: a report is kept in the carried record, sent only in a live run, resent after a catch-up or a lost
-- connection while the trap is live, and a refused fire settles as lost.
-- Run from the repo root: luajit tests/unit/traps_net_test.lua
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

local requests, state, live, logs

local function setup()
	requests, state, live, logs = {}, {}, true, {}
	local lobby = { player_id = "me", mod_id = "pvp", _nakama = true, _game = { started = { run_id = "run1" } } }
	MPAPI = {
		get_current_lobby = function()
			return lobby
		end,
		get_state = function(key)
			return state[key]
		end,
		request = function(kind, payload, on_result)
			requests[#requests + 1] = { kind = kind, payload = payload, on_result = on_result }
		end,
	}
	Card = {
		start_dissolve = function() end,
		can_sell_card = function()
			return true
		end,
	}
	PVP = {
		id = "pvp",
		in_session = function()
			return true
		end,
		match_log = function(_, text)
			logs[#logs + 1] = text
		end,
		UI = {},
		GAME = {},
		current_run_id = function()
			return "run1"
		end,
		NetBasics = {
			pvp_lobby = function()
				return lobby
			end,
		},
		OpponentNet = {
			is_live = function()
				return live
			end,
			can_apply = function()
				return live
			end,
			on_connected = function() end,
		},
		RunGate = {
			loaded = function()
				return true
			end,
		},
		TRAP_ROW = { refresh = function() end },
	}
	G = { consumeables = { cards = {} }, E_MANAGER = { add_event = function() end } }
	SMODS = {
		add_card = function()
			return nil
		end,
	}
	dofile("lib/_state_value.lua")
	dofile("lib/applied_trap_rewards.lua")
	dofile("lib/trap_utils.lua")
	PVP.TRAP.reveal_and_consume = function() end
	dofile("pvp_api/traps_net.lua")
end

local function value(traps)
	return { runId = "run1", trapSeq = #traps, traps = traps }
end

local function trap(id, state_)
	return { id = id, key = "c_mp_trap_alarm", owner = "they", holder = "me", state = state_ }
end

local function card_of(id)
	return { ability = { mp_trap_id = id }, config = { center = { key = "c_mp_trap_alarm" } } }
end

test("fire: sent at once in a live run, with the run and the trap id, and no data key for a trap with none", function()
	setup()
	state["pvp.traps"] = value({ trap(1, "live") })
	PVP.TRAP.fire(card_of(1))
	equal(#requests, 1)
	equal(requests[1].kind, "pvp.trap_fire")
	equal(requests[1].payload.trapId, 1)
	equal(requests[1].payload.runId, "run1")
	equal(requests[1].payload.data, nil)
	local json = dofile(os.getenv("MPAPI_JSON") or "D:/mp/api/lib/nakama/util/json.lua")
	assert(not json.encode(requests[1].payload):find('"data"', 1, true), "no data field on the wire")
end)

test("fire: a data trap sends its data", function()
	setup()
	state["pvp.traps"] = value({ trap(1, "live") })
	PVP.TRAP.fire(card_of(1), { hand_type = "Pair" })
	equal(requests[1].payload.data.hand_type, "Pair")
	local json = dofile(os.getenv("MPAPI_JSON") or "D:/mp/api/lib/nakama/util/json.lua")
	assert(json.encode(requests[1].payload):find('"data":{', 1, true), "data is an object on the wire")
end)

test("fire during a catch-up is kept, not sent, and sent after the attach while the trap is live", function()
	setup()
	live = false
	state["pvp.traps"] = value({ trap(1, "live") })
	PVP.TRAP.fire(card_of(1), { hand_type = "Pair" })
	equal(#requests, 0)
	equal(PVP.GAME.traps_sent.ids["1"].kind, "pvp.trap_fire")
	PVP.TrapsNet.resend()
	equal(#requests, 0, "still not live")
	live = true
	PVP.TrapsNet.on_connected()
	equal(#requests, 1)
	equal(requests[1].kind, "pvp.trap_fire")
	equal(requests[1].payload.data.hand_type, "Pair")
	PVP.TrapsNet.resend()
	equal(#requests, 1, "not sent twice while in flight")
end)

test("resend: a trap the record already settled is not sent", function()
	setup()
	live = false
	state["pvp.traps"] = value({ trap(1, "live") })
	PVP.TRAP.fire(card_of(1))
	state["pvp.traps"] = value({ trap(1, { fired = {} }) })
	live = true
	PVP.TrapsNet.on_connected()
	equal(#requests, 0)
end)

test("resend: a connection lost under a report resends it at the next connect", function()
	setup()
	state["pvp.traps"] = value({ trap(1, "live") })
	PVP.TRAP.fire(card_of(1))
	requests[1].on_result(false, { reason = "not_connected" })
	equal(#requests, 1)
	PVP.TrapsNet.on_connected()
	equal(#requests, 2)
	equal(requests[2].kind, "pvp.trap_fire")
end)

test("a fire the server refuses for good settles as lost, with no reward", function()
	setup()
	state["pvp.traps"] = value({ trap(1, "live") })
	PVP.TRAP.fire(card_of(1))
	requests[1].on_result(false, { reason = "bad_payload" })
	equal(#requests, 2)
	equal(requests[2].kind, "pvp.trap_lost")
	equal(requests[2].payload.trapId, 1)
	equal(requests[2].payload.data, nil)
	equal(PVP.GAME.traps_sent.ids["1"].kind, "pvp.trap_lost")
	-- A refused lost is only logged: no loop.
	requests[2].on_result(false, { reason = "bad_payload" })
	equal(#requests, 2)
end)

local function fire_and_refuse(reason, kind_card)
	setup()
	state["pvp.traps"] = value({ trap(1, "live") })
	PVP.TRAP.fire(kind_card or card_of(1))
	requests[1].on_result(false, { reason = reason })
end

test("not_holder is final: no lost report, and the report is not resent", function()
	fire_and_refuse("not_holder")
	equal(#requests, 1)
	equal(PVP.GAME.traps_sent.ids["1"].given_up, true)
	PVP.TrapsNet.on_connected()
	equal(#requests, 1)
end)

test("already_fired is final: the report is not resent, and the card is not rebuilt before the record settles", function()
	fire_and_refuse("already_fired")
	equal(#requests, 1)
	equal(PVP.GAME.traps_sent.ids["1"].given_up, true)
	PVP.TrapsNet.on_connected()
	equal(#requests, 1)
end)

for _, reason in ipairs({ "not_running", "wrong_run", "unknown_trap", "round_over" }) do
	test(reason .. " is not final: the report is kept and resent, never turned into lost", function()
		fire_and_refuse(reason)
		equal(#requests, 1)
		equal(PVP.GAME.traps_sent.ids["1"].kind, "pvp.trap_fire")
		equal(PVP.GAME.traps_sent.ids["1"].given_up, nil)
		PVP.TrapsNet.on_connected()
		equal(#requests, 2)
		equal(requests[2].kind, "pvp.trap_fire")
	end)
end

test("a refusal that arrives after the run changed is dropped", function()
	fire_and_refuse("bad_payload")
	setup()
	state["pvp.traps"] = value({ trap(1, "live") })
	PVP.TRAP.fire(card_of(1))
	PVP.current_run_id = function()
		return "run2"
	end
	requests[1].on_result(false, { reason = "bad_payload" })
	equal(#requests, 1)
end)

test("a lost report refused for good is given up once: logged once, not resent", function()
	setup()
	state["pvp.traps"] = value({ trap(1, "live") })
	PVP.TRAP.remember_report(1, "pvp.trap_lost")
	equal(#requests, 1)
	requests[1].on_result(false, { reason = "not_holder" })
	local errors = 0
	for _, text in ipairs(logs) do
		if text:find("given up", 1, true) then errors = errors + 1 end
	end
	equal(errors, 1)
	equal(PVP.GAME.traps_sent.ids["1"].given_up, true)
	PVP.TrapsNet.on_connected()
	PVP.TrapsNet.on_connected()
	equal(#requests, 1)
end)

test("a Snare with no tag is spent and reported lost, with no fire sent", function()
	setup()
	state["pvp.traps"] = value({ trap(1, "live") })
	local card = card_of(1)
	PVP.TRAP.fire_unpaid(card)
	equal(card.ability.mp_trap_fired, true)
	equal(#requests, 1)
	equal(requests[1].kind, "pvp.trap_lost")
	equal(requests[1].payload.data, nil)
end)

test("already_fired is a quiet answer: no lost report", function()
	setup()
	state["pvp.traps"] = value({ trap(1, "live") })
	PVP.TRAP.fire(card_of(1))
	requests[1].on_result(false, { reason = "already_fired" })
	equal(#requests, 1)
end)

test("lost: a destroyed unfired trap is reported once", function()
	setup()
	state["pvp.traps"] = value({ trap(1, "live") })
	local card = card_of(1)
	card.ability.mp_trap_hidden = true
	card.area = G.consumeables
	Card.start_dissolve(card)
	equal(#requests, 1)
	equal(requests[1].kind, "pvp.trap_lost")
end)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
