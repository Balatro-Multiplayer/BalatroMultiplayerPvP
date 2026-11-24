-- Run from the repo root: luajit tests/unit/match_net_test.lua
-- pvp_api/net/server_link.lua: numbered inputs with resends, the stored view and clock offset, the inbox
-- (one item per safe point, in order, once), the join keys and the put-off Run save.
local unpack = unpack or table.unpack
local T = dofile("tests/support/check.lua")
local eq = T.eq

local net, sent, warnings, queue, now, socket_up, calls, lobby_mod, view_handler, gone_handler

local function setup()
	sent, warnings, queue, now, socket_up, calls, lobby_mod = {}, {}, {}, 0, true, {}, "MultiplayerPvP"
	view_handler, gone_handler = nil, nil
	PVP = { NET = {}, READ = {}, UI = {}, PRACTICE = {}, id = "MultiplayerPvP", UTILS = { is_pvp_blind = function() return false end } }
	love = { timer = { getTime = function() return now end } }
	sendWarnMessage = function(text) warnings[#warnings + 1] = text end
	G = {
		STAGE = "run",
		STAGES = { RUN = "run" },
		STATES = { BLIND_SELECT = 1, SHOP = 2, SELECTING_HAND = 3, BOOSTER = 9 },
		STATE = 1,
		STATE_COMPLETE = true,
		GAME = {},
		E_MANAGER = { add_event = function(_, event) queue[#queue + 1] = event end },
	}
	Event = function(fields) return fields end
	MPAPI = {
		playback = { is_driving = function() return false end },
			get_current_lobby = function() return lobby_mod and { mod_id = lobby_mod } or nil end,
		send_match_input = function(_, input)
			calls[#calls + 1] = "send " .. input.kind
			if socket_up then sent[#sent + 1] = input end
			return socket_up
		end,
		on_match_view = function(_, fn) view_handler = fn calls[#calls + 1] = "view_handler" end,
		add_join_keys = function() calls[#calls + 1] = "join_keys" end,
		on_lobby_gone = function(_, fn) gone_handler = fn calls[#calls + 1] = "lobby_gone" end,
		run_save = {
			register_save_wait = function() calls[#calls + 1] = "save_wait" end,
			save_now = function() calls[#calls + 1] = "save_now" end,
			is_staged = function() return false end,
		},
	}
	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/net/_rules.lua")
	dofile("pvp_api/net/server_link.lua")
	net = PVP.NET
end

-- Runs the blocking events the net queued, oldest first, as the game's event queue would.
local function run_queue()
	local rest = {}
	for _, event in ipairs(queue) do
		if event.blocking == false then rest[#rest + 1] = event
		elseif not event.func() then rest[#rest + 1] = event end
	end
	queue = rest
end

-- The engine's clear_queue deletes every event that is not no_delete.
local function clear_queue()
	local kept = {}
	for _, event in ipairs(queue) do
		if event.no_delete then kept[#kept + 1] = event end
	end
	queue = kept
end

local function view(fields)
	local value = { serverTime = 1000, lastMessageReceived = 0, me = "a", match = {}, players = {}, timers = {}, onlyMine = { inbox = {}, inboxNewest = 0 } }
	for key, item in pairs(fields or {}) do value[key] = item end
	return value
end

local function in_run(inbox, inbox_done, view_run)
	G.GAME.pvp_net = { runId = "run1", inboxDone = inbox_done or 0, totals = {} }
	return view({ match = { run = { id = view_run or "run1" } }, onlyMine = { inbox = inbox, inboxNewest = #inbox } })
end

local function item(number, effect) return { itemNumber = number, effect = effect or "pizza", amount = 1 } end

local function numbers(list)
	local out = {}
	for index, input in ipairs(list) do out[index] = input.messageNumber end
	return table.concat(out, ",")
end

-- Nothing is called by loading the file.
setup()
eq(#calls, 0, "loading calls no API function")
eq(#queue, 0, "loading queues nothing")
net.register()
eq(table.concat(calls, ","), "view_handler,join_keys,save_wait,lobby_gone", "register is the one place that wires the API")

-- register follows the lobby: a view of another lobby starts the numbers over, and only the gone
-- hook of the lobby the numbers belong to resets them
setup()
net.register()
local lobby = {}
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
view_handler(lobby, view())
eq(net.view ~= nil, true, "the view reaches net")
net.send("ready", {})
sent = {}
view_handler(lobby, view())
eq(net.waiting(), true, "another view of the same lobby keeps the unconfirmed input")
gone_handler(lobby)
eq(net.view, nil, "an exit from the lobby is a reset")
eq(net.send("ready", {}), nil, "with the numbers forgotten")

-- an old lobby's late gone hook does not wipe the current match's unconfirmed inputs
setup()
net.register()
local old_lobby, new_lobby = {}, {}
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
view_handler(old_lobby, view())
view_handler(new_lobby, view())
net.send("team", { team = "A" })
gone_handler(old_lobby)
eq(net.waiting("team"), true, "the unconfirmed input of the current match is kept")
eq(net.view ~= nil, true, "and so is its view")
gone_handler(new_lobby)
eq(net.waiting(), false, "the current lobby's own gone hook resets")

-- a new lobby with no gone hook starts numbering from 1 again, with nothing left over
setup()
net.register()
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
view_handler(old_lobby, view({ lastMessageReceived = 9 }))
eq(net.send("ready", {}), 10, "the first lobby's numbers go on from its view")
view_handler(new_lobby, view({ lastMessageReceived = 0 }))
eq(net.waiting(), false, "the old lobby's unconfirmed input is gone")
eq(net.send("ready", {}), 1, "the new lobby starts from 1")

-- join keys are asked at every join and rejoin: a restarted game holds its saves until the first view
setup()
net.register()
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
eq(net.save_must_wait(), false, "before any join nothing is held")
net.join_keys({ save = { GAME = G.GAME } })
eq(net.save_must_wait(), true, "asking for the join keys holds the save until the first view")
view_handler(old_lobby, view())
eq(net.save_must_wait(), false, "the first view releases it")

-- net_send_numbers_and_resends
setup()
G.GAME.pvp_net = { runId = "run1", inboxDone = 4, totals = {} }
eq(net.send("ready", { ready = true, blindKey = "2:Boss" }), nil, "nothing is sent before the first view")
eq(#sent, 0, "no input left before the first view")
net.receive_view(nil, view())
eq(net.send("ready", { ready = true, blindKey = "2:Boss" }), 1, "the first input is number 1")
eq(net.send("progress", { ante = 2, location = "shop" }), 2, "the next is number 2")
eq(numbers(sent), "1,2", "each input goes out when it is sent")
eq(sent[1].inboxDone, 4, "the header carries the last applied number")
eq(sent[1].runId, "run1", "the header carries the run id")
local first_bytes = sent[1]
local resend_times = {}
for step = 1, 40 do
	now = step * 0.5
	local before = #sent
	net.update()
	if #sent > before then
		resend_times[#resend_times + 1] = now
		eq(numbers({ unpack(sent, before + 1) }), "1,2", "a resend is every unconfirmed input, oldest first")
		eq(sent[before + 1], first_bytes, "a resend sends the same input")
	end
end
eq(table.concat(resend_times, ","), "0.5,1.5,3.5,7.5,11.5,15.5,19.5", "resends at 0.5, 1.5, 3.5, 7.5, 11.5 s, then every 4 s")
net.receive_view(nil, view({ lastMessageReceived = 1 }))
eq(net.waiting(), true, "input 2 is still unconfirmed")
eq(net.waiting("progress"), true, "waiting by kind")
eq(net.waiting("ready"), false, "input 1 is confirmed")
local count = #sent
now = 100
net.update()
eq(numbers({ unpack(sent, count + 1) }), "2", "only the unconfirmed input is sent again")
net.receive_view(nil, view({ lastMessageReceived = 2 }))
count = #sent
now = 200
net.update()
eq(#sent, count, "a confirmed input is never sent again")
eq(net.waiting(), false, "nothing is waiting")
-- The latest unconfirmed input of a kind: what a second Ready press toggles from.
net.send("ready", { ready = true, blindKey = "2:Boss" })
net.send("ready", { ready = false, blindKey = "2:Boss" })
eq(net.latest_waiting("ready").ready, false, "the latest unconfirmed ready")
eq(net.latest_waiting("progress"), nil, "none of a kind waiting")
net.receive_view(nil, view({ lastMessageReceived = 4 }))
eq(net.latest_waiting("ready"), nil, "confirmed: none waiting")

-- a resend marks every input it sent: the one left after a partial confirm keeps its own schedule
setup()
net.receive_view(nil, view())
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
net.send("progress", { ante = 1, location = "x" })
net.send("progress", { ante = 2, location = "y" })
now = 0.5
net.update()
eq(numbers(sent), "1,2,1,2", "both go out again once the oldest is due")
now = 0.6
net.receive_view(nil, view({ lastMessageReceived = 1 }))
net.update()
eq(numbers(sent), "1,2,1,2", "input 2 waits for its own next gap, no burst")

-- a failed send is tried again, oldest first, and never skips ahead
setup()
net.receive_view(nil, view())
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
socket_up = false
net.send("progress", { ante = 1, location = "x" })
net.send("progress", { ante = 2, location = "y" })
eq(#sent, 0, "nothing left while the socket is down")
socket_up = true
now = 1
net.update()
eq(numbers(sent), "1,2", "both go out once the socket is back, oldest first")

-- after a failed send the next try is 0.5 s later, not 4
setup()
net.receive_view(nil, view())
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
net.send("progress", { ante = 1, location = "x" })
sent = {}
socket_up = false
now = 1
net.update()
socket_up = true
now = 1.4
net.update()
eq(#sent, 0, "not yet 0.5 s after the failed try")
now = 1.5
net.update()
eq(numbers(sent), "1", "0.5 s after the failed try it goes out")

-- another mod's lobby gets nothing
setup()
net.receive_view(nil, view())
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
calls = {}
lobby_mod = "OtherMod"
eq(net.send("ready", {}), 1, "the input is still numbered and kept")
eq(#calls, 0, "but another mod's lobby is sent nothing")
lobby_mod = nil
net.send("ready", {})
eq(#calls, 0, "and no lobby at all is sent nothing")

-- every_kind_encodes_valid_header
setup()
net.receive_view(nil, view())
local kinds = { "ready", "team", "blindStart", "handPlayed", "handScored", "progress", "blindResult", "skip", "sell", "shop", "voucher", "effect", "trapPlant", "trapFire", "trapLost", "timerStart", "timerPause", "paidPreviews", "animating", "vote", "forfeit", "endGame", "applied" }
eq(#kinds, 23, "the 23 kinds")
eq(net.send("progress", {}), nil, "a run kind needs a run")
eq(net.send("team", { team = "A" }), 1, "team goes without a run")
eq(sent[1].runId, nil, "team has no run id")
G.GAME.pvp_net = { runId = "stale", inboxDone = 9, totals = {} }
eq(net.send("team", { team = "B" }), 2, "team goes with a game left over from an old run")
eq(sent[2].runId, nil, "team never carries a run id")
local has_run_key = false
for key in pairs(sent[2]) do has_run_key = has_run_key or key == "runId" end
eq(has_run_key, false, "the key is absent on the wire")
eq(sent[2].inboxDone, 0, "and no old run's number")
G.GAME.pvp_net = { runId = "run1", inboxDone = 3, totals = {} }
for _, kind in ipairs(kinds) do
	if kind ~= "team" then
		local number = net.send(kind, { handsLeft = 3, nested = { a = 1 } })
		local input = sent[#sent]
		eq(number, #sent, kind .. " is numbered in order")
		eq(input.kind, kind, kind .. " keeps its kind")
		eq(input.messageNumber == math.floor(input.messageNumber) and input.messageNumber > 0, true, kind .. " has a whole messageNumber")
		eq(input.inboxDone, 3, kind .. " has inboxDone")
		eq(input.runId, "run1", kind .. " has the run id")
		eq(input.handsLeft, 3, kind .. " keeps its fields")
	end
end
eq(net.send(7, {}), nil, "a kind must be text")
eq(net.send("ready", "x"), nil, "a body must be a table")
G.GAME.pvp_net = { runId = "run1", totals = {} }
eq(net.send("ready", {}), nil, "a run with no last applied number is refused, not defaulted")
eq(net.rules.make_input(-1, 0, "r", "ready", {}), nil, "a negative input number is refused")
eq(net.rules.make_input(1, -1, "r", "ready", {}), nil, "a negative last applied number is refused")
eq(net.rules.make_input(1.5, 0, "r", "ready", {}), nil, "a fraction is refused")

-- the body is copied: later changes by the caller do not change a resend
setup()
net.receive_view(nil, view())
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
local body = { stats = { n = 1 } }
net.send("endGame", body)
body.stats.n = 2
eq(sent[1].stats.n, 1, "an input's bytes are fixed when it is made")

-- next_seq_is_confirmed_plus_1_after_crash, no_send_before_first_view
setup()
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
net.on_join()
eq(net.send("ready", {}), nil, "a new process sends nothing before the first view")
net.receive_view(nil, view({ lastMessageReceived = 7 }))
eq(net.send("ready", {}), 8, "then it uses lastMessageReceived + 1")

-- unconfirmed inputs keep their numbers across a socket drop and go out again with the first view
setup()
net.receive_view(nil, view())
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
net.send("ready", {})
net.send("ready", {})
sent = {}
net.on_join()
eq(#sent, 0, "nothing is sent before the first view of the join")
net.receive_view(nil, view({ lastMessageReceived = 0 }))
eq(numbers(sent), "1,2", "the first view after a join sends them again, oldest first")
eq(net.send("ready", {}), 3, "the next number goes on from the last one made")

-- the resend after a join waits for the first view, whatever the clock and a failed try in between,
-- and goes out before the put-off save
setup()
net.receive_view(nil, view())
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
net.send("sell", {})
calls = {}
net.on_join()
socket_up = false
now = 1
net.update()
eq(#calls, 0, "nothing is tried before the first view after a join")
socket_up = true
now = 1.1
net.receive_view(nil, view({ lastMessageReceived = 0 }))
eq(calls[1], "send sell", "the first view sends the unconfirmed input at once")
eq(calls[2], "save_now", "and only then is the put-off save taken")

-- every valid view is stored, the last one that arrived wins
setup()
net.receive_view(nil, view({ lastMessageReceived = 5, serverTime = 2000 }))
local lower = view({ lastMessageReceived = 4, serverTime = 9999 })
net.receive_view(nil, lower)
eq(net.view, lower, "the view that arrived last is the one stored")
eq(net.send("ready", {}), nil, "no run, but the number came from the first view")

-- a missing required field is refused with a log line, never defaulted
setup()
net.receive_view(nil, { serverTime = 1, match = {}, onlyMine = { inbox = {} } })
eq(net.view, nil, "no lastMessageReceived: refused")
net.receive_view(nil, { lastMessageReceived = 0, match = {}, onlyMine = { inbox = {} } })
eq(net.view, nil, "no serverTime: refused")
net.receive_view(nil, { lastMessageReceived = 0, serverTime = 1, match = {}, onlyMine = {} })
eq(net.view, nil, "no onlyMine.inbox: refused")
net.receive_view(nil, { lastMessageReceived = 1.5, serverTime = 1, match = {}, onlyMine = { inbox = {} } })
eq(net.view, nil, "a fraction: refused")
net.receive_view(nil, { lastMessageReceived = -1, serverTime = 1, match = {}, onlyMine = { inbox = {} } })
eq(net.view, nil, "a negative number: refused")
net.receive_view(nil, { lastMessageReceived = 0, serverTime = 1, onlyMine = { inbox = {} } })
eq(net.view, nil, "no match: refused")
eq(#warnings, 6, "each refusal is logged")

-- offset_is_largest_since_join
setup()
eq(net.server_now(), nil, "no offset before a view")
now = 10
net.receive_view(nil, view({ serverTime = 15000 }))
now = 11
net.receive_view(nil, view({ serverTime = 15500, lastMessageReceived = 1 }))
now = 12
net.receive_view(nil, view({ serverTime = 15600, lastMessageReceived = 2 }))
eq(net.server_now(), 12000 + 5000, "the largest offset: 5000, 4500 and 3600 were seen; 5000 wins")
net.on_join()
eq(net.server_now(), nil, "the offset starts over on every join")
now = 20
net.receive_view(nil, view({ serverTime = 21000 }))
eq(net.server_now(), 21000, "the new offset is the join's own")

-- the inbox: in order, once each, one per safe point; applied goes out once the inbox is drained
setup()
local ran = {}
net.handlers.pizza = function(it) ran[#ran + 1] = it.itemNumber end
net.receive_view(nil, in_run({ item(2), item(1), item(3) }, 0))
eq(table.concat(ran, ","), "1", "the lowest item runs first, one per safe point")
eq(net.busy(), true, "busy while its events are queued")
net.update()
eq(#ran, 1, "the next item waits until the last-item-done event has run")
run_queue()
eq(G.GAME.pvp_net.inboxDone, 1, "the event moves the last applied number")
eq(#sent, 0, "applied is not sent while another item waits")
net.update()
run_queue()
net.update()
run_queue()
eq(table.concat(ran, ","), "1,2,3", "items run in number order")
eq(#sent, 1, "applied is sent once, when the inbox is drained")
eq(sent[1].kind, "applied", "it is the applied input")
eq(sent[1].inboxDone, 3, "with the last number")
net.update()
run_queue()
eq(table.concat(ran, ","), "1,2,3", "each exactly once")
eq(G.GAME.pvp_net.inboxDone, 3, "all done")
eq(net.busy(), false, "not busy with nothing left")

-- the last-item-done event survives a cleared event queue
setup()
ran = {}
net.handlers.pizza = function(it) ran[#ran + 1] = it.itemNumber end
net.receive_view(nil, in_run({ item(1), item(2) }, 0))
eq(table.concat(ran, ","), "1", "the first item runs")
clear_queue()
run_queue()
eq(G.GAME.pvp_net.inboxDone, 1, "the number still moved")
eq(net.busy(), true, "the second item is waiting, not an item stuck in flight")
net.update()
eq(table.concat(ran, ","), "1,2", "the next item still runs")

-- client_skips_items_at_or_below_local_last_applied
setup()
ran = {}
net.handlers.pizza = function(it) ran[#ran + 1] = it.itemNumber end
net.receive_view(nil, in_run({ item(3), item(4) }, 3))
eq(table.concat(ran, ","), "4", "items at or below the game's own number never run")

-- only last-item-done + 1 runs; a jump ahead is logged once and waits
setup()
ran = {}
net.handlers.pizza = function(it) ran[#ran + 1] = it.itemNumber end
net.receive_view(nil, in_run({ item(5), item(6) }, 3))
net.update()
net.update()
eq(#ran, 0, "item 4 is missing: nothing runs")
eq(net.busy(), false, "and nothing is waiting to run")
eq(#warnings, 1, "it is logged once")
eq(warnings[1]:find("item 4", 1, true) ~= nil, true, "naming the missing item")

-- a view with only items at or below the last applied number: applied goes out once per number
setup()
net.handlers.pizza = function() end
net.receive_view(nil, in_run({ item(1), item(2) }, 2))
eq(#sent, 1, "applied is sent")
eq(sent[1].kind, "applied", "it is the applied input")
eq(sent[1].inboxDone, 2, "with the client's number")
net.receive_view(nil, in_run({ item(1), item(2) }, 2))
net.update()
eq(#sent, 1, "not again for the same number")
net.receive_view(nil, in_run({ item(1), item(2) }, 3))
eq(#sent, 2, "again for a new number")
net.receive_view(nil, in_run({ item(3), item(4) }, 3))
eq(#sent, 2, "not while an item is next")

-- an item with no whole number is logged
setup()
net.receive_view(nil, in_run({ item(1), { itemNumber = "x", effect = "pizza" } }, 1))
eq(#warnings, 1, "an unreadable item is logged")
eq(warnings[1]:find("item 2", 1, true) ~= nil, true, "with its place in the inbox")

-- net_ignores_view_of_other_run
setup()
ran = {}
net.handlers.pizza = function(it) ran[#ran + 1] = it.itemNumber end
net.receive_view(nil, in_run({ item(1) }, 5, "run2"))
eq(#ran, 0, "a view of another run applies no item")
eq(net.busy(), false, "and its items are not waiting")
net.receive_view(nil, in_run({ item(1) }, 0, "run2"))
eq(#ran, 0, "even when the numbers fit")
eq(net.busy(), false, "its items are still not waiting")

-- a game replaced while an item is queued is not written to
setup()
ran = {}
net.handlers.pizza = function(it) ran[#ran + 1] = it.itemNumber end
net.receive_view(nil, in_run({ item(1) }, 0))
local old_game_net = G.GAME.pvp_net
local new_game_net = { runId = "run2", inboxDone = 0, totals = {} }
G.GAME = { pvp_net = new_game_net }
sent = {}
run_queue()
eq(new_game_net.inboxDone, 0, "the new game's number does not move")
eq(old_game_net.inboxDone, 0, "nor is the old one's")
eq(#sent, 0, "and no applied goes out")
eq(net.busy(), false, "the net is not stuck")

-- handler_error_moves_last_applied
setup()
ran = {}
net.handlers.pizza = function() error("boom") end
net.handlers.gambling = function(it) ran[#ran + 1] = it.itemNumber end
net.receive_view(nil, in_run({ item(1, "pizza"), item(2, "gambling"), item(3, "unknown") }, 0))
run_queue()
eq(G.GAME.pvp_net.inboxDone, 1, "a handler that errors still moves the number")
eq(warnings[1]:find("boom", 1, true) ~= nil and warnings[1]:find("item 1", 1, true) ~= nil, true, "the error is logged with the item")
net.update()
run_queue()
eq(table.concat(ran, ","), "2", "the next item runs")
net.update()
run_queue()
eq(G.GAME.pvp_net.inboxDone, 3, "an effect with no handler is lost and moves the number")
eq(warnings[2]:find("no handler", 1, true) ~= nil, true, "and is logged")

-- net_calls_handlers_before_listeners, cursor event runs last
setup()
local order = {}
net.handlers.pizza = function()
	order[#order + 1] = "handler"
	G.E_MANAGER:add_event(Event({ func = function() order[#order + 1] = "handler event" return true end }))
end
net.add_view_listener(function() order[#order + 1] = "listener" end)
net.receive_view(nil, in_run({ item(1) }, 0))
run_queue()
eq(table.concat(order, ","), "handler,listener,handler event", "handlers first, then listeners")
eq(G.GAME.pvp_net.inboxDone, 1, "the number moved after the handler's own event")
queue = {}
order = {}
net.handlers.gambling = function()
	G.E_MANAGER:add_event(Event({ func = function() order[#order + 1] = "first" return true end }))
	G.E_MANAGER:add_event(Event({ func = function() order[#order + 1] = "second" return true end }))
end
G.GAME.pvp_net.inboxDone = 1
net.receive_view(nil, in_run({ item(2, "gambling") }, 1))
local before = G.GAME.pvp_net.inboxDone
for _, event in ipairs(queue) do
	if event.blocking ~= false then
		eq(G.GAME.pvp_net.inboxDone, before, "the number has not moved before the item's events ran")
		event.func()
	end
end
eq(table.concat(order, ","), "listener,first,second", "the handler's events run in order before the number moves")
eq(G.GAME.pvp_net.inboxDone, 2, "the number moved last")

-- net_waits_for_safe_point
setup()
ran = {}
net.handlers.pizza = function(it) ran[#ran + 1] = it.itemNumber end
local waiting_view = in_run({ item(1) }, 0)
G.STATE = G.STATES.BOOSTER
net.receive_view(nil, waiting_view)
eq(#ran, 0, "nothing runs with a booster pack open")
eq(net.busy(), true, "the item waits and the net is busy")
G.STATE = G.STATES.SHOP
G.STATE_COMPLETE = false
net.update()
eq(#ran, 0, "nothing runs before the state is built")
G.STATE_COMPLETE = true
G.STAGE = "menu"
net.update()
eq(#ran, 0, "nothing runs outside a run")
G.STAGE = "run"
MPAPI.playback = { is_driving = function(mod) return mod == "pvp" end }
net.update()
eq(#ran, 0, "nothing runs while a rejoin's replay plays the run")
MPAPI.playback = { is_driving = function() return false end }
net.update()
eq(#ran, 1, "the item runs at the safe point")
G.STATE = G.STATES.SELECTING_HAND
net.update()
eq(#ran, 1, "and not again while its events are queued")

-- a comeback bonus runs as the blind's evaluation starts, so that blind's cash-out pays it
setup()
ran = {}
net.handlers.pizza = function(it) ran[#ran + 1] = "pizza" .. it.itemNumber end
net.handlers.comebackBonus = function(it) ran[#ran + 1] = "bonus" .. it.itemNumber end
G.STATES.ROUND_EVAL = 8
G.STATE = G.STATES.ROUND_EVAL
G.STATE_COMPLETE = false
net.receive_view(nil, in_run({ item(1, "comebackBonus") }, 0))
net.update()
eq(#ran, 0, "the update does not run it in the evaluation state")
net.before_blind_eval()
eq(table.concat(ran, ","), "bonus1", "the evaluation's start runs it")
net.before_blind_eval()
eq(#ran, 1, "and not again while its events are queued")
run_queue()
eq(G.GAME.pvp_net.inboxDone, 1, "the number moved behind it")

-- the loser's Pizza discard shows in the shop, as on main. The server writes the bonus when it records the
-- PvP blind's result, before the winner's Pizza, so the bonus is first.
setup()
ran = {}
net.handlers.pizza = function(it) ran[#ran + 1] = "pizza" .. it.itemNumber end
net.handlers.comebackBonus = function(it) ran[#ran + 1] = "bonus" .. it.itemNumber end
G.STATES.ROUND_EVAL = 8
G.STATE = G.STATES.ROUND_EVAL
G.STATE_COMPLETE = false
net.receive_view(nil, in_run({ item(1, "comebackBonus"), item(2, "pizza") }, 0))
net.before_blind_eval()
run_queue()
G.STATE_COMPLETE = true
net.update()
run_queue()
eq(table.concat(ran, ","), "bonus1", "the bonus runs at the evaluation, the pizza not on the evaluation screen")
G.STATE = G.STATES.SHOP
net.update()
eq(table.concat(ran, ","), "bonus1,pizza2", "the pizza runs in the shop")

-- another kind of item waits for its own safe point, and the bonus behind it with it
setup()
ran = {}
net.handlers.asteroid = function(it) ran[#ran + 1] = "asteroid" .. it.itemNumber end
net.handlers.comebackBonus = function(it) ran[#ran + 1] = "bonus" .. it.itemNumber end
G.STATES.ROUND_EVAL = 8
G.STATE = G.STATES.ROUND_EVAL
net.receive_view(nil, in_run({ item(1, "asteroid"), item(2, "comebackBonus") }, 0))
net.before_blind_eval()
eq(#ran, 0, "an earlier item of another kind is not run at the evaluation, nor the bonus behind it")
G.STATE = G.STATES.SHOP
G.STATE_COMPLETE = true
net.update()
run_queue()
net.update()
eq(table.concat(ran, ","), "asteroid1,bonus2", "they run in number order at the safe points")

-- outside a run the evaluation's start runs nothing
setup()
ran = {}
net.handlers.comebackBonus = function(it) ran[#ran + 1] = "bonus" .. it.itemNumber end
G.STAGE = "menu"
G.STATES.ROUND_EVAL = 8
G.STATE = G.STATES.ROUND_EVAL
net.receive_view(nil, in_run({ item(1, "comebackBonus") }, 0))
net.before_blind_eval()
eq(#ran, 0, "no run, no item")

-- busy() from an item's arrival until it has run
setup()
net.handlers.pizza = function() end
net.receive_view(nil, view())
eq(net.busy(), false, "not busy with no item")
G.STATE = G.STATES.BOOSTER
net.receive_view(nil, in_run({ item(1) }, 0))
eq(net.busy(), true, "busy from the item's arrival")
G.STATE = G.STATES.SHOP
net.update()
eq(net.busy(), true, "busy while it is queued")
run_queue()
eq(net.busy(), false, "not busy once it has run")

-- join_keys_come_from_loaded_save
setup()
local saved = { save = { GAME = { pvp_net = { runId = "run7", inboxDone = 12, totals = {} } } } }
local keys = net.join_keys(saved)
eq(keys.pvp_run, "run7", "pvp_run is the saved run id")
eq(keys.pvp_inbox_done, "12", "pvp_inbox_done is the saved number, as text")
G.GAME.pvp_net = { runId = "live", inboxDone = 3, totals = {} }
eq(net.join_keys(saved).pvp_run, "run7", "the loaded save wins over the game in memory")
eq(net.join_keys(nil).pvp_run, "live", "with no save the game in memory is used")
eq(net.join_keys(nil).pvp_inbox_done, "3", "its number too")
G.GAME = {}
eq(next(net.join_keys(nil)), nil, "both keys are absent with no run")
eq(next(net.join_keys({ save = { GAME = {} } })), nil, "and with a save that has no run")
eq(type(net.take_refusal()), "string", "a loaded save with no run refuses the rejoin, with a reason")
eq(net.take_refusal(), nil, "the refusal is given once")
net.join_keys(saved)
eq(net.take_refusal(), nil, "a save with a run is not refused")
net.join_keys(nil)
eq(net.take_refusal(), nil, "a join with no save is not refused")
eq(next(net.rules.join_keys({ runId = "r" })), nil, "one key never goes alone")
eq(next(net.rules.join_keys({ runId = "r", inboxDone = 1.5 })), nil, "a fraction is not a number")
eq(net.rules.join_keys({ runId = "r", inboxDone = 0 }).pvp_inbox_done, "0", "0 is a number")

-- start_run
setup()
eq(net.start_run("run9"), true, "a new run starts")
eq(G.GAME.pvp_net.runId, "run9", "a new run keeps its id")
eq(G.GAME.pvp_net.inboxDone, 0, "with nothing done")
G.GAME.pvp_net = nil
local started, why = net.start_run(12)
eq(started, nil, "a run id that is not text is refused")
eq(why, "the run id must be text", "with the reason")
eq(G.GAME.pvp_net, nil, "and nothing is written")

-- a refusal from one join never survives into the next
setup()
local bad_save, good_save = { save = { GAME = {} } }, { save = { GAME = { pvp_net = { runId = "run7", inboxDone = 3 } } } }
net.join_keys(bad_save)
net.join_keys(good_save)
eq(net.take_refusal(), nil, "a bad save, then a good save: the good one is not refused")
net.join_keys(bad_save)
net.join_keys(nil)
eq(net.take_refusal(), nil, "a bad save, then a join with no save: no refusal")
net.join_keys(bad_save)
eq(type(net.take_refusal()), "string", "a bad save is still refused")

-- the run record starts once per fresh run, from the view's run
local function fresh_game()
	setup()
	MPAPI.has_server_referee = function() return true end
	PVP.PRACTICE.is_on = function() return false end
	net.register()
	net.receive_view(nil, view())
	G.GAME = {}
	net.game_started(false)
	return G.GAME
end
local function view_of_run(id) return view({ match = { run = { id = id } } }) end

eq(net.rules.run_to_start({ view_run_id = "r2" }), "r2", "a run id in the view starts the record")
eq(net.rules.run_to_start({ view_run_id = "r2", has_record = true }), nil, "a game with a record never starts another")
eq(net.rules.run_to_start({ view_run_id = nil }), nil, "no run in the view, nothing to start")
eq(net.rules.run_to_start({ view_run_id = "r1", previous_run_id = "r1" }), nil, "the run before is not the new run")
eq(net.rules.wants_record({ server_lobby = true }), true, "a fresh run in a server lobby has a record")
eq(net.rules.wants_record({ server_lobby = true, load = true }), false, "a load has none to start")
eq(net.rules.wants_record({ server_lobby = true, practice = true }), false, "practice has none")
eq(net.rules.wants_record({ server_lobby = false }), false, "another kind of lobby has none")

-- the view arrives after the game's run exists
local game = fresh_game()
eq(game.pvp_net, nil, "no record before the view shows a run")
net.receive_view(nil, view())
eq(game.pvp_net, nil, "a view with no run starts nothing")
net.receive_view(nil, view_of_run("r1"))
eq(game.pvp_net.runId, "r1", "the record starts with the view's run id")
eq(game.pvp_net.inboxDone, 0, "with nothing done")
game.pvp_net.inboxDone = 5
net.receive_view(nil, view_of_run("r1"))
net.update()
eq(game.pvp_net.inboxDone, 5, "it is started once")
eq(net.send("ready", {}) ~= nil and sent[#sent].runId, "r1", "inputs carry the run id")

-- the view arrives before the game's run exists
setup()
MPAPI.has_server_referee = function() return true end
PVP.PRACTICE.is_on = function() return false end
net.register()
net.receive_view(nil, view_of_run("r1"))
G.GAME = {}
net.update()
eq(G.GAME.pvp_net, nil, "a view held before any game starts nothing")
net.game_started(false)
net.update()
eq(G.GAME.pvp_net.runId, "r1", "the fresh game takes the run the view already shows")

-- a loaded save keeps its own record
fresh_game()
G.GAME = { pvp_net = { runId = "saved", inboxDone = 7, totals = {} } }
net.game_started(true)
net.receive_view(nil, view_of_run("r9"))
eq(G.GAME.pvp_net.runId, "saved", "a load is never restarted")
eq(G.GAME.pvp_net.inboxDone, 7, "nor overwritten")
-- a fresh game that was waiting, then a load that has no record: the load ends the wait
fresh_game()
net.game_started(true)
net.receive_view(nil, view_of_run("r9"))
eq(G.GAME.pvp_net, nil, "a game that turns out to be a load starts no record")
-- a fresh game that already holds a record is not overwritten either
game = fresh_game()
game.pvp_net = { runId = "kept", inboxDone = 2, totals = {} }
net.receive_view(nil, view_of_run("r9"))
eq(game.pvp_net.runId, "kept", "a record is never overwritten")

-- a restart: the view of the old run is held when the new game starts
game = fresh_game()
net.receive_view(nil, view_of_run("old"))
eq(game.pvp_net.runId, "old", "the first run's record")
G.GAME = {}
net.game_started(false)
net.receive_view(nil, view_of_run("old"))
net.update()
eq(G.GAME.pvp_net, nil, "the held view of the old run does not start the new record")
net.receive_view(nil, view_of_run("new"))
eq(G.GAME.pvp_net.runId, "new", "the new run's view does")
-- the old run was a loaded one, and the player went through a menu game before the rematch
fresh_game()
net.join_keys({ save = { GAME = { pvp_net = { runId = "loaded", inboxDone = 1 } } } })
G.GAME = {}
net.game_started(false)
net.receive_view(nil, view_of_run("loaded"))
eq(G.GAME.pvp_net, nil, "a loaded run's id counts as the run before too")
net.receive_view(nil, view_of_run("next"))
eq(G.GAME.pvp_net.runId, "next", "and the next run's view starts it")

-- a later game replaces the one waiting for its record
game = fresh_game()
G.GAME = {}
net.receive_view(nil, view_of_run("r1"))
eq(G.GAME.pvp_net, nil, "a game that is not the fresh one gets no record")
net.receive_view(nil, view_of_run("r2"))
eq(G.GAME.pvp_net, nil, "and the wait is over")

-- The same, through the entry the real lobby uses: the view handler and the gone hook. The first view
-- of a lobby resets the numbers; what the run record waits on must survive that.
local function server_lobby_setup()
	setup()
	MPAPI.has_server_referee = function() return true end
	PVP.PRACTICE.is_on = function() return false end
	net.register()
end

do
	-- a rejoin by load, then a restart: the new record takes the new id, not the loaded one
	server_lobby_setup()
	local lobby_a = {}
	net.join_keys({ save = { GAME = { pvp_net = { runId = "R1", inboxDone = 2 } } } })
	G.GAME = { pvp_net = { runId = "R1", inboxDone = 2, totals = {} } }
	net.game_started(true)
	view_handler(lobby_a, view_of_run("R1"))
	eq(G.GAME.pvp_net.runId, "R1", "the loaded run keeps its record")
	G.GAME = {}
	net.game_started(false)
	view_handler(lobby_a, view_of_run("R1"))
	eq(G.GAME.pvp_net, nil, "the view still showing the loaded run does not start the restart's record")
	view_handler(lobby_a, view_of_run("R2"))
	eq(G.GAME.pvp_net.runId, "R2", "the restart's record starts with the new id")
	eq(net.send("ready", {}) ~= nil and sent[#sent].runId, "R2", "and its inputs carry it")
end

do
	-- the game starts before the first view of its lobby (the first lobby of the process)
	server_lobby_setup()
	local first_lobby, second_lobby = {}, {}
	G.GAME = {}
	net.game_started(false)
	view_handler(first_lobby, view_of_run("r1"))
	eq(G.GAME.pvp_net and G.GAME.pvp_net.runId, "r1", "the first view of a lobby starts the record of a game that began before it")
	-- and the second lobby after leaving the first
	gone_handler(first_lobby)
	G.GAME = {}
	net.game_started(false)
	view_handler(second_lobby, view_of_run("r2"))
	eq(G.GAME.pvp_net and G.GAME.pvp_net.runId, "r2", "the same in a second lobby")
end

do
	-- the old lobby's gone hook arrives after the new game started
	server_lobby_setup()
	local old_one, new_one = {}, {}
	view_handler(old_one, view_of_run("r1"))
	G.GAME = {}
	net.game_started(false)
	gone_handler(old_one)
	view_handler(new_one, view_of_run("r2"))
	eq(G.GAME.pvp_net and G.GAME.pvp_net.runId, "r2", "a late gone hook of the old lobby does not drop the new game's wait")
end

do
	-- a different game still ends the wait, and a started record ends it for good
	server_lobby_setup()
	local lobby_b = {}
	view_handler(lobby_b, view())
	local first_game = {}
	G.GAME = first_game
	net.game_started(false)
	G.GAME = {}
	view_handler(lobby_b, view_of_run("r1"))
	G.GAME = first_game
	view_handler(lobby_b, view_of_run("r2"))
	eq(first_game.pvp_net, nil, "a game that was replaced stays out of the wait")
	local waiting_game = {}
	G.GAME = waiting_game
	net.game_started(false)
	view_handler(lobby_b, view_of_run("r3"))
	eq(waiting_game.pvp_net.runId, "r3", "the record starts")
	waiting_game.pvp_net = nil
	view_handler(lobby_b, view_of_run("r4"))
	eq(waiting_game.pvp_net, nil, "and the wait ended with it")
end

do
	-- never on a load: the API's staged save is asked before it is handed to the original start_run
	Game = { start_run = function() G.GAME = {} end }
	server_lobby_setup()
	local lobby_c = {}
	local staged = true
	MPAPI.run_save.is_staged = function() return staged end
	view_handler(lobby_c, view_of_run("r1"))
	Game:start_run({})
	view_handler(lobby_c, view_of_run("r1"))
	eq(G.GAME.pvp_net, nil, "a staged load starts no record")
	Game:start_run({ savetext = "saved" })
	staged = false
	view_handler(lobby_c, view_of_run("r1"))
	eq(G.GAME.pvp_net, nil, "nor does a start with the save text")
	Game:start_run({})
	view_handler(lobby_c, view_of_run("r1"))
	eq(G.GAME.pvp_net.runId, "r1", "a start with no save does")
	MPAPI.run_save.is_staged = function() error("no api") end
	Game:start_run({})
	view_handler(lobby_c, view_of_run("r2"))
	eq(G.GAME.pvp_net, nil, "a start that cannot be told from a load starts no record")
	eq(warnings[#warnings]:find("load could not be told", 1, true) ~= nil, true, "and says so")
	Game = nil
	eq(net.rules.is_load({}, true), true, "staged is a load")
	eq(net.rules.is_load({ savetext = "x" }, false), true, "a save text is a load")
	eq(net.rules.is_load(nil, false), false, "neither is not")
end

-- practice, solo and other lobbies: no record
setup()
MPAPI.has_server_referee = function() return true end
PVP.PRACTICE.is_on = function() return true end
net.register()
net.receive_view(nil, view_of_run("r1"))
G.GAME = {}
net.game_started(false)
net.receive_view(nil, view_of_run("r1"))
eq(G.GAME.pvp_net, nil, "practice has no record")
PVP.PRACTICE.is_on = function() return false end
lobby_mod = "OtherMod"
net.game_started(false)
net.receive_view(nil, view_of_run("r1"))
eq(G.GAME.pvp_net, nil, "another mod's lobby has no record")
lobby_mod = nil
net.game_started(false)
net.receive_view(nil, view_of_run("r1"))
eq(G.GAME.pvp_net, nil, "no lobby, no record")

-- a fresh run that has waited 10 seconds without the view showing a run is logged, once
local function waits_logged()
	local count = 0
	for _, text in ipairs(warnings) do
		if text:find("shown no run", 1, true) then count = count + 1 end
	end
	return count
end
game = fresh_game()
now = 9.9
net.update()
eq(waits_logged(), 0, "nothing is logged before 10 seconds")
now = 10
net.update()
eq(waits_logged(), 1, "10 seconds with no run in the view is logged")
now = 40
net.update()
net.receive_view(nil, view())
eq(waits_logged(), 1, "it is logged once for the run")
eq(game.pvp_net, nil, "and nothing else changes")
net.receive_view(nil, view_of_run("r1"))
eq(game.pvp_net.runId, "r1", "the run still starts when the view shows it")
-- a run the view shows in time is not logged; the next fresh run is logged again
game = fresh_game()
now = 5
net.receive_view(nil, view_of_run("r1"))
now = 20
net.update()
eq(waits_logged(), 0, "a run shown within 10 seconds is not logged")
game = fresh_game()
now = 10
net.update()
eq(waits_logged(), 1, "the next fresh run is logged on its own")
-- a load waits for nothing
fresh_game()
G.GAME = { pvp_net = { runId = "saved", inboxDone = 0, totals = {} } }
net.game_started(true)
now = 200
net.update()
eq(waits_logged(), 0, "a load is never logged")

-- run_held_until_first_view, no_save_while_inbox_busy, run_save_after_inputs_ordering
setup()
net.register()
calls = {}
eq(net.save_must_wait(), false, "outside a match a save is never put off")
net.on_join()
eq(net.save_must_wait(), true, "after a join the run is held until the first view")
net.handlers.pizza = function() end
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
net.send("ready", {})
net.receive_view(nil, view({ lastMessageReceived = 0 }))
eq(net.save_must_wait(), false, "with the first view the save can go ahead")
G.STATE = G.STATES.BOOSTER
net.receive_view(nil, in_run({ item(1) }, 0))
eq(net.save_must_wait(), true, "put off while an item waits")
G.STATE = G.STATES.BLIND_SELECT
calls = {}
net.update()
eq(net.save_must_wait(), true, "put off while its events are queued")
eq(table.concat(calls, ","):find("save_now", 1, true), nil, "no save yet")
run_queue()
eq(calls[#calls], "save_now", "the put-off save is released once the last-item-done event has run")
-- an unconfirmed input does not put the save off, in a PvP blind or outside one: the run's record holds it
G.STATE = G.STATES.SELECTING_HAND
net.send("handPlayed", { handsLeft = 3 })
eq(net.save_must_wait(), false, "an unconfirmed input does not put it off outside a PvP blind")
PVP.UTILS.is_pvp_blind = function() return true end
eq(net.save_must_wait(), false, "nor in a PvP blind")
eq(G.GAME.pvp_net.unconfirmed[#G.GAME.pvp_net.unconfirmed].kind, "handPlayed", "the record holds the unconfirmed input")
net.send("handPlayed", { handsLeft = 2 })
local confirmed = in_run({}, 1)
confirmed.lastMessageReceived = 100
calls = {}
net.receive_view(nil, confirmed)
eq(calls[#calls], "save_now", "the save goes ahead when the view confirms them")
eq(#G.GAME.pvp_net.unconfirmed, 0, "and the record drops what the view confirmed")
-- after a rejoin the resend goes out before any save is released
net.send("handPlayed", { handsLeft = 1 })
net.on_join()
calls = {}
local after_join = in_run({}, 1)
after_join.lastMessageReceived = 0
net.receive_view(nil, after_join)
eq(calls[1], "send handPlayed", "the unconfirmed input is sent again first")
eq(calls[#calls], "save_now", "and the save follows it")
-- a put-off save is not taken while the blind is being evaluated
G.STATES.ROUND_EVAL = 8
G.STATE = G.STATES.ROUND_EVAL
calls = {}
net.receive_view(nil, in_run({}, 1))
eq(table.concat(calls, ","):find("save_now", 1, true), nil, "no put-off save during the blind's evaluation")
G.STATE = G.STATES.SHOP
net.receive_view(nil, in_run({}, 1))
eq(calls[#calls], "save_now", "it is taken once the blind is out of its evaluation")

-- reset forgets the numbers and the view
setup()
net.receive_view(nil, view({ lastMessageReceived = 9 }))
net.reset()
eq(net.view, nil, "reset forgets the view")
eq(net.send("ready", {}), nil, "and the numbers")

-- next_item names its outcome; held says whether the inbox still holds done items
setup()
local function inbox_view(numbers)
	local inbox = {}
	for _, number in ipairs(numbers) do inbox[#inbox + 1] = { itemNumber = number } end
	return { match = { run = { id = "r" } }, onlyMine = { inbox = inbox } }
end
local item_cases = {
	{ "the next number runs", { 3 }, { runId = "r", inboxDone = 2 }, "run", "none" },
	{ "a gap waits for the missing one", { 5 }, { runId = "r", inboxDone = 2 }, "wait for missing", "none" },
	{ "done items only", { 1, 2 }, { runId = "r", inboxDone = 2 }, "all done", "done items" },
	{ "an empty inbox", {}, { runId = "r", inboxDone = 2 }, "nothing", "none" },
	{ "another run's record", { 3 }, { runId = "other", inboxDone = 2 }, "nothing", "none" },
	{ "no record", { 3 }, nil, "nothing", "none" },
	{ "the next one behind done ones", { 1, 3 }, { runId = "r", inboxDone = 2 }, "run", "done items" },
}
for _, case in ipairs(item_cases) do
	local got = net.rules.next_item(inbox_view(case[2]), case[3])
	eq(got.outcome, case[4], case[1] .. ": outcome")
	eq(got.held, case[5], case[1] .. ": held")
end
eq(net.rules.next_item(inbox_view({ 5, 4 }), { runId = "r", inboxDone = 2 }).skipped_to, 4, "the lowest number above")

-- the wait warning is due once, after the wait
eq(net.rules.wait_warning_due({ since = 0, warned = "not yet" }, 9, 10), false, "not before the wait")
eq(net.rules.wait_warning_due({ since = 0, warned = "not yet" }, 10, 10), true, "at the wait")
eq(net.rules.wait_warning_due({ since = 0, warned = "warned" }, 99, 10), false, "never twice")

-- send_live sends nothing for no body or while a replay drives
setup()
net.receive_view(nil, view({ lastMessageReceived = 0 }))
MPAPI.playback = { is_driving = function() return false end }
eq(net.send_live("team", nil), nil, "no body, nothing sent")
MPAPI.playback = { is_driving = function() return true end }
eq(net.send_live("team", {}), nil, "a replay sends nothing")
MPAPI.playback = { is_driving = function() return false end }
eq(net.send_live("team", {}), 1, "live play sends")

-- The lobby stage's inputs (lobbyReady, lobbyStart) take the same envelope with no run, and nothing
-- is sent before the first view.
setup()
eq(net.send("lobbyReady", { ready = true }), nil, "no lobby input before the first view")
net.receive_view(nil, view())
G.GAME.pvp_net = { runId = "stale", inboxDone = 9, totals = {} }
eq(net.send("lobbyReady", { ready = true }), 1, "a lobby input is numbered")
eq(sent[1].runId, nil, "and has no run id")
eq(sent[1].inboxDone, 0, "and no old run's number")

-- For any lobby input, dropping its first send still ends confirmed: the resend is the same input and
-- the view's number confirms it; nothing per case. The server model takes only last + 1, in order.
for dropped = 1, 3 do
	setup()
	net.receive_view(nil, view())
	for _ = 1, 3 do net.send("lobbyReady", { ready = true }) end
	local last, delivered = 0, 0
	for step = 1, 60 do
		now = step
		net.update()
		for index = delivered + 1, #sent do
			local input = sent[index]
			-- The first send of input `dropped` is lost on the way.
			local lost = input.messageNumber == dropped and index <= 3
			if not lost and input.messageNumber == last + 1 then last = input.messageNumber end
		end
		delivered = #sent
		net.receive_view(nil, view({ lastMessageReceived = last }))
	end
	eq(last, 3, "dropping send " .. dropped .. ": the server still takes all three")
	eq(net.waiting("lobbyReady"), false, "dropping send " .. dropped .. " still ends confirmed")
end

-- A before-run input made ahead of its lobby's first view is held, then numbered and sent on that view,
-- in the order made; a run input then is refused, and a gone lobby's held inputs are dropped.
setup()
net.register()
local early = MPAPI.get_current_lobby()
MPAPI.get_current_lobby = function() return early end
local number, problem = net.send("lobbySettings", { settings = { stake = "3" } })
eq(number, nil, "no number before the first view")
eq(problem, "held for the first view", "a before-run input is held")
net.send("lobbyReady", { ready = true })
eq(select(2, net.send("handPlayed", {})), "no view yet", "a run input is not held")
eq(#sent, 0, "nothing goes up before the view")
view_handler(early, view({ lastMessageReceived = 4 }))
eq(numbers(sent), "5,6", "held inputs go up on the first view, numbered from it")
eq(sent[1].kind .. "," .. sent[2].kind, "lobbySettings,lobbyReady", "in the order made")
eq(sent[1].settings.stake, "3", "with their body")
sent = {}
view_handler(early, view({ lastMessageReceived = 4 }))
eq(#sent, 0, "a held input is sent once, then resent only when due")
setup()
net.register()
local gone, now_in = { mod_id = "MultiplayerPvP" }, { mod_id = "MultiplayerPvP" }
MPAPI.get_current_lobby = function() return gone end
net.send("lobbySettings", { settings = { stake = "3" } })
MPAPI.get_current_lobby = function() return now_in end
view_handler(now_in, view())
eq(#sent, 0, "another lobby's held input is dropped")
eq(net.waiting(), false, "and nothing waits for it")

-- A hand scored, a crash before the confirm, a load: the saved record's input is sent again with its number.
setup()
net.register()
local first_lobby = {}
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
view_handler(first_lobby, view({ lastMessageReceived = 0 }))
eq(net.send("handScored", { blindKey = "2:Boss", handsLeft = 0, score = "250" }), 1, "the hand's score is input 1")
local saved_record = G.GAME.pvp_net
eq(#saved_record.unconfirmed, 1, "the save holds the unconfirmed input")
-- the game restarts: a new process knows nothing, the loaded game carries the record
setup()
net.register()
G.GAME.pvp_net = saved_record
net.join_keys({ save = { GAME = G.GAME } })
sent = {}
view_handler(first_lobby, view({ lastMessageReceived = 0 }))
eq(numbers(sent), "1", "the envelope sends the saved input again after the load")
eq(sent[1].kind, "handScored", "the same input")
eq(sent[1].score, "250", "with its body as it was")
eq(net.send("ready", {}), 2, "new inputs go on from the saved numbers")

-- an input the server already confirmed is not sent again after a load
setup()
net.register()
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {}, unconfirmed = { { kind = "handScored", messageNumber = 1, inboxDone = 0, runId = "run1" } } }
net.join_keys({ save = { GAME = G.GAME } })
sent = {}
view_handler(first_lobby, view({ lastMessageReceived = 1 }))
eq(#sent, 0, "a confirmed input is not sent again")
eq(net.waiting(), false, "and is not waiting")
eq(#G.GAME.pvp_net.unconfirmed, 0, "and the record drops it")
eq(net.send("ready", {}), 2, "numbers go on after it")

-- saved inputs of another run are not taken
setup()
net.register()
G.GAME.pvp_net = { runId = "run2", inboxDone = 0, totals = {}, unconfirmed = { { kind = "handScored", messageNumber = 1, inboxDone = 0, runId = "run1" } } }
net.join_keys({ save = { GAME = G.GAME } })
sent = {}
view_handler(first_lobby, view({ lastMessageReceived = 0 }))
eq(#sent, 0, "an input of another run is not sent")


-- a run input made by the fresh game before its run id is held and sent once the run id exists
local game2 = fresh_game()
local the_lobby = { mod_id = "MultiplayerPvP" }
MPAPI.get_current_lobby = function() return the_lobby end
local number2, why = net.send("progress", { location = "Blind select" })
eq(number2, nil, "no number before the run id")
eq(why, "held for the run", "a run input in the wait for the run is held")
eq(#sent, 0, "nothing goes up yet")
net.receive_view(nil, view_of_run("r1"))
eq(#sent, 1, "the held input goes up when the run starts")
eq(sent[1].kind, "progress", "it is the one made")
eq(sent[1].runId, "r1", "with the new run id")
eq(sent[1].location, "Blind select", "and its body")
net.receive_view(nil, view_of_run("r1"))
eq(#sent, 1, "it is sent once")
-- a game that ends the wait drops what it held
local game3 = fresh_game()
MPAPI.get_current_lobby = function() return the_lobby end
net.send("progress", { location = "x" })
net.game_started(false)
G.GAME = {}
net.game_started(false)
net.receive_view(nil, view_of_run("r2"))
eq(#sent, 0, "a new game's start drops the inputs of the one before")


T.done("match_net_test")
