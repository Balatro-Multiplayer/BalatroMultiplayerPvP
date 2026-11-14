-- Run from the repo root: luajit tests/unit/connected_reapply_test.lua
-- A crash rejoin in MPAPI's real order, with the real lobby_bridge.lua CONNECTED handler, LivesNet,
-- ResultNet and RunGate: the server state is pushed while no PvP lobby is current (nothing
-- pending), the rejoin attach hook runs, the live lobby becomes current while it still holds
-- its messages, CONNECTED fires, then the lobby is released. Lives events and the result apply
-- once, and only because CONNECTED re-reads them.
local noop = function() end
local eased, handled, handlers, lobby_events, hooks, current, refreshed

local function make_live()
	local live = {
		mod_id = "pvp",
		player_id = "me",
		code = "ABC",
		is_host = false,
		_nakama = true,
		_holding = true,
		_game = { started = { run_id = "r1" } },
	}
	function live:on(event, fn)
		lobby_events[event] = fn
	end
	function live:get_players()
		return { { id = "me" }, { id = "they" } }
	end
	function live:get_metadata()
		return {}
	end
	return live
end

local function setup()
	eased, handled, handlers, lobby_events, current, refreshed = {}, {}, {}, {}, nil, {}
	PVP = {
		id = "pvp",
		LOBBY = { config = { gold_on_life_loss = true }, deck = {} },
		GAME = { lives = 4, comeback_bonus = 0, enemy = { lives = 4 } },
		config = {},
		ReadyNet = { on_connected = noop, on_snapshot = noop, update = noop },
		TimerNet = { on_connected = noop, on_snapshot = noop, update = noop },
		RoundNet = { on_snapshot = noop, update = noop },
		TargetsNet = { on_connected = noop },
		EnemyScoreNet = { on_connected = noop },
		SkipsNet = { on_connected = noop, update = noop },
		OpponentNet = { on_connected = noop, update = noop, end_catch_up = noop },
		EffectsNet = { update = noop },
		TrapsNet = { update = noop },
		AnimatingNet = { update = noop },
		ClocksNet = { on_connected = noop, on_snapshot = noop },
		show_vote_counts = noop,
		UTILS = {},
		UI = {
			UTILS = {},
			ease_lives = function(delta, instant)
				eased[#eased + 1] = { delta = delta, instant = instant }
			end,
		},
		SETUP = { apply_results = noop },
		LobbyAccess = {},
		TRAP_ROW = { on_player_back = noop, forget = noop },
		SP = {},
		RoundEndNet = {
			on_connected = function()
				refreshed[#refreshed + 1] = "round_end"
			end,
			update = noop,
		},
		OPPONENT_SIGNALS = {
			lives_dropped = function()
				return false
			end,
		},
		is_pvp_boss = function()
			return false
		end,
		rejoined_lobby_kind = noop,
		force_lobby_options = noop,
		match_log = noop,
		end_pending_death = noop,
		HANDLERS = {
			winGame = function()
				handled[#handled + 1] = "winGame"
			end,
			loseGame = noop,
			drawGame = noop,
		},
		version = "1.0.3",
	}
	PVP.reset_game_states = function()
		PVP.GAME = { lives = 0, comeback_bonus = 0, enemy = { lives = 4 } }
	end
	local events = {}
	for _, name in ipairs({
		"CONNECTED",
		"PLAYER_JOINED",
		"PLAYER_INFO",
		"PLAYER_LEFT",
		"DISCONNECTED",
		"ERROR",
		"PLAYER_CATCHING_UP",
		"PLAYER_DISCONNECTED",
		"PLAYER_RECONNECTED",
		"REPLAY_TAIL",
		"METADATA_CHANGED",
		"PLAYER_STANDING_CHANGED",
		"HOST_CHANGED",
		"SETUP_CHANGED",
		"PLAYER_READY_CHANGED",
		"GAME_STARTED",
		"CONTESTED",
		"GAME_ENDED",
		"SNAPSHOT_APPLIED",
	}) do
		events[name] = name
	end
	local states = {}
	MPAPI = {
		LobbyEvent = events,
		matchmaking = { group = {} },
		apply_default_modifiers = noop,
		add_modifier = noop,
		modifiers_serialize = noop,
		refresh_current_view = noop,
		create_lobby_ui = noop,
		get_current_lobby = function()
			return current
		end,
		get_state = function(key)
			return states[key]
		end,
		set_state = function(key, value)
			states[key] = value
			for _, fn in ipairs(handlers[key] or {}) do
				fn(value)
			end
		end,
		on_state = function(key, fn)
			handlers[key] = handlers[key] or {}
			table.insert(handlers[key], fn)
		end,
		request = noop,
		playback = {
			register_rejoin_hooks = function(_, registered)
				hooks = registered
			end,
		},
		run_save = { register_state = noop },
	}
	G = {
		STAGE = "run",
		STAGES = { RUN = "run" },
		GAME = { round_resets = { ante = 2 }, blind_on_deck = "Big", blind = { dollars = 5 } },
	}
	Game = { update = noop }
	function localize()
		return ""
	end
	dofile("lib/pending_death.lua")
	dofile("lib/_state_value.lua")
	dofile("lib/applied_effects.lua")
	dofile("lib/lives_view.lua")
	dofile("lib/result_view.lua")
	dofile("lib/version_gate.lua")
	dofile("pvp_api/lobby_bridge.lua")
	dofile("lib/rejoin.lua")
	dofile("pvp_api/run_gate.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/lives_net.lua")
	dofile("pvp_api/result_net.lua")
	dofile("pvp_api/frame.lua")
	local evaluate_votes = PVP.ResultNet.evaluate_votes
	PVP.ResultNet.evaluate_votes = function()
		refreshed[#refreshed + 1] = "votes"
		return evaluate_votes()
	end
	PVP.refresh_target_lives = noop
	PVP.current_target_id = function()
		return "they"
	end
	PVP.UTILS.version_mismatches = function()
		return {}
	end
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

local function equal(got, want, what)
	assert(got == want, ("%s: got %s, wanted %s"):format(what or "value", tostring(got), tostring(want)))
end

-- Pushes while no PvP lobby is current, attaches, makes the lobby current while it still holds
-- its messages, fires CONNECTED, then releases it.
local function rejoin()
	local live = make_live()
	hooks.attach(live, {})
	current = live
	lobby_events.CONNECTED()
	Game:update(0)
	equal(#eased, 0, "a held lobby is not live")
	equal(#handled, 0, "a held lobby is not live")
	live._holding = false
	Game:update(0)
	Game:update(0)
end

test("lives pushed before the attach apply once after CONNECTED", function()
	setup()
	MPAPI.set_state("pvp.lives", {
		runId = "r1",
		players = { me = { lives = 3, events = { { delta = -1, key = "2:Big" } } }, they = { lives = 4, events = {} } },
		pending = {},
	})
	equal(#eased, 0, "no lobby yet, nothing pending")
	rejoin()
	equal(#eased, 1)
	equal(eased[1].delta, -1)
	equal(PVP.GAME.lives, 3)
	equal(PVP.GAME.applied.events.me, 1)
end)

test("a result pushed before the attach applies once after CONNECTED", function()
	setup()
	MPAPI.set_state("pvp.result", {
		runId = "r1",
		kind = "win",
		winnerId = "me",
		places = { { playerId = "me", place = 1 }, { playerId = "they", place = 2 } },
	})
	equal(#handled, 0, "no lobby yet, nothing pending")
	rejoin()
	equal(#handled, 1)
	equal(handled[1], "winGame")
end)

test("CONNECTED re-reads the votes and the round-end marks", function()
	setup()
	rejoin()
	equal(table.concat(refreshed, ","), "votes,round_end")
end)

test("CONNECTED reads ReadyNet (the round id of a rejoin) before RoundEndNet", function()
	setup()
	PVP.ReadyNet.on_connected = function()
		refreshed[#refreshed + 1] = "ready"
	end
	rejoin()
	local order = table.concat(refreshed, ",")
	assert(order:find("ready", 1, true) and order:find("ready,.*round_end"), "got " .. order)
end)

test("CONNECTED reads the timer's deadline once, as the snapshot's", function()
	setup()
	local reads = 0
	PVP.TimerNet.on_connected = function()
		reads = reads + 1
	end
	rejoin()
	equal(reads, 1)
end)

test("CONNECTED reads the opponent again", function()
	setup()
	local reads = 0
	PVP.TargetsNet.on_connected = function()
		reads = reads + 1
	end
	rejoin()
	equal(reads, 1)
end)

test("CONNECTED reads the server clocks once, as the snapshot's", function()
	setup()
	local reads = 0
	PVP.ClocksNet.on_connected = function()
		reads = reads + 1
	end
	rejoin()
	equal(reads, 1)
end)

test("CONNECTED reads the team roster before the opponent (the attach reset emptied the roster)", function()
	setup()
	local order = {}
	PVP.TeamsNet = {
		refresh = function()
			order[#order + 1] = "teams"
		end,
	}
	PVP.TargetsNet.on_connected = function()
		order[#order + 1] = "targets"
	end
	rejoin()
	equal(table.concat(order, ","), "teams,targets")
end)

test("CONNECTED runs the nets in the declared order, the team roster first", function()
	setup()
	equal(
		table.concat(PVP.CONNECTED_ORDER, ","),
		"ReadyNet,TimerNet,TargetsNet,EnemyScoreNet,SkipsNet,OpponentNet,ClocksNet,LivesNet,ResultNet,RoundEndNet",
		"the declared order"
	)
	local order = {}
	PVP.TeamsNet = {
		refresh = function()
			order[#order + 1] = "TeamsNet"
		end,
	}
	for _, name in ipairs(PVP.CONNECTED_ORDER) do
		local on_connected = PVP[name].on_connected
		PVP[name].on_connected = function()
			order[#order + 1] = name
			return on_connected()
		end
	end
	rejoin()
	equal(table.concat(order, ","), "TeamsNet," .. table.concat(PVP.CONNECTED_ORDER, ","), "the order run")
end)

test("SNAPSHOT_APPLIED tells ReadyNet, TimerNet, RoundNet, then ClocksNet", function()
	setup()
	equal(table.concat(PVP.SNAPSHOT_ORDER, ","), "ReadyNet,TimerNet,RoundNet,ClocksNet", "the declared order")
	local order = {}
	for _, name in ipairs(PVP.SNAPSHOT_ORDER) do
		PVP[name].on_snapshot = function()
			order[#order + 1] = name
		end
	end
	local live = make_live()
	hooks.attach(live, {})
	current = live
	lobby_events.SNAPSHOT_APPLIED()
	equal(table.concat(order, ","), "ReadyNet,TimerNet,RoundNet,ClocksNet", "the order run")
end)

if failures > 0 then os.exit(1) end
print("connected_reapply_test: ok")
