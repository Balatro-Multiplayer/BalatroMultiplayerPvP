-- Run from the repo root: luajit tests/unit/enemy_score_net_test.lua
-- The shell around lib/enemy_score_view.lua with a stubbed MPAPI and PVP: the enemy score shows
-- only once a push of this round carries it, and score_known says so.
local states, listeners, lobby, eased, target, logs

local passed, failed = 0, 0
local function check(name, got, want)
	if got == want then
		passed = passed + 1
		print("ok   " .. name)
	else
		failed = failed + 1
		print(("FAIL %s: got %s, wanted %s"):format(name, tostring(got), tostring(want)))
	end
end

local function setup(config)
	states, listeners, eased, target, logs = {}, {}, {}, "they", {}
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
	}
	PVP = {
		id = "pvp",
		GAME = {
			round_id = 3,
			enemy = { score = "0", real_score = "0", highest_score = nil, score_known = false },
		},
		LOBBY = { config = config or {} },
		match_log = function(level, text)
			logs[#logs + 1] = level .. " " .. text
		end,
		Score = {
			parse = function(text)
				return type(text) == "string" and text:match("^%d+$") or nil
			end,
			greater = function(a, b)
				return tonumber(a) > tonumber(b)
			end,
		},
		UI = {
			ease_enemy_score = function(score)
				eased[#eased + 1] = score
			end,
		},
		current_target_id = function()
			return target
		end,
	}
	dofile("lib/_state_value.lua")
	dofile("lib/enemy_score_view.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/enemy_score_net.lua")
end

local function round(players, round_id, run_id)
	return { runId = run_id or "r1", roundId = round_id or 3, phase = "playing", players = players }
end

local MASKED = round({ me = { handsLeft = 3 }, they = { handsLeft = 2 } })

local function push(key, value)
	states[key] = value
	listeners[key](value)
end

setup()
check("subscribes to pvp.round", type(listeners["pvp.round"]), "function")
check("subscribes to pvp.targets", type(listeners["pvp.targets"]), "function")

setup()
push("pvp.round", MASKED)
check("a masked push leaves score_known false", PVP.GAME.enemy.score_known, false)
check("a masked push leaves the score 0", PVP.GAME.enemy.score, "0")
check("a masked push eases nothing", #eased, 0)

setup()
push("pvp.round", round({ they = { score = "1200", highestScore = "5000" } }))
check("an unmasked push for my round sets score_known", PVP.GAME.enemy.score_known, true)
check("it eases to the score", eased[1], "1200")
check("it sets real_score", PVP.GAME.enemy.real_score, "1200")
check("it sets the highest score", PVP.GAME.enemy.highest_score, "5000")

setup()
push("pvp.round", round({ they = { score = "300" } }))
check("a score with no highestScore still shows the score", PVP.GAME.enemy.real_score, "300")
check("a score with no highestScore leaves the highest unset", PVP.GAME.enemy.highest_score, nil)
check("a score with no highestScore is logged as an error", #logs == 1 and logs[1]:find("error", 1, true) ~= nil, true)
push("pvp.round", round({ they = { score = "100", highestScore = "300" } }))
check("a highestScore is assigned when none is known yet", PVP.GAME.enemy.highest_score, "300")
push("pvp.round", round({ they = { score = "100", highestScore = "200" } }))
check("a lower highestScore never lowers the highest", PVP.GAME.enemy.highest_score, "300")

setup()
push("pvp.round", round({ they = { score = "1200" } }, 2))
check("a push for an old round is ignored (known)", PVP.GAME.enemy.score_known, false)
check("a push for an old round is ignored (eased)", #eased, 0)
push("pvp.round", round({ they = { score = "1200" } }, 3, "r0"))
check("a push of another run is ignored", PVP.GAME.enemy.score_known, false)

setup({ team_based = true })
push("pvp.round", round({ they = { score = "1200" } }))
check("a team lobby is skipped (known)", PVP.GAME.enemy.score_known, false)
check("a team lobby is skipped (eased)", #eased, 0)

setup()
lobby.mod_id = "other"
push("pvp.round", round({ they = { score = "1200" } }))
check("another mod's lobby is skipped", PVP.GAME.enemy.score_known, false)

setup()
push("pvp.round", round({ other = { score = "9" } }))
check("a score for someone else is not mine to show", PVP.GAME.enemy.score_known, false)
target = nil
push("pvp.round", round({ they = { score = "9" } }))
check("no opponent yet shows nothing", PVP.GAME.enemy.score_known, false)

setup()
push("pvp.round", round({ they = { score = "1200" } }))
push("pvp.round", round({ they = { score = "1200" } }))
check("the same score again does not ease again", #eased, 1)
push("pvp.round", round({ they = { score = "1500" } }))
check("a new score eases again", #eased, 2)
check("a new score is the last eased", eased[2], "1500")

setup()
states["pvp.round"] = round({ a = { score = "10" }, b = { score = "20" } })
target = "a"
PVP.EnemyScoreNet.on_connected()
check("on_connected reads the state again", eased[1], "10")
target = "b"
push("pvp.targets", { runId = "r1" })
check("a pvp.targets push re-reads for the new opponent", eased[2], "20")

setup()
PVP.GAME = nil
push("pvp.round", round({ they = { score = "1" } }))
check("no PVP.GAME (not loaded yet) is not an error", #eased, 0)

setup()
push("pvp.round", { runId = "r1", roundId = 3 })
push("pvp.round", "garbage")
check("a value with no players, or not a table, is not an error", PVP.GAME.enemy.score_known, false)

-- The opponent's hands come from the state (a rejoiner's replay tail has no args), masked or not.
setup()
PVP.GAME.enemy.hands = 4
push("pvp.round", MASKED)
check("a masked push still sets the opponent's hands", PVP.GAME.enemy.hands, 2)
check("hands do not reveal the score", PVP.GAME.enemy.score_known, false)
push("pvp.round", round({ they = {} }))
check("no handsLeft (not reported yet) makes the hands unknown, not kept", PVP.GAME.enemy.hands, nil)
push("pvp.round", MASKED)
check("the hands come back with the server's handsLeft", PVP.GAME.enemy.hands, 2)
push("pvp.round", round({ they = { handsLeft = 1 } }, 2))
check("an old round's hands are ignored", PVP.GAME.enemy.hands, 2)

setup()
PVP.GAME.enemy.hands = 4
states["pvp.round"] = MASKED
PVP.EnemyScoreNet.on_connected()
check("on_connected sets the hands (rejoin)", PVP.GAME.enemy.hands, 2)

setup({ team_based = true })
PVP.GAME.enemy.hands = 4
push("pvp.round", MASKED)
check("a team lobby's hands are left alone", PVP.GAME.enemy.hands, 4)

-- Teams rejoin: TeamsNet reads before ReadyNet restores the round id, so it is read again here.
setup({ team_based = true })
local team_reads = {}
PVP.TeamsNet = {
	refresh = function()
		team_reads[#team_reads + 1] = PVP.GAME.round_id
	end,
}
PVP.GAME.round_id = nil
PVP.GAME.round_id = 3
PVP.EnemyScoreNet.on_connected()
check("a team lobby reads TeamsNet again on CONNECTED", #team_reads, 1)
check("it reads after the round id is restored", team_reads[1], 3)
setup()
PVP.TeamsNet = {
	refresh = function()
		error("not a team lobby")
	end,
}
check("a non-team lobby does not read TeamsNet", pcall(PVP.EnemyScoreNet.on_connected), true)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
