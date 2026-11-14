-- Run from the repo root: luajit tests/unit/targets_net_test.lua
-- The shell around lib/targets_view.lua with the real lobby_bridge.lua readers and a stubbed
-- MPAPI: a Nemesis-pairing lobby names its opponent from the server's pvp.targets state, and a
-- state change updates what depends on the opponent.
-- LOBBY_BRIDGE_PATH (optional) points at another copy of pvp_api/lobby_bridge.lua, to check a
-- test against older code.
local states, listeners, lobby, mirrored

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

local function make_lobby(mod_id, player_count)
	local made = { mod_id = mod_id, player_id = "me", _game = { started = { run_id = "r1" } } }
	function made:get_players()
		local players = { { id = "me" }, { id = "they" }, { id = "third" }, { id = "fourth" } }
		return { (unpack or table.unpack)(players, 1, player_count or 2) }
	end
	return made
end

local labels
local function setup(config, player_count)
	states, listeners, mirrored, labels = {}, {}, 0, 0
	lobby = make_lobby("pvp", player_count)
	MPAPI = {
		get_current_lobby = function()
			return lobby
		end,
		get_state = function(key)
			return states[key]
		end,
		on_state = function(key, fn)
			listeners[key] = fn
		end,
	}
	PVP = {
		id = "pvp",
		GAME = { enemy = { lives = 4 } },
		LOBBY = { config = config or { nemesis_pairing = true, starting_lives = 4 } },
		-- What the lives net filled in from pvp.lives.
		_player_lives_cache = { me = 4, they = 2 },
		CURRENT_LOBBY = lobby,
		UI = {
			refresh_enemy_score_label = function()
				labels = labels + 1
			end,
		},
		mirror_players = function()
			mirrored = mirrored + 1
		end,
	}
	dofile("lib/lives_lookup.lua")
	dofile(os.getenv("LOBBY_BRIDGE_PATH") or "pvp_api/lobby_bridge.lua")
	-- lobby_bridge.lua replaced the stub with the real mirror; the rows count the calls instead.
	PVP.mirror_players = function()
		mirrored = mirrored + 1
	end
	dofile("lib/_state_value.lua")
	dofile("lib/targets_view.lua")
	dofile("lib/lives_view.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/targets_net.lua")
end

local function targets(run_id, opponents, extra)
	local value = { runId = run_id, opponents = opponents, cardTargets = {}, teamScores = nil }
	for key, entry in pairs(extra or {}) do
		value[key] = entry
	end
	return value
end

local function push(value)
	states["pvp.targets"] = value
	listeners["pvp.targets"](value)
end

test("subscribes to pvp.targets at load", function()
	setup()
	equal(type(listeners["pvp.targets"]), "function")
end)

test("a 2-player Nemesis lobby names its opponent from pvp.targets", function()
	setup()
	states["pvp.targets"] = targets("r1", { me = "they", they = "me" })
	equal(PVP.current_target_id(), "they", "current_target_id()")
	equal(PVP.is_byed(), false, "is_byed()")
	equal(PVP.is_announced_bye(), false, "is_announced_bye()")
end)

test("no pvp.targets value: no target, byed, and not an announced bye", function()
	setup()
	equal(PVP.current_target_id(), nil, "current_target_id()")
	equal(PVP.is_byed(), true, "is_byed()")
	equal(PVP.is_announced_bye(), false, "is_announced_bye()")
end)

test("a pvp.targets value of another run: no target, byed, and not an announced bye", function()
	setup()
	states["pvp.targets"] = targets("r0", { me = "they", they = "me" })
	equal(PVP.current_target_id(), nil, "current_target_id()")
	equal(PVP.is_byed(), true, "is_byed()")
	equal(PVP.is_announced_bye(), false, "is_announced_bye()")
end)

test("a current-run value with no opponent for this player is an announced bye", function()
	setup()
	states["pvp.targets"] = targets("r1", { other = "third" })
	equal(PVP.current_target_id(), nil, "current_target_id()")
	equal(PVP.is_byed(), true, "is_byed()")
	equal(PVP.is_announced_bye(), true, "is_announced_bye()")
	states["pvp.targets"] = targets("r1", {})
	equal(PVP.is_announced_bye(), false, "an empty map pairs nobody")
end)

test("the opponent is read from the state each time: a new value changes it, with no push needed", function()
	setup()
	states["pvp.targets"] = targets("r1", { me = "they" })
	equal(PVP.current_target_id(), "they")
	states["pvp.targets"] = targets("r1", {})
	equal(PVP.current_target_id(), nil)
	lobby._game.started.run_id = "r2"
	states["pvp.targets"] = targets("r1", { me = "they" })
	equal(PVP.current_target_id(), nil, "the lobby moved to a new run")
end)

test("a pvp.targets change brings the enemy lives to the opponent's lives", function()
	setup()
	push(targets("r1", { me = "they", they = "me" }))
	equal(PVP.GAME.enemy.lives, 2)
end)

test("a pvp.targets change updates the lobby mirror and the ante's Nemesis", function()
	setup()
	push(targets("r1", { me = "they", they = "me" }))
	equal(mirrored, 1, "mirror_players calls")
end)

test("no lobby mirror call when no lobby is set", function()
	setup()
	PVP.CURRENT_LOBBY = nil
	push(targets("r1", { me = "they", they = "me" }))
	equal(mirrored, 0)
	equal(PVP.GAME.enemy.lives, 2)
end)

test("a pvp.targets change outside a PvP lobby does nothing", function()
	setup()
	lobby.mod_id = "other"
	push(targets("r1", { me = "they", they = "me" }))
	equal(PVP.GAME.enemy.lives, 4)
	equal(mirrored, 0)
	lobby = nil
	listeners["pvp.targets"](states["pvp.targets"])
	equal(PVP.GAME.enemy.lives, 4, "no lobby at all")
end)

test("a pvp.targets change in a lobby without Nemesis pairing updates nothing", function()
	setup({ starting_lives = 4 })
	push(targets("r1", { me = "they", they = "me" }))
	equal(PVP.GAME.enemy.lives, 4)
	equal(mirrored, 0, "mirror_players calls")
end)

test("refresh() runs the same updates from the held state", function()
	setup()
	states["pvp.targets"] = targets("r1", { me = "they", they = "me" })
	PVP.TargetsNet.refresh()
	equal(PVP.GAME.enemy.lives, 2)
	equal(mirrored, 1)
end)

test("a rebuilt PVP.GAME (rejoin, reconnect) still names the opponent, with no new push", function()
	setup()
	push(targets("r1", { me = "they", they = "me" }))
	PVP.GAME = { enemy = {} }
	equal(PVP.current_target_id(), "they", "current_target_id()")
	equal(PVP.is_byed(), false, "is_byed()")
	PVP.refresh_target_lives()
	equal(PVP.GAME.enemy.lives, 2, "the enemy lives follow again")
end)

test("known() and opponent_id() with no lobby", function()
	setup()
	states["pvp.targets"] = targets("r1", { me = "they" })
	lobby = nil
	equal(PVP.TargetsNet.known(), false)
	equal(PVP.TargetsNet.opponent_id(), nil)
end)

test("a plain 2-player lobby (no Nemesis pairing) still names the other player", function()
	setup({ starting_lives = 4 })
	equal(PVP.current_target_id(), "they")
	equal(not PVP.is_byed(), true, "not is_byed()")
end)

test("a 3-player Royale lobby follows pvp.targets: lives, mirror, score label", function()
	setup({ starting_lives = 4 }, 3)
	push(targets("r1", { me = "they", they = "me", third = "me" }, { safe = { me = true } }))
	equal(PVP.GAME.enemy.lives, 2, "the target's lives")
	equal(mirrored, 1, "mirror_players calls")
	equal(labels, 1, "score label refreshes")
end)

test("a Royale that started with 3 still follows pvp.targets after a seat leaves", function()
	setup({ starting_lives = 4 }, 2)
	states["pvp.rules"] = { runId = "r1", startedCount = 3 }
	push(targets("r1", { me = "they", they = "me", third = "me" }))
	equal(PVP.GAME.enemy.lives, 2, "the target's lives")
	equal(mirrored, 1, "mirror_players calls")
	equal(labels, 1, "score label refreshes")
end)

test("a game that started with 2 is a duel whatever the seats: not touched", function()
	setup({ starting_lives = 4 }, 3)
	states["pvp.rules"] = { runId = "r1", startedCount = 2 }
	push(targets("r1", { me = "they", they = "me" }))
	equal(mirrored, 0, "mirror_players calls")
end)

test("player_count() is the started count of this run, else the live seats", function()
	setup({ starting_lives = 4 }, 2)
	equal(PVP.TargetsNet.player_count(lobby), 2, "no rules yet")
	states["pvp.rules"] = { runId = "r0", startedCount = 4 }
	equal(PVP.TargetsNet.player_count(lobby), 2, "rules of another run")
	states["pvp.rules"] = { runId = "r1", startedCount = 4 }
	equal(PVP.TargetsNet.player_count(lobby), 4, "rules of this run")
end)

test("a Manhunt lobby that started with 4 follows pvp.targets: lives, mirror", function()
	setup({ starting_lives = 4, manhunt = true }, 4)
	push(targets("r1", { me = "they", they = "me", third = "me", fourth = "me" }))
	equal(PVP.current_target_id(), "they", "current_target_id()")
	equal(PVP.GAME.enemy.lives, 2, "the target's lives")
	equal(mirrored, 1, "mirror_players calls")
end)

test("a Manhunt lobby that started with 2 is a duel: not touched", function()
	setup({ starting_lives = 4, manhunt = true }, 2)
	push(targets("r1", { me = "they", they = "me" }))
	equal(PVP.GAME.enemy.lives, 4)
	equal(mirrored, 0, "mirror_players calls")
end)

test("a Teams lobby of 4 does not follow pvp.targets: its card target comes from TeamsNet", function()
	setup({ starting_lives = 4, team_based = true }, 4)
	push(targets("r1", { me = "they", they = "me" }))
	equal(PVP.GAME.enemy.lives, 4)
	equal(mirrored, 0, "teams: mirror_players calls")
end)

test("a 2-player lobby without Nemesis pairing is not touched (a duel)", function()
	setup({ starting_lives = 4 }, 2)
	push(targets("r1", { me = "they", they = "me" }))
	equal(labels, 0, "score label refreshes")
end)

test("safe() is the server's marker for this player, nil until it is ranked", function()
	setup({ starting_lives = 4 }, 3)
	equal(PVP.TargetsNet.safe(), nil, "no state")
	states["pvp.targets"] = targets("r1", { me = "they" }, { safe = { me = false } })
	equal(PVP.TargetsNet.safe(), false, "a losing player")
	states["pvp.targets"] = targets("r1", { me = "they" }, { safe = { me = true } })
	equal(PVP.TargetsNet.safe(), true, "a safe player")
	states["pvp.targets"] = targets("r1", { me = "they" }, { safe = {} })
	equal(PVP.TargetsNet.safe(), nil, "outside Royale the map is empty")
	states["pvp.targets"] = targets("r0", { me = "they" }, { safe = { me = true } })
	equal(PVP.TargetsNet.safe(), nil, "another run")
	lobby = nil
	equal(PVP.TargetsNet.safe(), nil, "no lobby")
end)

if failed > 0 then os.exit(1) end
print(("targets_net_test: ok (%d rows)"):format(passed))
