-- Run from the repo root: luajit tests/unit/teams_net_test.lua
-- The shell around lib/teams_view.lua with a stubbed MPAPI and PVP: the server's pvp.teams state
-- fills the lobby mirror, a Teams pvp.targets state shows the enemy team's score and follows the
-- card target, and a refused pick shows the server's roster again.
local states, listeners, lobby, eased, refreshed, requests, logs

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

local function setup(config)
	states, listeners, eased, refreshed, requests, logs = {}, {}, {}, 0, {}, {}
	lobby = { mod_id = "pvp", player_id = "me", _game = { started = { run_id = "r1" } } }
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
		request = function(kind, payload, on_result)
			requests[#requests + 1] = { kind = kind, payload = payload, on_result = on_result }
		end,
	}
	PVP = {
		id = "pvp",
		GAME = { enemy = {} },
		LOBBY = { config = config or { team_based = true }, roster = {} },
		match_log = function(level, text)
			logs[#logs + 1] = level .. " " .. text
		end,
		Score = {
			parse = function(text)
				return type(text) == "string" and text:match("^%d+$") and "S:" .. text or nil
			end,
		},
		UI = {
			ease_enemy_score = function(score)
				eased[#eased + 1] = score
			end,
		},
		refresh_target_lives = function()
			refreshed = refreshed + 1
		end,
	}
	dofile("lib/_state_value.lua")
	dofile("lib/teams_view.lua")
	dofile("lib/enemy_score_view.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/teams_net.lua")
end

local function teams(run_id, map)
	return { runId = run_id, teams = map }
end

local function targets(run_id, extra)
	local value = { runId = run_id, opponents = {}, cardTargets = {}, safe = {} }
	for key, entry in pairs(extra or {}) do
		value[key] = entry
	end
	return value
end

local function push(key, value)
	states[key] = value
	listeners[key](value)
end

test("subscribes to pvp.teams and pvp.targets at load", function()
	setup()
	equal(type(listeners["pvp.teams"]), "function", "pvp.teams")
	equal(type(listeners["pvp.targets"]), "function", "pvp.targets")
end)

test("a pvp.teams value fills the roster and this player's team", function()
	setup()
	push("pvp.teams", teams("r1", { me = "B", they = "A" }))
	equal(PVP.LOBBY.roster.me, "B", "my entry")
	equal(PVP.LOBBY.roster.they, "A", "their entry")
	equal(PVP.LOBBY.team_id, "B", "team_id")
end)

test("lobby picks (no runId) fill the roster before a run", function()
	setup()
	push("pvp.teams", teams(nil, { me = "A" }))
	equal(PVP.LOBBY.roster.me, "A")
	equal(PVP.LOBBY.team_id, "A")
end)

test("a Manhunt lobby mirrors the roster and nothing else", function()
	setup({ manhunt = true })
	states["pvp.targets"] = targets("r1", { teamScores = { A = "1", B = "2" } })
	push("pvp.teams", teams("r1", { me = "RUNNER", they = "HUNTER" }))
	equal(PVP.LOBBY.team_id, "RUNNER", "team_id")
	equal(PVP.LOBBY.roster.they, "HUNTER", "roster")
	equal(#eased, 0, "score eases")
	equal(refreshed, 0, "refresh_target_lives calls")
end)

test("a roster of another run empties the mirror", function()
	setup()
	push("pvp.teams", teams("r1", { me = "B", they = "A" }))
	push("pvp.teams", teams("r0", { me = "A", they = "B" }))
	equal(next(PVP.LOBBY.roster), nil, "roster")
	equal(PVP.LOBBY.team_id, nil, "team_id")
end)

test("a player the state does not name has no team", function()
	setup()
	push("pvp.teams", teams("r1", { they = "A" }))
	equal(PVP.LOBBY.roster.they, "A")
	equal(PVP.LOBBY.team_id, nil, "team_id")
end)

test("a Teams pvp.targets value shows the enemy team's score once", function()
	setup()
	states["pvp.teams"] = teams("r1", { me = "A", they = "B" })
	push("pvp.targets", targets("r1", { teamScores = { A = "100", B = "250" } }))
	equal(#eased, 1, "score eases")
	equal(eased[1], "S:250", "the other team's score")
	equal(PVP.GAME.enemy.real_score, "S:250", "real_score")
end)

test("team B shows team A's score", function()
	setup()
	states["pvp.teams"] = teams("r1", { me = "B", they = "A" })
	push("pvp.targets", targets("r1", { teamScores = { A = "100", B = "250" } }))
	equal(eased[1], "S:100")
end)

test("a team score that is not a score is logged and shown as nothing, never as 0", function()
	setup()
	states["pvp.teams"] = teams("r1", { me = "A", they = "B" })
	push("pvp.targets", targets("r1", { teamScores = { A = "100", B = "garbage" } }))
	equal(#eased, 0, "score eases")
	equal(PVP.GAME.enemy.real_score, nil, "real_score")
	assert(#logs == 1 and logs[1]:find("error", 1, true), "the bad score must be logged")
end)

test("a Teams pvp.targets value calls refresh_target_lives", function()
	setup()
	states["pvp.teams"] = teams("r1", { me = "A", they = "B" })
	push("pvp.targets", targets("r1", { cardTargets = { me = "they" } }))
	equal(refreshed, 1, "refresh_target_lives calls")
end)

test("no enemy score (none, another run, no team) leaves the display alone", function()
	setup()
	states["pvp.teams"] = teams("r1", { me = "A", they = "B" })
	push("pvp.targets", targets("r1"))
	push("pvp.targets", targets("r0", { teamScores = { A = "1", B = "2" } }))
	equal(#eased, 0, "score eases")
	equal(PVP.GAME.enemy.real_score, nil, "real_score")
	states["pvp.teams"] = teams("r1", { they = "B" })
	push("pvp.targets", targets("r1", { teamScores = { A = "1", B = "2" } }))
	equal(#eased, 0, "score eases with no team of mine")
end)

-- The score is the player's to see only for the round they are in (the server's score mask).
test("the enemy team's score is known only for my round", function()
	setup()
	PVP.GAME.round_id = 3
	states["pvp.teams"] = teams("r1", { me = "A", they = "B" })
	states["pvp.round"] = { runId = "r1", roundId = 2, phase = "playing", players = {} }
	push("pvp.targets", targets("r1", { teamScores = { A = "100", B = "250" } }))
	equal(#eased, 1, "the score still eases")
	equal(PVP.GAME.enemy.score_known, nil, "score_known for an older round")
	states["pvp.round"] = { runId = "r1", roundId = 3, phase = "playing", players = {} }
	push("pvp.targets", targets("r1", { teamScores = { A = "100", B = "250" } }))
	equal(PVP.GAME.enemy.score_known, true, "score_known for my round")
end)

test("a masked Teams state (no team scores) leaves score_known alone", function()
	setup()
	PVP.GAME.round_id = 3
	states["pvp.teams"] = teams("r1", { me = "A", they = "B" })
	states["pvp.round"] = { runId = "r1", roundId = 3, phase = "playing", players = {} }
	push("pvp.targets", targets("r1"))
	equal(PVP.GAME.enemy.score_known, nil, "score_known")
	equal(#eased, 0, "score eases")
end)

test("no pvp.round value yet leaves score_known alone", function()
	setup()
	PVP.GAME.round_id = 3
	states["pvp.teams"] = teams("r1", { me = "A", they = "B" })
	push("pvp.targets", targets("r1", { teamScores = { A = "100", B = "250" } }))
	equal(PVP.GAME.enemy.score_known, nil, "score_known")
end)

test("a non-team lobby is left untouched", function()
	setup({ starting_lives = 4 })
	PVP.LOBBY.roster = { keep = "A" }
	states["pvp.targets"] = targets("r1", { teamScores = { A = "1", B = "2" } })
	push("pvp.teams", teams("r1", { me = "B" }))
	equal(PVP.LOBBY.roster.keep, "A", "roster")
	equal(PVP.LOBBY.team_id, nil, "team_id")
	equal(#eased, 0, "score eases")
	equal(refreshed, 0, "refresh_target_lives calls")
end)

test("outside a PvP lobby, or with no lobby, nothing happens", function()
	setup()
	lobby.mod_id = "other"
	push("pvp.teams", teams("r1", { me = "B" }))
	equal(PVP.LOBBY.team_id, nil, "other mod")
	lobby = nil
	listeners["pvp.teams"](states["pvp.teams"])
	equal(PVP.LOBBY.team_id, nil, "no lobby")
	equal(refreshed, 0, "refresh_target_lives calls")
end)

test("a refused pick shows the server's roster again", function()
	setup()
	states["pvp.teams"] = teams(nil, { me = "A", they = "B" })
	dofile("pvp_api/actions/team_manhunt.lua")
	PVP.pvp_set_team("B")
	equal(requests[1].kind, "pvp.team", "request")
	equal(requests[1].payload.team, "B", "picked team")
	equal(PVP.LOBBY.team_id, "B", "the pick shows at once")
	equal(PVP.LOBBY.roster.me, "B", "roster shows the pick at once")
	requests[1].on_result(false, { reason = "runner_taken" })
	equal(PVP.LOBBY.team_id, "A", "the server's team")
	equal(PVP.LOBBY.roster.me, "A", "the server's roster")
	equal(PVP.LOBBY.roster.they, "B", "the others' picks")
end)

test("an accepted pick leaves the optimistic write alone", function()
	setup()
	states["pvp.teams"] = teams(nil, { me = "A" })
	dofile("pvp_api/actions/team_manhunt.lua")
	PVP.pvp_set_team("B")
	requests[1].on_result(true, {})
	equal(PVP.LOBBY.team_id, "B")
end)

test("card_target_id() follows the state with no refresh call", function()
	setup()
	equal(PVP.TeamsNet.card_target_id(), nil, "no state")
	states["pvp.targets"] = targets("r1", { cardTargets = { me = "they" } })
	equal(PVP.TeamsNet.card_target_id(), "they", "named")
	states["pvp.targets"] = targets("r1", { cardTargets = { they = "me" } })
	equal(PVP.TeamsNet.card_target_id(), nil, "a null target")
	states["pvp.targets"] = targets("r0", { cardTargets = { me = "they" } })
	equal(PVP.TeamsNet.card_target_id(), nil, "another run")
	lobby = nil
	equal(PVP.TeamsNet.card_target_id(), nil, "no lobby")
	equal(refreshed, 0, "refresh_target_lives calls")
	equal(#eased, 0, "score eases")
end)

test("a rebuilt PVP.GAME (rejoin, reconnect) still names the card target, with no new push", function()
	setup()
	states["pvp.targets"] = targets("r1", { cardTargets = { me = "they" } })
	PVP.GAME = { enemy = {} }
	equal(PVP.TeamsNet.card_target_id(), "they")
end)

if failed > 0 then os.exit(1) end
print(("teams_net_test: ok (%d rows)"):format(passed))
