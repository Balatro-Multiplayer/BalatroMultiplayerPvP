-- Run from the repo root: luajit tests/unit/skips_net_test.lua
-- pvp_api/skips_net.lua over the real lib/skips_view.lua: the server's "pvp.skips" state feeds the
-- opponent's skips and keeps this player's Ante bank for the box (bank_seconds); a skip and a Preview cost are requests.
local requests, sounds, juiced, state, opts

local function setup(o)
	opts = o or {}
	requests, sounds, juiced, state = {}, {}, 0, {}
	local lobby = { mod_id = "pvp", player_id = "me", _game = { started = { run_id = "run1" } } }
	PVP = {
		id = "pvp",
		LOBBY = { config = { timer = true } },
		GAME = {
			enemy = { skips = nil },
		},
		match_log = function() end,
		current_target_id = function()
			return opts.target or "they"
		end,
		is_byed = function()
			return false
		end,
		is_pvp_boss = function()
			return opts.pvp_boss == true
		end,
		current_ruleset = function()
			return { enemy_location_disabled = opts.location_disabled }
		end,
		UI = {
			juice_up_pvp_hud = function()
				juiced = juiced + 1
			end,
		},
	}
	play_sound = function(name)
		sounds[#sounds + 1] = name
	end
	MPAPI = {
		get_current_lobby = function()
			if opts.no_lobby then return nil end
			return lobby
		end,
		get_state = function(key)
			return state[key]
		end,
		on_state = function() end,
		request = function(kind, payload, on_result)
			requests[#requests + 1] = { kind = kind, payload = payload, on_result = on_result }
		end,
	}
	dofile("lib/_state_value.lua")
	dofile("lib/skips_view.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/skips_net.lua")
end

-- The server's state: `mine` / `theirs` are { skips = n|nil, bank = ms }.
local function push(mine, theirs, run_id)
	local function player(p)
		return { skips = p.skips, anteBankMs = p.bank }
	end
	state["pvp.skips"] = {
		runId = run_id or "run1",
		players = { me = player(mine or { bank = 150000 }), they = player(theirs or { bank = 150000 }) },
	}
	PVP.SkipsNet.evaluate(state["pvp.skips"])
end

local failures = 0
local function test(name, fn, o)
	setup(o)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

-- Requests.

test("skip: one pvp.skip with the run, the total and the skipped blind", function()
	PVP.SkipsNet.skip(2, "1:Big")
	equal(#requests, 1)
	equal(requests[1].kind, "pvp.skip")
	equal(requests[1].payload.runId, "run1")
	equal(requests[1].payload.skips, 2)
	equal(requests[1].payload.blindKey, "1:Big")
end)

test("skip: no total, nothing is sent", function()
	PVP.SkipsNet.skip(nil, "1:Small")
	equal(#requests, 0)
end)

test("skip: a blind key that is not a string is logged and nothing is sent", function()
	local logged
	PVP.match_log = function(_, text)
		logged = text
	end
	PVP.SkipsNet.skip(1, nil)
	PVP.SkipsNet.skip(1, 12)
	equal(#requests, 0)
	assert(logged and logged:find("no blind key", 1, true), tostring(logged))
end)

-- The skip hook in ui/game/functions.lua over the real PVP.net_route (pvp_api/net.lua, which builds
-- the pvp.progress payload) and the real PVP.SkipsNet: progress goes out before the skip, at the
-- ante the blind key names. PVP.ACTIONS.set_furthest_blind and .skip are the thin routes of
-- networking/action_handlers.lua, restated here because that file needs the whole game.
local function skip_hook_case(blind, furthest, key, no_code)
	local order = {}
	PVP.GAME.furthest_blind = 0
	PVP.OpponentNet = {
		report_skip = function()
			order[#order + 1] = "report_skip"
		end,
	}
	PVP.LOBBY.code = (not no_code) and "ABC" or nil
	PVP.RoundNet = {
		progress = function(args)
			MPAPI.request("pvp.progress", args)
		end,
	}
	MPAPI.ActionTypes = {}
	dofile("pvp_api/net.lua")
	PVP.ACTIONS = {
		blind_result = function() end,
		update_location = function() end,
		skip = function(skips, blind_key)
			PVP.SkipsNet.skip(skips, blind_key)
		end,
		set_furthest_blind = function(furthest_blind)
			PVP.net_route({ action = "setFurthestBlind", furthestBlind = furthest_blind })
		end,
	}
	G = {
		GAME = {
			skips = 1,
			blind_on_deck = blind,
			round_resets = { ante = 3, blind_states = { Small = "Select", Big = "Select" } },
		},
		FUNCS = {
			skip_blind = function()
				G.GAME.round_resets.blind_states[blind] = "Skipped"
			end,
		},
	}
	local real_request = MPAPI.request
	MPAPI.request = function(kind, payload, on_result)
		order[#order + 1] = kind
		real_request(kind, payload, on_result)
	end
	dofile("ui/game/functions.lua")
	G.FUNCS.skip_blind({})
	if no_code then return order end
	equal(table.concat(order, ","), "pvp.progress,pvp.skip,report_skip")
	equal(requests[1].payload.runId, "run1")
	equal(requests[1].payload.ante, 3)
	equal(requests[1].payload.furthestBlind, furthest)
	equal(requests[2].payload.skips, 1)
	equal(requests[2].payload.blindKey, key)
	equal(key:match("^(%d+):"), tostring(requests[1].payload.ante))
end

test("skip hook: a skip with no lobby code (the crash-rejoin catch-up) still numbers the blind slot", function()
	local order = skip_hook_case("Big", 32, "3:Big", true)
	equal(table.concat(order, ","), "report_skip")
	equal(#requests, 0)
end)

test("skip hook: skipping the Big blind sends progress, pvp.skip with the key 3:Big, then the blind slot", function()
	skip_hook_case("Big", 32, "3:Big")
end)

test("skip hook: skipping the Small blind sends progress, pvp.skip with the key 3:Small, then the blind slot", function()
	skip_hook_case("Small", 31, "3:Small")
end)

test("skip: not in PvP's lobby, nothing is sent", function()
	PVP.SkipsNet.skip(1, "1:Small")
	PVP.SkipsNet.spend(1000)
	equal(#requests, 0)
end, { no_lobby = true })

test("spend: one pvp.timer_spend in whole milliseconds", function()
	PVP.SkipsNet.spend(2500.4)
	equal(requests[1].kind, "pvp.timer_spend")
	equal(requests[1].payload.runId, "run1")
	equal(requests[1].payload.ms, 2500)
end)

test("spend: zero or negative is not sent", function()
	PVP.SkipsNet.spend(0)
	PVP.SkipsNet.spend(-5)
	equal(#requests, 0)
end)

test("a refusal is logged and changes nothing", function()
	local logged
	PVP.match_log = function(_, text)
		logged = text
	end
	PVP.SkipsNet.skip(1, "1:Small")
	requests[1].on_result(false, { reason = "stale" })
	assert(logged and logged:find("pvp.skip refused: stale", 1, true), tostring(logged))
end)

-- The opponent's skips.

test("state: the target's skips are shown, nil while the server says null", function()
	push({ bank = 150000 }, { skips = nil, bank = 150000 })
	equal(PVP.GAME.enemy.skips, nil)
	push({ bank = 150000 }, { skips = 2, bank = 150000 })
	equal(PVP.GAME.enemy.skips, 2)
end)

test("state: a rise plays the signal and juices the HUD", function()
	push()
	push(nil, { skips = 1, bank = 150000 })
	equal(table.concat(sounds, ","), "negative,gong")
	equal(juiced, 1)
	push(nil, { skips = 3, bank = 150000 })
end)

test("state: the first sight is a baseline: a rejoin's total plays nothing", function()
	push(nil, { skips = 4, bank = 150000 })
	equal(PVP.GAME.enemy.skips, 4)
	equal(#sounds, 0)
end)

test("state: the same state again plays nothing more", function()
	push()
	push(nil, { skips = 1, bank = 150000 })
	push(nil, { skips = 1, bank = 150000 })
	equal(#sounds, 2)
end)

test("state: a ruleset with the location hidden plays no signal", function()
	push()
	push(nil, { skips = 1, bank = 150000 })
	equal(#sounds, 0)
end, { location_disabled = true })

test("state: a state of another run is ignored", function()
	push(nil, { skips = 5, bank = 150000 }, "run0")
	equal(PVP.GAME.enemy.skips, nil)
end)

test("state: no lobby, nothing is read", function()
	push(nil, { skips = 5, bank = 150000 })
	equal(PVP.GAME.enemy.skips, nil)
end, { no_lobby = true })

test("state: a team lobby leaves the opponent's skips alone", function()
	PVP.LOBBY.config.team_based = true
	push(nil, { skips = 5, bank = 150000 })
	equal(PVP.GAME.enemy.skips, nil)
end)

test("the opponent's skip adds nothing to this player's clock: the server owns it", function()
	push()
	push(nil, { skips = 1, bank = 150000 })
	equal(PVP.SkipsNet.bank_seconds(), 150)
	equal(PVP.GAME.timer, nil)
	equal(PVP.UI.restore_timer, nil)
end)

-- This player's bank.

test("bank: the server's bank is what bank_seconds gives", function()
	push({ skips = 1, bank = 210000 })
	equal(PVP.SkipsNet.bank_seconds(), 210)
end)

test("bank: unknown until the server says it, and again when the state is not this run's", function()
	equal(PVP.SkipsNet.bank_seconds(), nil)
	push({ bank = 90000 })
	equal(PVP.SkipsNet.bank_seconds(), 90)
	push({ bank = 30000 }, nil, "run0")
	equal(PVP.SkipsNet.bank_seconds(), nil)
end)

test("bank: a bank the state does not carry is unknown, not 0", function()
	state["pvp.skips"] = { runId = "run1", players = { me = { skips = 1 }, they = { skips = 0, anteBankMs = 1 } } }
	PVP.SkipsNet.evaluate(state["pvp.skips"])
	equal(PVP.SkipsNet.bank_seconds(), nil)
end)

test("bank: the box's bank follows a running or started timer too: the net keeps no clock flags", function()
	PVP.GAME.timer_started = true
	push({ bank = 90000 })
	equal(PVP.SkipsNet.bank_seconds(), 90)
end)

test("bank: no lobby, none is kept", function()
	push({ bank = 90000 })
	equal(PVP.SkipsNet.bank_seconds(), nil)
end, { no_lobby = true })

test("on_connected reads the state again", function()
	state["pvp.skips"] = { runId = "run1", players = { me = { anteBankMs = 99000 }, they = { skips = 1, anteBankMs = 1 } } }
	PVP.SkipsNet.on_connected()
	equal(PVP.SkipsNet.bank_seconds(), 99)
	equal(PVP.GAME.enemy.skips, 1)
end)

test("target switch: enemy.skips is the new target's count, signalled by nothing, the next rise counts from it", function()
	state["pvp.skips"] = {
		runId = "run1",
		players = { me = { anteBankMs = 1 }, they = { skips = 1, anteBankMs = 1 }, other = { skips = 5, anteBankMs = 1 } },
	}
	PVP.SkipsNet.evaluate(state["pvp.skips"])
	equal(PVP.GAME.enemy.skips, 1)
	opts.target = "other"
	PVP.SkipsNet.update()
	equal(PVP.GAME.enemy.skips, 5)
	equal(#sounds, 0)
	state["pvp.skips"].players.other.skips = 6
	PVP.SkipsNet.evaluate(state["pvp.skips"])
	equal(PVP.GAME.enemy.skips, 6)
	equal(#sounds, 2)
end)

test("a new run: its first total is a baseline, no sound", function()
	push({ skips = 1, bank = 1 }, { skips = 1, bank = 1 })
	MPAPI.get_current_lobby()._game.started.run_id = "run2"
	push({ skips = 3, bank = 1 }, { skips = 3, bank = 1 }, "run2")
	equal(PVP.GAME.enemy.skips, 3)
	equal(#sounds, 0)
end)

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
