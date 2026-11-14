-- Run from the repo root: luajit tests/unit/lives_net_test.lua
-- The shell around lib/lives_view.lua and lib/applied_effects.lua with stubbed MPAPI, G and
-- PVP.UI: the lives cache, the once-only effects, the gate on a live lobby, the rejoin attach, the save.
-- LIVES_NET_PATH (optional) points at another copy of pvp_api/lives_net.lua, to check a test
-- against older code.
local handlers, state, current, eased, registered, rejoin_hooks, signals, logged, juiced
local rules_state, result_state, eliminated_calls

local function make_lobby(id)
	return { mod_id = "pvp", player_id = id, _nakama = true, _game = { started = { run_id = "r1" } } }
end

local function setup(opts)
	opts = opts or {}
	handlers, state, eased, registered = {}, nil, {}, nil
	signals, logged, juiced = 0, {}, 0
	rules_state, result_state, eliminated_calls = nil, nil, {}
	PVP = {
		id = "pvp",
		config = { recordedRuns = opts.recorded },
		-- networking/action_handlers.lua: the server's "you are out" (params: { player_id }).
		HANDLERS = {
			eliminated = function(params)
				eliminated_calls[#eliminated_calls + 1] = params
			end,
		},
		GAME = { lives = 4, comeback_bonus = 0, comeback_bonus_given = true, enemy = { lives = 4 } },
		-- lobby_bridge.lua: the duel's target is the one other player; the enemy lives read the cache.
		current_target_id = function()
			return PVP.target or "they"
		end,
		refresh_target_lives = function()
			PVP.GAME.enemy.lives = PVP._player_lives_cache.they
		end,
		OPPONENT_SIGNALS = {
			lives_dropped = function(old, new)
				return old ~= nil and new ~= nil and new < old
			end,
			play_life_lost = function()
				signals = signals + 1
			end,
		},
		RLOG = {
			record = function(opcode, payload)
				logged[#logged + 1] = { opcode = opcode, payload = payload }
			end,
		},
		LOBBY = { config = { gold_on_life_loss = true, no_gold_on_round_loss = opts.no_gold == true } },
		UI = {
			juice_up_pvp_hud = function()
				juiced = juiced + 1
			end,
			ease_lives = function(delta, instant)
				eased[#eased + 1] = { delta = delta, instant = instant }
			end,
		},
		is_pvp_boss = function()
			return false
		end,
		in_session = function()
			return true
		end,
		SP = {},
		rejoined_lobby_kind = function() end,
		-- lobby_bridge.lua: a new lobby object clears the lives cache, then the match state is reset.
		setup_lobby_mirror = function()
			PVP._player_lives_cache = nil
			PVP.reset_game_states()
		end,
		reset_game_states = function()
			if opts.load_breaks then error("load broke") end
			PVP.GAME = { comeback_bonus = 0, comeback_bonus_given = true, enemy = {} }
		end,
	}
	current = make_lobby("me")
	MPAPI = {
		OPCODE = { LIFE_LOST = "LIFE_LOST" },
		get_current_lobby = function()
			return current
		end,
		get_state = function(key)
			if key == "pvp.rules" then return rules_state end
			if key == "pvp.result" then return result_state end
			return state
		end,
		playback = {
			register_rejoin_hooks = function(_, hooks)
				rejoin_hooks = hooks
			end,
		},
		on_state = function(_, fn)
			handlers[#handlers + 1] = fn
		end,
		run_save = {
			stage_load = function() end,
			unstage_load = function() end,
			-- Like MPAPI.run_save.restore: runs the state hook in a pcall, false and the reason on a failure.
			restore = function(envelope)
				local ok, err = pcall(registered.load, envelope.mods.pvp)
				if not ok then return false, err end
				return true
			end,
			register_state = function(_, hooks)
				registered = hooks
			end,
		},
	}
	G = {
		STAGE = "run",
		STAGES = { RUN = "run" },
		GAME = { round_resets = { ante = 2 }, blind_on_deck = "Big", blind = { dollars = 5 } },
	}
	frame = function() end
	Game = {
		update = function()
			frame()
		end,
	}
	dofile("lib/pending_death.lua")
	dofile("lib/_state_value.lua")
	dofile("lib/applied_effects.lua")
	dofile("lib/lives_view.lua")
	dofile("lib/result_view.lua")
	dofile("lib/lives_lookup.lua")
	dofile("lib/run_save.lua")
	local function noop() end
	PVP.OpponentNet = { begin_catch_up = noop, end_catch_up = noop, abort_catch_up = noop }
	dofile("lib/rejoin.lua")
	dofile("pvp_api/run_gate.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile(os.getenv("LIVES_NET_PATH") or "pvp_api/lives_net.lua")
end

local function equal(got, want, what)
	assert(got == want, ("%s: got %s, wanted %s"):format(what or "value", tostring(got), tostring(want)))
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

local function lives_state(run_id, mine, theirs, events, third)
	local players = { me = { lives = mine, events = events or {} }, they = { lives = theirs, events = {} } }
	if third then players.third = { lives = third, events = {} } end
	return { runId = run_id, players = players, teamLives = nil, pending = {} }
end

local function push(value)
	state = value
	handlers[1](value)
end

local function run_frame()
	PVP.LivesNet.update()
end

local LOSS = { delta = -1, key = "2:Big" }

test("subscribes to pvp.lives at load", function()
	setup()
	equal(#handlers, 1)
end)

test("a STATE with opponent lives 2 shows 2 and fills the cache", function()
	setup()
	push(lives_state("r1", 4, 2))
	equal(PVP._player_lives_cache.me, 4)
	equal(PVP._player_lives_cache.they, 2)
	equal(
		PVP.shown_opponent_lives({
			self_id = "me",
			player_ids = { "me", "they" },
			cache = PVP._player_lives_cache,
			starting_lives = 4,
		}),
		2
	)
end)

test("nemesis shows the nemesis's lives, no nemesis shows the highest of the others", function()
	setup()
	push(lives_state("r1", 4, 2, {}, 6))
	local sources = {
		self_id = "me",
		player_ids = { "me", "they", "third" },
		cache = PVP._player_lives_cache,
		starting_lives = 4,
	}
	sources.nemesis_id = "they"
	equal(PVP.shown_opponent_lives(sources), 2)
	sources.nemesis_id = nil
	equal(PVP.shown_opponent_lives(sources), 6)
end)

test("a loss applies once: lives, HUD, comeback gold; a repeat and a SNAPSHOT do nothing", function()
	setup()
	local value = lives_state("r1", 3, 4, { LOSS })
	push(value)
	equal(PVP.GAME.lives, 3)
	equal(#eased, 1)
	equal(eased[1].delta, -1)
	equal(eased[1].instant, true)
	equal(PVP.GAME.comeback_bonus, 1)
	equal(PVP.GAME.comeback_bonus_given, false)
	equal(PVP.GAME.applied.events.me, 1)
	push(value)
	push(lives_state("r1", 3, 4, { LOSS }))
	run_frame()
	equal(#eased, 1)
	equal(PVP.GAME.comeback_bonus, 1)
end)

test("dollars are zeroed only for a matching blind key", function()
	setup({ no_gold = true })
	push(lives_state("r1", 3, 4, { LOSS }))
	equal(G.GAME.blind.dollars, 0)
	setup({ no_gold = true })
	push(lives_state("r1", 3, 4, { { delta = -1, key = "1:Boss" } }))
	equal(G.GAME.blind.dollars, 5)
	setup({ no_gold = true })
	PVP.is_pvp_boss = function()
		return true
	end
	PVP.GAME.round_id = 7
	push(lives_state("r1", 3, 4, { { delta = -1, key = "pvp:7" } }))
	equal(G.GAME.blind.dollars, 0)
	setup({ no_gold = true })
	PVP.is_pvp_boss = function()
		return true
	end
	PVP.GAME.round_id = 8
	push(lives_state("r1", 3, 4, { { delta = -1, key = "pvp:7" } }))
	equal(G.GAME.blind.dollars, 5)
end)

-- The offline lobby a crash rejoin's catch-up plays in.
local function playback_lobby()
	local lobby = make_lobby("me")
	lobby._nakama = false
	return lobby
end

test("rejoin: load, attach with the reset, CONNECTED, then a push applies each event exactly once", function()
	setup()
	current = playback_lobby()
	push(lives_state("r1", 2, 4, { LOSS, { delta = -1, key = "2:Boss" } }))
	equal(PVP._player_lives_cache.me, 2, "cache is written at once")
	registered.load({ lives = 3, comeback_bonus = 1, applied = { runId = "r1", events = { me = 1 } } })
	run_frame()
	run_frame()
	equal(#eased, 0, "nothing applies while the playback lobby is current")
	-- The live lobby is attached: its CONNECTED handler (lobby_bridge.lua) re-reads the lives
	-- while the lobby still holds its messages, then the lobby is released.
	local live = make_lobby("me")
	live._holding = true
	rejoin_hooks.attach(live, {})
	equal(PVP.GAME.applied.events.me, 1, "the reset did not wipe the applied index")
	equal(PVP.GAME.lives, nil, "own lives are unknown until the server total arrives, not the saved or starting count")
	equal(PVP.GAME.comeback_bonus, 1, "nor the comeback gold")
	current = live
	PVP.LivesNet.on_connected()
	run_frame()
	equal(#eased, 0, "a held lobby is not live yet")
	live._holding = false
	run_frame()
	equal(#eased, 1, "only the event after the saved index")
	equal(eased[1].delta, -1)
	equal(PVP.GAME.lives, 2)
	equal(PVP.GAME.comeback_bonus, 2, "one more comeback bonus, not a jump")
	equal(PVP.GAME.applied.events.me, 2)
	push(lives_state("r1", 2, 4, { LOSS, { delta = -1, key = "2:Boss" } }))
	run_frame()
	equal(#eased, 1)
	equal(PVP.GAME.comeback_bonus, 2)
end)

test("a catch-up with nothing saved applies the whole log and ends on the server's lives", function()
	setup()
	local live = make_lobby("me")
	live._holding = true
	current = playback_lobby()
	push(lives_state("r1", 2, 4, { LOSS, { delta = -1, key = "2:Boss" } }))
	rejoin_hooks.attach(live, {})
	current = live
	PVP.LivesNet.on_connected()
	live._holding = false
	run_frame()
	equal(#eased, 2)
	equal(PVP.GAME.lives, 2)
end)

test("a playback lobby being current applies nothing, however often it is read", function()
	setup()
	current = playback_lobby()
	push(lives_state("r1", 3, 4, { LOSS }))
	PVP.LivesNet.on_connected()
	run_frame()
	equal(#eased, 0)
	equal(PVP.GAME.applied, nil)
	equal(PVP._player_lives_cache.me, 3)
end)

test("an aborted catch-up then a fresh run: lives apply in the fresh run", function()
	setup()
	current = playback_lobby()
	push(lives_state("r1", 3, 4, { LOSS }))
	run_frame()
	equal(#eased, 0)
	-- aborted: the player is back at the menu, then starts a new run in a live lobby
	current = nil
	run_frame()
	PVP.reset_game_states()
	current = make_lobby("me")
	current._game.started.run_id = "r2"
	push(lives_state("r2", 3, 4, { { delta = -1, key = "1:Small" } }))
	equal(#eased, 1)
	equal(PVP.GAME.applied.runId, "r2")
end)

test("a pending apply is dropped when there is no PvP lobby any more", function()
	setup()
	current = playback_lobby()
	push(lives_state("r1", 3, 4, { LOSS }))
	current = nil
	run_frame()
	current = make_lobby("me")
	run_frame()
	equal(#eased, 0, "nothing applies on its own after the lobby was gone")
end)

test("a runId change resets the index", function()
	setup()
	push(lives_state("r1", 3, 4, { LOSS }))
	equal(#eased, 1)
	current = make_lobby("me")
	current._game.started.run_id = "r2"
	push(lives_state("r2", 3, 4, { { delta = -1, key = "1:Small" } }))
	equal(#eased, 2)
	equal(PVP.GAME.applied.runId, "r2")
	equal(PVP.GAME.applied.events.me, 1)
end)

test("a state of another run than the lobby's changes nothing", function()
	setup()
	push(lives_state("r0", 1, 1, { LOSS, LOSS }))
	equal(#eased, 0)
	equal(PVP._player_lives_cache, nil)
end)

test("a save round trip keeps the index: the same state after the load applies nothing", function()
	setup()
	local value = lives_state("r1", 3, 4, { LOSS })
	push(value)
	equal(#eased, 1)
	local saved = registered.save()
	equal(saved.applied.events.me, 1)
	registered.load(saved)
	equal(PVP.GAME.applied.events.me, 1)
	push(value)
	equal(#eased, 1)
	push(lives_state("r1", 2, 4, { LOSS, LOSS }))
	equal(#eased, 2)
end)

test("a non-PvP lobby is ignored", function()
	setup()
	current.mod_id = "other"
	push(lives_state("r1", 3, 4, { LOSS }))
	equal(#eased, 0)
	equal(PVP._player_lives_cache, nil)
end)

test("an opponent drop from 4 to 3 shows 3 and signals once; a repeated state does not signal again", function()
	setup()
	push(lives_state("r1", 4, 4))
	equal(signals, 0, "first sight")
	push(lives_state("r1", 4, 3))
	equal(PVP.GAME.enemy.lives, 3)
	equal(signals, 1)
	equal(juiced, 1)
	push(lives_state("r1", 4, 3))
	push(lives_state("r1", 4, 3))
	equal(signals, 1, "the same state three times")
	equal(juiced, 1)
end)

test("a first SNAPSHOT at 2 shows 2 and plays nothing, also after a rejoin's CONNECTED re-read", function()
	setup()
	push(lives_state("r1", 4, 2))
	equal(PVP.GAME.enemy.lives, 2)
	equal(signals, 0)
	PVP.LivesNet.on_connected()
	equal(signals, 0)
	push(lives_state("r1", 4, 2))
	equal(signals, 0, "a SNAPSHOT repeating the value")
end)

test("own lives dropping signals nothing about the opponent and logs the loss once", function()
	setup()
	push(lives_state("r1", 4, 4))
	push(lives_state("r1", 3, 4, { LOSS }))
	equal(signals, 0)
	equal(PVP.GAME.enemy.lives, 4)
	equal(#logged, 1)
	equal(logged[1].payload.lost, 1)
	equal(logged[1].payload.lives, 3)
	push(lives_state("r1", 3, 4, { LOSS }))
	equal(#logged, 1)
end)

test("a new run starts a fresh sighting: its first value is not a drop", function()
	setup()
	push(lives_state("r1", 4, 4))
	current._game.started.run_id = "r2"
	push(lives_state("r2", 4, 1))
	equal(signals, 0)
	equal(PVP.GAME.enemy.lives, 1)
end)

test("saved lives that differ from the server total end on the total, with no new events", function()
	setup()
	registered.load({ lives = 1, applied = { runId = "r1", events = { me = 1 } } })
	push(lives_state("r1", 3, 4, { LOSS }))
	run_frame()
	equal(#eased, 0, "no new event")
	equal(PVP.GAME.lives, 3)
end)

test("a state cached from another run does not overwrite a fresh run's lives", function()
	setup()
	push(lives_state("r1", 2, 4, { LOSS, LOSS }))
	equal(PVP.GAME.lives, 2)
	-- a fresh run starts in the same lobby; the r1 state is still the mirror's
	current._game.started.run_id = "r2"
	PVP.GAME.lives = 4
	PVP.LivesNet.on_connected()
	run_frame()
	equal(PVP.GAME.lives, 4)
	current._game.started.run_id = nil
	PVP.LivesNet.on_connected()
	run_frame()
	equal(PVP.GAME.lives, 4, "nor with no current run")
end)

test("a target switch A, B, A with A dropping meanwhile plays no signal", function()
	setup()
	push(lives_state("r1", 4, 4, {}, 4))
	PVP.target = "third"
	push(lives_state("r1", 4, 4, {}, 4))
	push(lives_state("r1", 4, 3, {}, 4))
	equal(signals, 0, "A dropped while B was the target")
	PVP.target = "they"
	push(lives_state("r1", 4, 3, {}, 4))
	equal(signals, 0, "back to A")
	push(lives_state("r1", 4, 2, {}, 4))
	equal(signals, 1, "a real drop of the current target")
end)

test("rejoin's attach keeps the round-end marks", function()
	setup()
	PVP.GAME.round_end_applied = { r1 = true }
	local marks = PVP.GAME.round_end_applied
	rejoin_hooks.attach(make_lobby("me"), {})
	equal(PVP.GAME.round_end_applied, marks)
end)

-- R31: elimination in a game that started with 3 or more players.
local function out_state(run_id, pending)
	local value = lives_state(run_id, 0, 3, {}, 2)
	value.players.me.eliminated = true
	value.pending = pending or {}
	return value
end

test("N>2: an eliminated player is told once over identical STATE pushes, with { player_id }", function()
	setup()
	rules_state = { runId = "r1", mode = "royale", startedCount = 3 }
	push(out_state("r1"))
	equal(#eliminated_calls, 1)
	equal(eliminated_calls[1].player_id, "me")
	push(out_state("r1"))
	run_frame()
	equal(#eliminated_calls, 1, "a repeated STATE")
	PVP.LivesNet.on_connected()
	equal(#eliminated_calls, 1, "a rejoin's re-read in the same session")
	equal(PVP.GAME.result_handled, true, "pvp.result must not run the loss again")
	equal(PVP.config.recordedRuns[1], "r1", "the run is recorded as pvp.result does")
	-- Only the latch holds now: what reset_game_states clears is cleared, the run is not recorded.
	PVP.GAME.result_handled = nil
	PVP.config.recordedRuns = nil
	push(out_state("r1"))
	equal(#eliminated_calls, 1, "the per-run latch, not result_handled, stops a repeat")
end)

test("N>2: a pending death settled by a draw result in the same push: the result decides", function()
	setup()
	rules_state = { runId = "r1", mode = "royale", startedCount = 3 }
	push(out_state("r1", { { playerId = "me", blindKey = "2:Big", waitsOn = { "they", "third" } } }))
	equal(#eliminated_calls, 0)
	-- the server clears my entry and writes the result in one push; lives is read first
	result_state = { runId = "r1", kind = "draw", places = { { playerId = "me", place = 1 } } }
	push(out_state("r1"))
	equal(#eliminated_calls, 0, "no loss before the draw")
	equal(PVP.GAME.result_handled, nil, "pvp.result still shows its end screen")
	equal(PVP.config.recordedRuns, nil)
end)

test("N>2: a run recorded already (a crash rejoin) shows nothing and records nothing more", function()
	setup({ recorded = { "r1" } })
	rules_state = { runId = "r1", mode = "royale", startedCount = 3 }
	push(out_state("r1"))
	equal(#eliminated_calls, 0)
	equal(#PVP.config.recordedRuns, 1)
end)

test("N>2: a pending death waits, then the final one is told once", function()
	setup()
	rules_state = { runId = "r1", mode = "royale", startedCount = 3 }
	push(out_state("r1", { { playerId = "me", blindKey = "2:Big", waitsOn = { "they", "third" } } }))
	equal(#eliminated_calls, 0)
	equal(PVP.GAME.result_handled, nil)
	push(out_state("r1"))
	equal(#eliminated_calls, 1)
end)

test("a duel never tells the player it is eliminated", function()
	setup()
	rules_state = { runId = "r1", mode = "standard", startedCount = 2 }
	push(out_state("r1"))
	equal(#eliminated_calls, 0)
	equal(PVP.GAME.result_handled, nil)
end)

test("N>2: no rules of this run, or a player still alive, tells nothing", function()
	setup()
	push(out_state("r1"))
	equal(#eliminated_calls, 0, "no rules value yet")
	rules_state = { runId = "r0", mode = "royale", startedCount = 3 }
	push(out_state("r1"))
	equal(#eliminated_calls, 0, "rules of another run")
	rules_state = { runId = "r1", mode = "royale", startedCount = 3 }
	push(lives_state("r1", 2, 3, {}, 2))
	equal(#eliminated_calls, 0, "alive")
end)

test("N>2: a new run tells again; a result already handled is not run again", function()
	setup()
	rules_state = { runId = "r1", mode = "royale", startedCount = 3 }
	push(out_state("r1"))
	equal(#eliminated_calls, 1)
	current._game.started.run_id = "r2"
	PVP.GAME.result_handled = nil
	rules_state = { runId = "r2", mode = "royale", startedCount = 3 }
	push(out_state("r2"))
	equal(#eliminated_calls, 2, "the new run")
	current._game.started.run_id = "r3"
	PVP.GAME.result_handled = true
	rules_state = { runId = "r3", mode = "royale", startedCount = 3 }
	push(out_state("r3"))
	equal(#eliminated_calls, 2, "the result already ended this run")
end)

if failures > 0 then os.exit(1) end
print("lives_net_test: ok")
