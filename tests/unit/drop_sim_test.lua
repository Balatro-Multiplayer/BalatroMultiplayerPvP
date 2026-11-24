-- Run from the repo root: luajit tests/unit/drop_sim_test.lua
-- The real pvp_api/net/server_link.lua against a stand-in server over a socket that drops at random. Over TCP a
-- message is lost only with its socket: whatever is in flight when it drops is gone both ways, and the
-- rejoin's new session is sent a whole view. The server takes input `last + 1` once and sends a view when
-- it changes (the lobby) or on every tick (the game). Every input the player makes, of every kind, before
-- the first view, in the lobby and in the run, must reach the server exactly once, in order, and end
-- confirmed; the latest Ready and settings are the server's.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local RUN_KINDS = { "blindStart", "handPlayed", "handScored", "progress", "sell", "timerStart", "paidPreviews", "timerPause", "animating", "ready", "endGame" }
local LOBBY_KINDS = { "lobbySettings", "lobbyReady", "team" }
local DT = 0.05

local function simulate(seed)
	local rng_state = seed
	local function rng()
		rng_state = (1103515245 * rng_state + 12345) % 2147483648
		return rng_state / 2147483648
	end
	local function pick(list) return list[math.floor(rng() * #list) + 1] end

	local now = 0
	local events = {}
	local socket = { up = true, back_at = nil }
	local up_flight, down_flight = {}, {}
	local server = { last = 0, taken = {}, ready = nil, settings = {}, sent_view = nil, every_tick = false, next_tick = 0 }
	local lobby = { mod_id = "MultiplayerPvP", is_host = true }
	local view_handler

	PVP = { NET = {}, READ = {}, UI = {}, id = "MultiplayerPvP", UTILS = { is_pvp_blind = function() return false end } }
	love = { timer = { getTime = function() return now end } }
	sendWarnMessage = function() end
	G = {
		STAGE = "run",
		STAGES = { RUN = "run" },
		STATES = { BLIND_SELECT = 1, SHOP = 2, SELECTING_HAND = 3, BOOSTER = 9 },
		STATE = 1,
		STATE_COMPLETE = true,
		GAME = {},
		E_MANAGER = { add_event = function(_, event) events[#events + 1] = event end },
	}
	Event = function(fields) return fields end
	MPAPI = {
		get_current_lobby = function() return lobby end,
		send_match_input = function(_, input)
			if not socket.up then return false end
			up_flight[#up_flight + 1] = { at = now + rng() * 0.3, input = input }
			return true
		end,
		on_match_view = function(_, fn) view_handler = fn end,
		add_join_keys = function() end,
		on_lobby_gone = function() end,
		playback = { is_driving = function() return false end },
		run_save = { register_save_wait = function() end, save_now = function() end, is_staged = function() return false end },
	}
	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/net/_rules.lua")
	dofile("pvp_api/net/server_link.lua")
	local net = PVP.NET
	net.register()

	local function view_of_server()
		local match = {}
		if G.GAME.pvp_net then match.run = { id = "run1" } end
		return { serverTime = now * 1000, lastMessageReceived = server.last, me = "a", match = match, players = {}, timers = {}, onlyMine = { inbox = {}, inboxNewest = 0 } }
	end
	local function server_send_view(whole)
		local shown = view_of_server()
		if not whole and server.sent_view == shown.lastMessageReceived and not server.every_tick then return end
		server.sent_view = shown.lastMessageReceived
		down_flight[#down_flight + 1] = { at = now + rng() * 0.3, view = shown }
	end
	local function server_take(input)
		if input.messageNumber ~= server.last + 1 then return end
		server.last = input.messageNumber
		server.taken[#server.taken + 1] = input
		if input.kind == "lobbyReady" then server.ready = input.ready end
		if input.kind == "lobbySettings" then
			for key, value in pairs(input.settings) do server.settings[key] = value end
		end
	end

	-- What the player asked for, in the order asked.
	local asked, last_ready, last_stake = {}, nil, nil
	local function ask(kind)
		local body
		if kind == "lobbyReady" then
			last_ready = rng() < 0.5
			body = { ready = last_ready }
		elseif kind == "lobbySettings" then
			last_stake = tostring(math.floor(rng() * 8) + 1)
			body = { settings = { stake = last_stake, cocktail_recipe = { name = "x", decks = { "b_red" } } } }
		elseif kind == "team" then
			body = { team = pick({ "A", "B" }) }
		else
			body = { total = #asked + 1 }
		end
		local number, problem = net.send(kind, body)
		if number or problem == "held for the first view" then
			asked[#asked + 1] = kind
		else
			error("seed " .. seed .. ": " .. kind .. " not taken by the net: " .. tostring(problem))
		end
	end

	local function step(drops)
		now = now + DT
		-- The socket.
		if socket.up and drops and rng() < 0.01 then
			socket.up, socket.back_at = false, now + 0.2 + rng() * 6
			up_flight, down_flight = {}, {}
		elseif not socket.up and now >= socket.back_at then
			socket.up = true
			net.join_keys(nil)
			server.sent_view = nil
			server_send_view(true)
		end
		-- Up, in order.
		while up_flight[1] and up_flight[1].at <= now do
			local input = table.remove(up_flight, 1).input
			server_take(input)
			server_send_view(false)
		end
		if server.every_tick and socket.up and now >= server.next_tick then
			server.next_tick = now + 0.2
			server_send_view(true)
		end
		-- Down, in order.
		while down_flight[1] and down_flight[1].at <= now do
			view_handler(lobby, table.remove(down_flight, 1).view)
		end
		-- One frame of the game's events.
		local kept = {}
		for _, event in ipairs(events) do
			if not event.func() then kept[#kept + 1] = event end
		end
		events = kept
	end

	-- Before the first view: the host's settings on connect.
	ask("lobbySettings")
	server_send_view(true)
	-- The lobby.
	for _ = 1, 600 do
		if rng() < 0.08 then ask(pick(LOBBY_KINDS)) end
		step(true)
	end
	-- The run.
	G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
	server.every_tick = true
	for _ = 1, 1200 do
		if rng() < 0.08 then
			if rng() < 0.2 then ask(pick(LOBBY_KINDS)) else ask(pick(RUN_KINDS)) end
		end
		step(true)
	end
	-- The network heals.
	for _ = 1, 1200 do step(false) end

	eq(#server.taken, #asked, "seed " .. seed .. ": every input reached the server once")
	for index, kind in ipairs(asked) do
		eq(server.taken[index].kind, kind, "seed " .. seed .. ": input " .. index .. " in order")
		eq(server.taken[index].messageNumber, index, "seed " .. seed .. ": input " .. index .. " numbered in order")
	end
	eq(net.waiting(), false, "seed " .. seed .. ": nothing left unconfirmed")
	eq(server.ready, last_ready, "seed " .. seed .. ": the latest Ready is the server's")
	eq(server.settings.stake, last_stake, "seed " .. seed .. ": the latest settings are the server's")
end

for seed = 1, 200 do simulate(seed) end
T.done("drop_sim_test")
