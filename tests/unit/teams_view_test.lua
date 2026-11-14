-- Run from the repo root: luajit tests/unit/teams_view_test.lua
-- The pure view of the server's "pvp.teams" and "pvp.targets" state for the team modes: the
-- roster, one player's team, the enemy team's score and one player's Teams card target.
PVP = {}
dofile("lib/_state_value.lua")
dofile("lib/teams_view.lua")

local failed = 0

local function same_map(a, b)
	for key, value in pairs(a) do
		if b[key] ~= value then return false end
	end
	for key, value in pairs(b) do
		if a[key] ~= value then return false end
	end
	return true
end

local function report(name, ok, got, want)
	if ok then
		print("ok   " .. name)
	else
		failed = failed + 1
		print(("FAIL %s: got %s; wanted %s"):format(name, tostring(got), tostring(want)))
	end
end

-- A decoded pvp.teams value. MPAPI's JSON decoder drops a null, so a lobby value has no runId.
local function teams(run_id, map)
	return { runId = run_id, teams = map }
end

-- A decoded pvp.targets value. A null card target or null teamScores is a missing key.
local function targets(run_id, extra)
	local value = { runId = run_id, opponents = {}, cardTargets = {}, safe = {} }
	for key, entry in pairs(extra or {}) do
		value[key] = entry
	end
	return value
end

local PICKS = { me = "A", they = "B", third = "A" }

local roster_rows = {
	{ name = "lobby picks (no runId) are the roster before a run", value = teams(nil, PICKS), run = nil, want = PICKS },
	{
		name = "lobby picks are still the roster once a run id is known",
		value = teams(nil, PICKS),
		run = "r1",
		want = PICKS,
	},
	{ name = "the current run's roster", value = teams("r1", PICKS), run = "r1", want = PICKS },
	{ name = "a roster of another run is empty", value = teams("r0", PICKS), run = "r1", want = {} },
	{ name = "a roster of a run, with no current run, is empty", value = teams("r1", PICKS), run = nil, want = {} },
	{ name = "a run id of another type matches by its text", value = teams("7", PICKS), run = 7, want = PICKS },
	{ name = "no value is empty", value = nil, run = "r1", want = {} },
	{ name = "a value that is not a table is empty", value = "r1", run = "r1", want = {} },
	{ name = "a value without teams is empty", value = { runId = "r1" }, run = "r1", want = {} },
	{ name = "teams that is not a table is empty", value = { runId = "r1", teams = "A" }, run = "r1", want = {} },
	{ name = "an empty map is an empty roster", value = teams("r1", {}), run = "r1", want = {} },
	{
		name = "an entry that is not a non-empty string is left out",
		value = teams("r1", { me = "RUNNER", they = {}, third = 5, fourth = false, fifth = "" }),
		run = "r1",
		want = { me = "RUNNER" },
	},
	{
		name = "a Manhunt roster",
		value = teams("r1", { me = "HUNTER", they = "RUNNER" }),
		run = "r1",
		want = { me = "HUNTER", they = "RUNNER" },
	},
}

for _, row in ipairs(roster_rows) do
	local got = PVP.TeamsView.roster(row.value, row.run)
	report("roster: " .. row.name, same_map(got, row.want), got, row.want)
end

local SCORES = { A = "1000", B = "2500" }

local score_rows = {
	{
		name = "team A sees B's score",
		value = targets("r1", { teamScores = SCORES }),
		run = "r1",
		team = "A",
		want = "2500",
	},
	{
		name = "team B sees A's score",
		value = targets("r1", { teamScores = SCORES }),
		run = "r1",
		team = "B",
		want = "1000",
	},
	{
		name = "a Talisman string is returned as it is",
		value = targets("r1", { teamScores = { A = "1e400", B = "1e500" } }),
		run = "r1",
		team = "A",
		want = "1e500",
	},
	{
		name = "scores of another run are not shown",
		value = targets("r0", { teamScores = SCORES }),
		run = "r1",
		team = "A",
		want = nil,
	},
	{
		name = "no current run shows nothing",
		value = targets("r1", { teamScores = SCORES }),
		run = nil,
		team = "A",
		want = nil,
	},
	{ name = "no team scores (a null) shows nothing", value = targets("r1"), run = "r1", team = "A", want = nil },
	{
		name = "an unknown team shows nothing",
		value = targets("r1", { teamScores = SCORES }),
		run = "r1",
		team = "RUNNER",
		want = nil,
	},
	{
		name = "no team shows nothing",
		value = targets("r1", { teamScores = SCORES }),
		run = "r1",
		team = nil,
		want = nil,
	},
	{
		name = "a missing score for the enemy team shows nothing",
		value = targets("r1", { teamScores = { A = "1" } }),
		run = "r1",
		team = "A",
		want = nil,
	},
	{
		name = "a non-string score shows nothing",
		value = targets("r1", { teamScores = { A = 1, B = 2 } }),
		run = "r1",
		team = "A",
		want = nil,
	},
	{
		name = "an empty score shows nothing",
		value = targets("r1", { teamScores = { A = "", B = "" } }),
		run = "r1",
		team = "A",
		want = nil,
	},
	{
		name = "team scores that is not a table shows nothing",
		value = targets("r1", { teamScores = "x" }),
		run = "r1",
		team = "A",
		want = nil,
	},
	{ name = "no value shows nothing", value = nil, run = "r1", team = "A", want = nil },
	{ name = "a value that is not a table shows nothing", value = 4, run = "r1", team = "A", want = nil },
}

for _, row in ipairs(score_rows) do
	local got = PVP.TeamsView.enemy_score(row.value, row.run, row.team)
	report("enemy_score: " .. row.name, got == row.want, got, row.want)
end

local CARDS = { me = "they", they = "me" }

local card_rows = {
	{
		name = "the current run names the target",
		value = targets("r1", { cardTargets = CARDS }),
		run = "r1",
		player = "me",
		want = "they",
	},
	{
		name = "a target of another run is not used",
		value = targets("r0", { cardTargets = CARDS }),
		run = "r1",
		player = "me",
		want = nil,
	},
	{
		name = "no current run names nothing",
		value = targets("r1", { cardTargets = CARDS }),
		run = nil,
		player = "me",
		want = nil,
	},
	{
		name = "a null card target (missing key) is none",
		value = targets("r1", { cardTargets = { they = "me" } }),
		run = "r1",
		player = "me",
		want = nil,
	},
	{
		name = "a null sentinel entry is none",
		value = targets("r1", { cardTargets = { me = {} } }),
		run = "r1",
		player = "me",
		want = nil,
	},
	{
		name = "an empty string is none",
		value = targets("r1", { cardTargets = { me = "" } }),
		run = "r1",
		player = "me",
		want = nil,
	},
	{
		name = "a number entry is none",
		value = targets("r1", { cardTargets = { me = 5 } }),
		run = "r1",
		player = "me",
		want = nil,
	},
	{ name = "an empty map is none (outside Teams)", value = targets("r1"), run = "r1", player = "me", want = nil },
	{ name = "cardTargets missing is none", value = { runId = "r1" }, run = "r1", player = "me", want = nil },
	{
		name = "cardTargets that is not a table is none",
		value = { runId = "r1", cardTargets = "x" },
		run = "r1",
		player = "me",
		want = nil,
	},
	{ name = "no value is none", value = nil, run = "r1", player = "me", want = nil },
	{ name = "a value that is not a table is none", value = "r1", run = "r1", player = "me", want = nil },
}

for _, row in ipairs(card_rows) do
	local got = PVP.TeamsView.card_target(row.value, row.run, row.player)
	report("card_target: " .. row.name, got == row.want, got, row.want)
end

-- The server's Teams 2v2 midgame example: a1 and a2 are team A, b1 and b2 team B; each aims its cards at
-- a player of the other team; the team scores are Talisman strings.
do
	local midgame = dofile("tests/unit/net_fixture.lua")("state_pvp_midgame").changed
	local roster = PVP.TeamsView.roster(midgame["pvp.teams"], "r1")
	report(
		"midgame roster: four seats on two teams",
		same_map(roster, { a1 = "A", a2 = "A", b1 = "B", b2 = "B" }),
		roster,
		"a1,a2=A b1,b2=B"
	)
	for player, want in pairs({ a1 = "b2", a2 = "b1", b1 = "a2", b2 = "a2" }) do
		local got = PVP.TeamsView.card_target(midgame["pvp.targets"], "r1", player)
		report("midgame card_target of " .. player, got == want, got, want)
	end
	local a_sees = PVP.TeamsView.enemy_score(midgame["pvp.targets"], "r1", "A")
	report("midgame: team A sees B's 500", a_sees == "500", a_sees, "500")
	local b_sees = PVP.TeamsView.enemy_score(midgame["pvp.targets"], "r1", "B")
	report("midgame: team B sees A's 150", b_sees == "150", b_sees, "150")
end

if failed > 0 then os.exit(1) end
print("teams_view_test: ok")
