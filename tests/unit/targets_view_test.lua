-- Run from the repo root: luajit tests/unit/targets_view_test.lua
-- The pure view of the server's "pvp.targets" state: whether it is of the current run, and
-- the opponent it names for one player.
PVP = {}
dofile("lib/_state_value.lua")
dofile("lib/targets_view.lua")

local failed = 0

-- A decoded state value. MPAPI's JSON decoder drops a null, so a bye is a missing key.
local function targets(run_id, opponents)
	return { runId = run_id, opponents = opponents, cardTargets = {}, teamScores = nil }
end

local rows = {
	{
		name = "the current run names the opponent",
		value = targets("r1", { me = "they", they = "me" }),
		run = "r1",
		known = true,
		opponent = "they",
	},
	{
		name = "a state of another run is not known",
		value = targets("r0", { me = "they", they = "me" }),
		run = "r1",
		known = false,
		opponent = nil,
	},
	{ name = "no value is not known", value = nil, run = "r1", known = false, opponent = nil },
	{ name = "a value that is not a table is not known", value = "r1", run = "r1", known = false, opponent = nil },
	{
		name = "the idle value (no run) is not known",
		value = targets(nil, {}),
		run = "r1",
		known = false,
		opponent = nil,
	},
	{
		name = "no current run is not known, even for an idle state",
		value = targets(nil, {}),
		run = nil,
		known = false,
		opponent = nil,
	},
	{
		name = "no current run is not known for a state of a run",
		value = targets("r1", { me = "they" }),
		run = nil,
		known = false,
		opponent = nil,
	},
	{
		name = "a run id of another type still matches by its text",
		value = targets("7", { me = "they" }),
		run = 7,
		known = true,
		opponent = "they",
	},
	{
		name = "no entry for this player is a known bye",
		value = targets("r1", { they = "other" }),
		run = "r1",
		known = true,
		opponent = nil,
	},
	{
		name = "an empty map pairs nobody, so it is not known (not a bye for everyone)",
		value = targets("r1", {}),
		run = "r1",
		known = false,
		opponent = nil,
	},
	{
		name = "a null sentinel entry is a known bye",
		value = targets("r1", { me = {} }),
		run = "r1",
		known = true,
		opponent = nil,
	},
	{
		name = "a false entry is a known bye",
		value = targets("r1", { me = false }),
		run = "r1",
		known = true,
		opponent = nil,
	},
	{
		name = "an empty string is a known bye",
		value = targets("r1", { me = "" }),
		run = "r1",
		known = true,
		opponent = nil,
	},
	{
		name = "a number entry is a known bye",
		value = targets("r1", { me = 5 }),
		run = "r1",
		known = true,
		opponent = nil,
	},
	{
		name = "opponents missing is not known",
		value = { runId = "r1" },
		run = "r1",
		known = false,
		opponent = nil,
	},
	{
		name = "opponents that is not a table is not known",
		value = { runId = "r1", opponents = "x" },
		run = "r1",
		known = false,
		opponent = nil,
	},
}

for _, row in ipairs(rows) do
	local known, opponent = PVP.TargetsView.opponent(row.value, row.run, "me")
	if known == row.known and opponent == row.opponent then
		print("ok   " .. row.name)
	else
		failed = failed + 1
		print(
			("FAIL %s: got %s, %s; wanted %s, %s"):format(
				row.name,
				tostring(known),
				tostring(opponent),
				tostring(row.known),
				tostring(row.opponent)
			)
		)
	end
end

-- The Royale safe marker and the Nemesis pairing ante ride on the same state value.
local function state(run_id, extra)
	local value = targets(run_id, { me = "they" })
	for key, entry in pairs(extra) do
		value[key] = entry
	end
	return value
end

local safe_rows = {
	{
		name = "safe: a true entry",
		value = state("r1", { safe = { me = true } }),
		run = "r1",
		known = true,
		safe = true,
	},
	{
		name = "safe: a false entry is known and not safe",
		value = state("r1", { safe = { me = false } }),
		run = "r1",
		known = true,
		safe = false,
	},
	{
		name = "safe: the state of another run is not known",
		value = state("r0", { safe = { me = true } }),
		run = "r1",
		known = false,
		safe = false,
	},
	{
		name = "safe: no current run is not known",
		value = state("r1", { safe = { me = true } }),
		run = nil,
		known = false,
		safe = false,
	},
	{
		name = "safe: a missing entry is not known",
		value = state("r1", { safe = { they = true } }),
		run = "r1",
		known = false,
		safe = false,
	},
	{
		name = "safe: the empty map outside Royale is not known",
		value = state("r1", { safe = {} }),
		run = "r1",
		known = false,
		safe = false,
	},
	{ name = "safe: a missing map is not known", value = state("r1", {}), run = "r1", known = false, safe = false },
	{ name = "safe: no value is not known", value = nil, run = "r1", known = false, safe = false },
	{
		name = "safe: a non-boolean entry is not known",
		value = state("r1", { safe = { me = 1 } }),
		run = "r1",
		known = false,
		safe = false,
	},
}

for _, row in ipairs(safe_rows) do
	local known, safe = PVP.TargetsView.safe(row.value, row.run, "me")
	if known == row.known and safe == row.safe then
		print("ok   " .. row.name)
	else
		failed = failed + 1
		print(
			("FAIL %s: got %s, %s; wanted %s, %s"):format(
				row.name,
				tostring(known),
				tostring(safe),
				tostring(row.known),
				tostring(row.safe)
			)
		)
	end
end

local ante_rows = {
	{ name = "pairing_ante: the current run's ante", value = state("r1", { pairingAnte = 3 }), run = "r1", ante = 3 },
	{ name = "pairing_ante: another run's is nil", value = state("r0", { pairingAnte = 3 }), run = "r1", ante = nil },
	{ name = "pairing_ante: no current run is nil", value = state("r1", { pairingAnte = 3 }), run = nil, ante = nil },
	{ name = "pairing_ante: a null (missing key) is nil", value = state("r1", {}), run = "r1", ante = nil },
	{ name = "pairing_ante: a non-number is nil", value = state("r1", { pairingAnte = "3" }), run = "r1", ante = nil },
	{ name = "pairing_ante: no value is nil", value = nil, run = "r1", ante = nil },
}

for _, row in ipairs(ante_rows) do
	local ante = PVP.TargetsView.pairing_ante(row.value, row.run)
	if ante == row.ante then
		print("ok   " .. row.name)
	else
		failed = failed + 1
		print(("FAIL %s: got %s; wanted %s"):format(row.name, tostring(ante), tostring(row.ante)))
	end
end

-- The pvp.targets of the server's Teams 2v2 midgame example: no pairing (opponents is {}), no Royale
-- safe map, no Nemesis pairing ante. The card targets and team scores are read in teams_view_test.lua.
do
	local value = dofile("tests/unit/net_fixture.lua")("state_pvp_midgame").changed["pvp.targets"]
	local known, opponent = PVP.TargetsView.opponent(value, "r1", "a1")
	local safe_known, safe = PVP.TargetsView.safe(value, "r1", "a1")
	local checks = {
		{ "midgame: no pairing is not known", known, false },
		{ "midgame: and names no opponent", opponent, nil },
		{ "midgame: no safe map is not known", safe_known, false },
		{ "midgame: and nobody is safe", safe, false },
		{ "midgame: no pairing ante", PVP.TargetsView.pairing_ante(value, "r1"), nil },
	}
	for _, row in ipairs(checks) do
		if row[2] == row[3] then
			print("ok   " .. row[1])
		else
			failed = failed + 1
			print(("FAIL %s: got %s; wanted %s"):format(row[1], tostring(row[2]), tostring(row[3])))
		end
	end
end

if failed > 0 then os.exit(1) end
print("targets_view_test: ok")
