-- Run from the repo root: luajit tests/unit/round_end_view_test.lua
-- The pure rules of lib/round_end_view.lua.
PVP = {}
dofile("lib/_state_value.lua")
dofile("lib/round_end_view.lua")
local RoundEndView = PVP.RoundEndView

-- decide with the player in the PvP blind of the round the state resolved, unless a row says otherwise.
local function D(round, lives, me, run, applied, opts)
	opts = opts or {}
	local current = opts.current
	if current == nil then
		local last = type(round) == "table" and round.lastResult or nil
		current = { round_id = last and last.roundId or nil, in_pvp_blind = true }
	end
	return RoundEndView.decide({
		round_value = round,
		lives_value = lives,
		me = me,
		run_id = run,
		applied = applied,
		result_set = opts.result_set,
		eliminated = opts.eliminated,
		started_count = opts.started_count,
		teams = opts.teams,
		hands_left = opts.hands_left,
		current = current,
	})
end

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

local function round(roundId, losers, runId)
	return {
		runId = runId or "r1",
		roundId = roundId,
		phase = "resolved",
		lastResult = { roundId = roundId, losers = losers },
	}
end
local function lives(pending, runId)
	return { runId = runId or "r1", players = {}, pending = pending }
end
local IDLE_ROUND = { runId = nil, roundId = 0, lastResult = nil }
local IDLE_LIVES = { runId = nil, players = {}, pending = {} }

-- Outcomes 5-11: I lost round 1 -> one end_pvp, lost.
local cmds, applied = D(round(1, { "a" }), IDLE_LIVES, "a", "r1", nil)
check("5: a lost round gives one command", #cmds, 1)
check("5: it is end_pvp", cmds[1].kind, "end_pvp")
check("5: lost", cmds[1].lost, true)
check("5: round id", cmds[1].roundId, 1)
for _ = 1, 3 do
	cmds, applied = D(round(1, { "a" }), IDLE_LIVES, "a", "r1", applied)
end
check("5: the same STATE three times applies nothing more", #cmds, 0)
cmds = D(round(1, { "a" }), lives({}), "a", "r1", applied)
check("5: a SNAPSHOT replay applies nothing more", #cmds, 0)
cmds, applied = D(round(2, { "b" }), IDLE_LIVES, "a", "r1", applied)
check("5: the next round applies again", #cmds, 1)
check("5: next round is a win for me", cmds[1].lost, false)

cmds = D(round(1, { "b" }), IDLE_LIVES, "a", "r1", nil)
check("5: I won -> lost=false", cmds[1].lost, false)
cmds = D(round(1, {}), IDLE_LIVES, "a", "r1", nil)
check("5: nobody lost (a draw round) -> lost=false", cmds[1].lost, false)

check("idle round applies nothing", #D(IDLE_ROUND, IDLE_LIVES, "a", "r1", nil), 0)
check("nil values apply nothing", #D(nil, nil, "a", "r1", nil), 0)
check("no current run applies nothing", #D(round(1, { "a" }), IDLE_LIVES, "a", nil, nil), 0)
check("another run's round applies nothing", #D(round(1, { "a" }, "r0"), IDLE_LIVES, "a", "r1", nil), 0)
check("a number run id matches its string", #D(round(1, { "a" }, 7), IDLE_LIVES, "a", "7", nil), 1)

-- The input marks are never changed.
local before = RoundEndView.fresh()
D(round(1, { "a" }), IDLE_LIVES, "a", "r1", before)
check("decide leaves the given marks alone", next(before.rounds), nil)

-- Marks carry their run; marks of another run are dropped, so its round numbers mean nothing here.
cmds, applied = D(round(1, { "a" }), IDLE_LIVES, "a", "r1", nil)
check("the returned marks carry the run", applied.run_id, "r1")
cmds = D(round(1, { "a" }), IDLE_LIVES, "a", "r1", { run_id = "r0", rounds = { [1] = true }, pending = {} })
check("marks of another run are dropped: the round applies again", #cmds, 1)
cmds, applied = D(round(1, { "a" }), IDLE_LIVES, "a", "r1", { run_id = "r0", rounds = { [9] = true }, pending = {} })
check("marks of another run are dropped: none carried over", applied.rounds[9], nil)
cmds = D(round(1, { "a" }), IDLE_LIVES, "a", "r1", { run_id = "r1", rounds = { [1] = true }, pending = {} })
check("marks of this run are kept", #cmds, 0)

-- Outcomes 65-98: pending deaths.
local mine = { playerId = "a", blindKey = "2:Big", waitsOn = { "b" } }
cmds, applied = D(IDLE_ROUND, lives({ mine }), "a", "r1", nil)
check("65: my pending entry gives death_pending", cmds[1].kind, "death_pending")
check("65: player id", cmds[1].player_id, "a")
check("65: opponent id is waitsOn[1]", cmds[1].opponent_id, "b")
check("65: blind key", cmds[1].blind_key, "2:Big")
cmds, applied = D(IDLE_ROUND, lives({ mine }), "a", "r1", applied)
check("65: the same entry again applies nothing", #cmds, 0)
cmds, applied = D(IDLE_ROUND, lives({}), "a", "r1", applied)
check("98: my entry removed -> end_pending_death", cmds[1].kind, "end_pending_death")
check("98: only that one command", #cmds, 1)
cmds = D(IDLE_ROUND, lives({}), "a", "r1", applied)
check("98: end_pending_death only once", #cmds, 0)

cmds, applied = D(IDLE_ROUND, lives({ mine }), "a", "r1", nil)
cmds = D(IDLE_ROUND, lives({}), "a", "r1", applied, { result_set = true })
check("result set: the result ends the screen, not this", #cmds, 0)

-- A server run-out death has no blind: blindKey is null (nil here). It applies once, with no blind named.
local runout = { playerId = "a", blindKey = nil, waitsOn = { "b" } }
cmds, applied = D(IDLE_ROUND, lives({ runout }), "a", "r1", nil)
check("null blindKey: gives death_pending", cmds[1].kind, "death_pending")
check("null blindKey: no blind is named", cmds[1].blind_key, nil)
check("null blindKey: the opponent is still waitsOn[1]", cmds[1].opponent_id, "b")
cmds, applied = D(IDLE_ROUND, lives({ runout }), "a", "r1", applied)
check("null blindKey: the same entry again applies nothing", #cmds, 0)

local theirs = { playerId = "b", blindKey = "2:Big", waitsOn = { "a" } }
cmds, applied = D(IDLE_ROUND, lives({ theirs }), "a", "r1", nil)
check("85: opponent's entry gives death_pending", cmds[1].kind, "death_pending")
check("85: my id is the one it waits on", cmds[1].opponent_id, "a")
check("85: player is the opponent", cmds[1].player_id, "b")
cmds = D(IDLE_ROUND, lives({}), "a", "r1", applied)
check("85: the opponent's entry going does not end my screen", #cmds, 0)

cmds = D(IDLE_ROUND, lives({ { playerId = "b", blindKey = "2:Big", waitsOn = {} } }), "a", "r1", nil)
check("80: no waitsOn gives a nil opponent", cmds[1].opponent_id, nil)
cmds = D(IDLE_ROUND, lives({ { playerId = "b", blindKey = "2:Big", waitsOn = { "a", "c" } } }), "a", "r1", nil)
check("80: several waitsOn gives a nil opponent", cmds[1].opponent_id, nil)
cmds = D(IDLE_ROUND, lives({ mine }, "r0"), "a", "r1", nil)
check("another run's pending applies nothing", #cmds, 0)

-- F9: the opponent is named only when the game started with exactly 2 players.
cmds = D(IDLE_ROUND, lives({ mine }), "a", "r1", nil, { started_count = 3 })
check("F9: 3 started, wait list of 1: many-player branch (no opponent)", cmds[1].opponent_id, nil)
check("F9: 3 started: still my death_pending", cmds[1].kind, "death_pending")
cmds = D(IDLE_ROUND, lives({ theirs }), "a", "r1", nil, { started_count = 8 })
check("F9: 8 started, wait list of 1 (theirs): no opponent", cmds[1].opponent_id, nil)
cmds = D(IDLE_ROUND, lives({ mine }), "a", "r1", nil, { started_count = 2 })
check("F9: 2 started: the opponent id as before", cmds[1].opponent_id, "b")
check("F9: 2 started, wait list of 2: no opponent", RoundEndView.opponent_of({ "b", "c" }, 2), nil)
check("F9: opponent_of with no wait list", RoundEndView.opponent_of(nil, 2), nil)
check(
	"F9: opponent_of with an unknown count falls back to the list length",
	RoundEndView.opponent_of({ "b" }, nil),
	"b"
)

local other = { playerId = "a", blindKey = "3:Small", waitsOn = { "b" } }
cmds, applied = D(IDLE_ROUND, lives({ mine }), "a", "r1", nil)
cmds, applied = D(IDLE_ROUND, lives({ other }), "a", "r1", applied)
check("a new blind's entry applies again", cmds[1].kind, "death_pending")

-- The resolve itself: the player is in the blind of the round that resolved; it applies.
cmds = D(
	{ runId = "r1", roundId = 1, phase = "resolved", lastResult = { roundId = 1, losers = { "a" } } },
	IDLE_LIVES,
	"a",
	"r1",
	nil
)
check("resolve, in the PvP blind of that round: applies", #cmds, 1)

-- end_pvp runs only for the round the player is in, and only inside its PvP blind.
local resolved = { runId = "r1", roundId = 1, phase = "resolved", lastResult = { roundId = 1, losers = { "a" } } }
-- decide with exactly the given `current` (nil = none known).
local function decide_with(round, lives_value, me, run, applied, current)
	return RoundEndView.decide({
		round_value = round,
		lives_value = lives_value,
		me = me,
		run_id = run,
		applied = applied,
		current = current,
	})
end
cmds, applied = decide_with(resolved, IDLE_LIVES, "a", "r1", nil, { round_id = 1, in_pvp_blind = false })
check("in the shop after round 1: no end_pvp", #cmds, 0)
check("in the shop after round 1: the round is marked", applied.rounds[1], true)
cmds = decide_with(resolved, IDLE_LIVES, "a", "r1", applied, { round_id = 1, in_pvp_blind = true })
check("a marked round does not apply when the player later enters a blind", #cmds, 0)
cmds, applied = decide_with(resolved, IDLE_LIVES, "a", "r1", nil, { round_id = 2, in_pvp_blind = true })
check("in blind 2 (a later round): round 1 only marks", #cmds, 0)
check("in blind 2: round 1 is marked", applied.rounds[1], true)
cmds = decide_with(resolved, IDLE_LIVES, "a", "r1", nil, { round_id = nil, in_pvp_blind = true })
check("no round id yet: no end_pvp", #cmds, 0)
cmds = decide_with(resolved, IDLE_LIVES, "a", "r1", nil, nil)
check("no current given: no end_pvp", #cmds, 0)
cmds = decide_with(resolved, IDLE_LIVES, "a", "r1", nil, { round_id = 1, in_pvp_blind = true })
check("in blind 1 when round 1 resolves: applies", #cmds, 1)
-- The playing phase (the server's next round open) needs no rule of its own: such a client is
-- in a later round or the shop, so the round id check marks it.
local open = { runId = "r1", roundId = 2, phase = "playing", lastResult = { roundId = 1, losers = { "a" } } }
cmds, applied = decide_with(open, IDLE_LIVES, "a", "r1", nil, { round_id = 2, in_pvp_blind = true })
check("server round open, player in blind 2: round 1 only marks", #cmds, 0)
check("server round open: the round is marked", applied.rounds[1], true)

-- Team pending death (Manhunt, Teams): opts.teams names each player's team.
local function T(lives_value, me, applied, teams)
	return D(IDLE_ROUND, lives_value, me, "r1", applied, { teams = teams })
end
local MANHUNT_TEAMS = { r = "RUNNER", h1 = "HUNTER", h2 = "HUNTER" }
local runner_dead = { playerId = "r", blindKey = "2:Big", waitsOn = { "h1", "h2" } }
cmds = T(lives({ runner_dead }), "r", nil, MANHUNT_TEAMS)
check("team: the Runner's command carries team_id RUNNER", cmds[1].team_id, "RUNNER")
check("team: it still names the player who died", cmds[1].player_id, "r")
cmds, applied = T(lives({ runner_dead }), "r", nil, MANHUNT_TEAMS)
cmds = T(lives({}), "r", applied, MANHUNT_TEAMS)
check("team: the entry going ends the Runner's own pending screen", cmds[1].kind, "end_pending_death")
cmds, applied = T(lives({ runner_dead }), "h1", nil, MANHUNT_TEAMS)
check("team: a Hunter sees the same command, with team_id RUNNER", cmds[1].team_id, "RUNNER")
cmds = T(lives({}), "h1", applied, MANHUNT_TEAMS)
check("team: the Runner's entry going is not a Hunter's own: nothing ends", #cmds, 0)

local teammate_dead = { playerId = "a2", blindKey = "2:Big", waitsOn = { "b1", "b2" } }
local TEAMS = { a1 = "A", a2 = "A", b1 = "B", b2 = "B" }
cmds, applied = T(lives({ teammate_dead }), "a1", nil, TEAMS)
check("teams: a teammate's death gives me the pending command", cmds[1].kind, "death_pending")
check("teams: it carries my team's id", cmds[1].team_id, "A")
check("teams: it names the teammate who died", cmds[1].player_id, "a2")
cmds = T(lives({}), "a1", applied, TEAMS)
check("teams: the entry leaving ends my pending screen too", cmds[1].kind, "end_pending_death")
cmds, applied = T(lives({ teammate_dead }), "b1", nil, TEAMS)
check("teams: the other team gets the command with the dead team's id", cmds[1].team_id, "A")
cmds = T(lives({}), "b1", applied, TEAMS)
check("teams: the other team has no screen to end", #cmds, 0)
cmds = T(lives({ teammate_dead }), "a1", nil, { a2 = "A" })
check("teams: a map naming only the dead player still gives team_id", cmds[1].team_id, "A")
cmds, applied = T(lives({ teammate_dead }), "a1", nil, { a2 = "A" })
cmds = T(lives({}), "a1", applied, { a2 = "A" })
check("teams: I am not on the team when the map leaves me out: nothing ends", #cmds, 0)

-- No team map: exactly the old rows.
cmds, applied = T(lives({ mine }), "a", nil, nil)
check("no team map: no team_id", cmds[1].team_id, nil)
cmds = T(lives({}), "a", applied, nil)
check("no team map: my entry going still ends it", cmds[1].kind, "end_pending_death")
cmds, applied = T(lives({ theirs }), "a", nil, nil)
cmds = T(lives({}), "a", applied, nil)
check("no team map: another player's entry is not mine", #cmds, 0)
cmds = T(lives({ mine }), "a", nil, {})
check("an empty team map: no team_id", cmds[1].team_id, nil)

-- An eliminated player's run is over: the rounds the others play on are marked, never run.
cmds, applied = D(round(1, { "a" }), IDLE_LIVES, "a", "r1", nil, { eliminated = true })
check("eliminated: no end_pvp", #cmds, 0)
check("eliminated: the round is still marked", applied.rounds[1], true)
cmds = D(round(1, { "a" }), IDLE_LIVES, "a", "r1", nil, { eliminated = false })
check("not eliminated: end_pvp as before", #cmds, 1)
cmds = D(round(1, { "a" }), lives({ mine }), "a", "r1", nil, { eliminated = true })
check("eliminated: a pending death still applies", cmds[1].kind, "death_pending")

-- The team map of the current run.
local TEAMS_VALUE = { runId = "r1", teams = { a = "A", b = "B" } }
check("team_map: the map of the current run", RoundEndView.team_map(TEAMS_VALUE, "r1").a, "A")
check(
	"team_map: a number run id matches its string",
	RoundEndView.team_map({ runId = 7, teams = {} }, "7") ~= nil,
	true
)
check("team_map: another run's map is none", RoundEndView.team_map(TEAMS_VALUE, "r2"), nil)
check("team_map: an idle value is none", RoundEndView.team_map({ runId = nil, teams = {} }, "r1"), nil)
check("team_map: no value is none", RoundEndView.team_map(nil, "r1"), nil)
check("team_map: no current run is none", RoundEndView.team_map(TEAMS_VALUE, nil), nil)

-- Round end and pending in one STATE: round first.
cmds = D(round(1, { "a" }), lives({ mine }), "a", "r1", nil)
check("both in one go: round end first", cmds[1].kind, "end_pvp")
check("both in one go: then the pending death", cmds[2].kind, "death_pending")

-- The server's Teams 2v2 examples: round 1 resolved with team A (a1, a2) the losers, no pending death.
do
	local midgame = dofile("tests/unit/net_fixture.lua")("state_pvp_midgame").changed
	cmds, applied = D(midgame["pvp.round"], midgame["pvp.lives"], "a1", "r1", nil)
	check("midgame: a loser gets one command", #cmds, 1)
	check("midgame: it is end_pvp", cmds[1].kind, "end_pvp")
	check("midgame: a1 lost", cmds[1].lost, true)
	check("midgame: round id", cmds[1].roundId, 1)
	check("midgame: round 1 is marked", applied.rounds[1], true)
	cmds = D(midgame["pvp.round"], midgame["pvp.lives"], "a2", "r1", nil)
	check("midgame: a2 lost too", cmds[1].lost, true)
	cmds = D(midgame["pvp.round"], midgame["pvp.lives"], "b1", "r1", nil)
	check("midgame: b1 won", cmds[1].lost, false)
	cmds = D(midgame["pvp.round"], midgame["pvp.lives"], "b2", "r1", nil)
	check("midgame: b2 won", cmds[1].lost, false)
	cmds = D(midgame["pvp.round"], midgame["pvp.lives"], "b2", "r2", nil)
	check("midgame: another run applies nothing", #cmds, 0)
end

-- Property: replaying any state sequence gives the same list as playing it once,
-- and a reorder gives the same commands (as a set).
local function render(list)
	local out = {}
	for _, c in ipairs(list) do
		out[#out + 1] = table.concat(
			{ c.kind, tostring(c.roundId), tostring(c.lost), tostring(c.player_id), tostring(c.blind_key) },
			","
		)
	end
	return out
end
local function run_all(seq)
	local all, marks = {}, nil
	for _, s in ipairs(seq) do
		local c
		c, marks = D(s.round, s.lives, "a", "r1", marks)
		for _, one in ipairs(render(c)) do
			all[#all + 1] = one
		end
	end
	return all
end
local function sorted(list)
	table.sort(list)
	return table.concat(list, ";")
end

local seed = 12345
local function rand(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n + 1
end
-- States: run r1 or r0, roundId 1..4, random losers, a pending entry present or absent.
-- r0 is never the current run, and only r0 ever names me ("a") as a loser or pending
-- player's blind "r0key", so any such command is a leak from the other run.
local states = {}
for _, run_id in ipairs({ "r1", "r0" }) do
	for i = 1, 4 do
		for _, losers in ipairs({ { "b" }, {}, { "b", "c" } }) do
			for _, with_pending in ipairs({ false, true }) do
				local who = run_id == "r0" and { "a" } or losers
				local entry = { playerId = "b", blindKey = run_id == "r0" and "r0key" or "2:Big", waitsOn = { "a" } }
				states[#states + 1] = {
					round = round(i, who, run_id),
					lives = lives(with_pending and { entry } or {}, run_id),
				}
			end
		end
	end
end
local ok_replay, ok_reorder, ok_once, ok_leak = true, true, true, true
for _ = 1, 300 do
	local seq = {}
	for _ = 1, rand(12) do
		seq[#seq + 1] = states[rand(#states)]
	end
	local seen = {}
	for _, line in ipairs(run_all(seq)) do
		local round_id = line:match("^end_pvp,(%d+),")
		if round_id then
			if seen[round_id] then ok_once = false end
			seen[round_id] = true
		end
		if line:find("^end_pvp,%d+,true") or line:find("r0key") then ok_leak = false end
	end
	local replayed = {}
	for _, s in ipairs(seq) do
		replayed[#replayed + 1] = s
		replayed[#replayed + 1] = s
		replayed[#replayed + 1] = s
	end
	if table.concat(run_all(seq), ";") ~= table.concat(run_all(replayed), ";") then ok_replay = false end
	local shuffled = {}
	for _, s in ipairs(seq) do
		table.insert(shuffled, rand(#shuffled + 1), s)
	end
	-- The first state naming a round decides its `lost`, so a reorder may change that
	-- value, never which rounds and pending entries apply, nor how often.
	local function only_apply(list)
		local out = {}
		for _, line in ipairs(list) do
			if line:find("^end_pvp") then
				out[#out + 1] = line:match("^end_pvp,%d+")
			elseif line:find("^death_pending") then
				out[#out + 1] = line
			end
		end
		return sorted(out)
	end
	if only_apply(run_all(seq)) ~= only_apply(run_all(shuffled)) then ok_reorder = false end
end
check("property: a repeated STATE sequence gives the same commands", ok_replay, true)
check("property: a reordered STATE sequence applies the same rounds and entries", ok_reorder, true)
check("property: at most one end_pvp per round id", ok_once, true)
check("property: no command comes from another run", ok_leak, true)

-- hands_spent: the server spent my hands while the round is still open.
local function open_round(roundId, players, runId)
	return { runId = runId or "r1", roundId = roundId, phase = "playing", players = players }
end
local SPENT = { a = { handsLeft = 0, handsSpent = true }, b = { handsLeft = 2 } }
local IN_ROUND_1 = { round_id = 1, in_pvp_blind = true }

cmds, applied = D(open_round(1, SPENT), IDLE_LIVES, "a", "r1", nil, { current = IN_ROUND_1, hands_left = 2 })
check("spent: one hands_spent command", #cmds, 1)
check("spent: it is hands_spent", cmds[1].kind, "hands_spent")
check("spent: round id", cmds[1].roundId, 1)
check("spent: marked per round", applied.spent, 1)
cmds, applied = D(open_round(1, SPENT), IDLE_LIVES, "a", "r1", applied, { current = IN_ROUND_1, hands_left = 2 })
check("spent: a re-push of the same state is a no-op", #cmds, 0)
cmds = D(
	open_round(1, SPENT),
	IDLE_LIVES,
	"a",
	"r1",
	{ run_id = "r1", rounds = {}, pending = {}, spent = 1 },
	{ current = IN_ROUND_1, hands_left = 2 }
)
check("spent: a reload with the mark set does nothing", #cmds, 0)
cmds, applied = D(
	open_round(2, SPENT),
	IDLE_LIVES,
	"a",
	"r1",
	applied,
	{ current = { round_id = 2, in_pvp_blind = true }, hands_left = 2 }
)
check("spent: the next round applies again", #cmds, 1)

cmds = D(
	open_round(1, { a = { handsLeft = 0 }, b = { handsSpent = true } }),
	IDLE_LIVES,
	"a",
	"r1",
	nil,
	{ current = IN_ROUND_1, hands_left = 2 }
)
check("spent: only my own entry counts", #cmds, 0)
-- The server's real shape: the run-out sets handsSpent and leaves handsLeft as it was reported.
cmds = D(
	open_round(1, { a = { handsLeft = 2, handsSpent = true, timerLosses = 0, canTime = false }, b = { handsLeft = 2 } }),
	IDLE_LIVES,
	"a",
	"r1",
	nil,
	{ current = IN_ROUND_1, hands_left = 2 }
)
check("spent: the server's real flag, with its handsLeft left as reported, runs the path", #cmds, 1)
cmds = D(open_round(1, SPENT), IDLE_LIVES, "a", "r1", nil, { current = IN_ROUND_1, hands_left = 0 })
check("spent: not when my hands are already 0", #cmds, 0)
cmds = D(open_round(1, SPENT), IDLE_LIVES, "a", "r1", nil, { current = IN_ROUND_1 })
check("spent: not when my hands are unknown", #cmds, 0)
cmds = D(open_round(1, SPENT), IDLE_LIVES, "a", "r1", nil, { current = IN_ROUND_1, hands_left = 2, eliminated = true })
check("spent: not when eliminated", #cmds, 0)
cmds = D(
	open_round(1, SPENT),
	IDLE_LIVES,
	"a",
	"r1",
	nil,
	{ current = { round_id = 1, in_pvp_blind = false }, hands_left = 2 }
)
check("spent: not outside the PvP blind", #cmds, 0)
cmds = D(
	open_round(1, SPENT),
	IDLE_LIVES,
	"a",
	"r1",
	nil,
	{ current = { round_id = 2, in_pvp_blind = true }, hands_left = 2 }
)
check("spent: not for a round that is not mine", #cmds, 0)
cmds = D(open_round(1, SPENT), IDLE_LIVES, "a", "r1", nil, { current = IN_ROUND_1, hands_left = 2, result_set = true })
check("spent: a pending-death result does not stop it", #cmds, 1)
cmds = D(open_round(1, SPENT, "r0"), IDLE_LIVES, "a", "r1", nil, { current = IN_ROUND_1, hands_left = 2 })
check("spent: not from another run's state", #cmds, 0)
cmds = D(
	open_round(1, { a = { handsSpent = "yes" } }),
	IDLE_LIVES,
	"a",
	"r1",
	nil,
	{ current = IN_ROUND_1, hands_left = 2 }
)
check("spent: only a true flag counts", #cmds, 0)
cmds = D(
	{ runId = "r1", roundId = 1, phase = "playing" },
	IDLE_LIVES,
	"a",
	"r1",
	nil,
	{ current = IN_ROUND_1, hands_left = 2 }
)
check("spent: a state with no players is not an error", #cmds, 0)

-- One STATE carrying both the flag and the result (a duel): hands_spent first, then end_pvp.
local both = round(1, { "a" })
both.players = SPENT
cmds, applied = D(both, IDLE_LIVES, "a", "r1", nil, { current = IN_ROUND_1, hands_left = 2 })
check("spent + result: two commands", #cmds, 2)
check("spent + result: hands_spent comes first", cmds[1].kind, "hands_spent")
check("spent + result: end_pvp comes second", cmds[2].kind, "end_pvp")
check("spent + result: both are marked", applied.spent == 1 and applied.rounds[1], true)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
