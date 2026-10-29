-- Plain Lua test for PVP.Score and the referee's pure score decisions (no game needed).
-- Run from the repo root: luajit tests/unit/score_test.lua
-- Needs the MPAPI repo next to this one (BalatroMultiplayerAPI/lib/big_score.lua).
MPAPI = {}
PVP = {}
dofile("../BalatroMultiplayerAPI/lib/big_score.lua")
dofile("lib/score.lua")
dofile("pvp_api/referee.lua")
local S = PVP.Score

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(tostring(name), tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

-- Score text, from the ADR: 10^100 and 10^10^20, next to plain numbers.
local PLAIN = "999999999999999"
local E100 = "100,1"
local TOWER = "20,2"

check("zero is not greater than zero", S.greater(S.ZERO, S.ZERO), false)
check("zero equals zero", S.equal("0", "0"), true)
check("a plain score beats zero", S.greater("5", "0"), true)
check("10 beats 9, not text order", S.greater("10", "9"), true)
check("an exponent score beats a big plain score", S.greater(E100, PLAIN), true)
check("a plain score does not beat an exponent score", S.greater(PLAIN, E100), false)
check("a tower beats an exponent score", S.greater(TOWER, E100), true)
check("an exponent score does not beat a tower", S.greater(E100, TOWER), false)
check("same text is equal", S.equal(E100, E100), true)
check("a missing score counts as zero", S.greater("1", nil), true)
check("a missing score equals zero", S.equal(nil, "0"), true)
check("a malformed score counts as zero", S.greater("1", "banana"), true)
check("a malformed score equals zero", S.equal("1e5", "0"), true)
check("a number is not score text", S.parse(5), nil)
check("parse gives canonical text", S.parse("12345"), "12345")
check("or_zero of garbage", S.or_zero("x"), "0")

check("display of a small score has comma groups", S.display("1234567"), "1,234,567")
check("display of an exponent score", S.display(E100), "1e100")
check("display of nothing", S.display(nil), "0")

check("small_number of a small score", S.small_number("42"), 42)
check("small_number of an exponent score", S.small_number(E100), nil)
check("small_number of a score past the switch point", S.small_number("100000000000"), nil)

check("from a double", S.from_game_value(1234), "1234")
check("a big-number-mod value and a double agree", S.from_game_value({ array = { 1234 }, sign = 1 }), S.from_game_value(1234))
check("an Amulet-style value past 1e308", S.from_game_value({ array = { 400, 1 }, sign = 1 }), "400,1")

-- The referee: who loses a round, decided on score text.
local function side(id, score, hands) return { id = id, score = score, hands_left = hands } end
local function resolve(a_score, b_score, a_hands, b_hands)
	local a, b = side("a", a_score, a_hands), side("b", b_score, b_hands)
	return PVP.referee_resolve_2p_round(a, b), a, b
end

do
	local r, a, b = resolve("5", "3", 0, 0)
	check("2p: higher plain score wins", r.winner, a)
	check("2p: lower plain score loses", r.loser, b)
	check("2p: not a tie", r.equal, false)
end
do
	local r, a, b = resolve(PLAIN, E100, 0, 0)
	check("2p: an exponent score beats a plain score (Amulet vs no mod)", r.winner, b)
	check("2p: the plain score loses", r.loser, a)
end
do
	local r, a = resolve(E100, TOWER, 0, 0)
	check("2p: a tower beats an exponent score", r.winner.id, "b")
	check("2p: the exponent score loses", r.loser, a)
end
do
	local r = resolve(E100, E100, 0, 0)
	check("2p: equal big scores tie", r.equal, true)
end
check("2p: the round stays open while the trailing side has hands", resolve("5", "3", 0, 1), nil)
do
	local r, a, b = resolve("3", E100, 0, 2)
	check("2p: the trailing side out of hands ends the round", r.loser, a)
end

-- Manhunt and Royale compare the same way.
do
	local runner = { id = "r", score = E100 }
	local hunters = { { id = "h1", score = PLAIN }, { id = "h2", score = TOWER } }
	local out = PVP.referee_resolve_manhunt_round(runner, hunters)
	check("manhunt: the hunter below the runner loses a life", #out.hunter_losers, 1)
	check("manhunt: it is h1", out.hunter_losers[1].id, "h1")
	check("manhunt: the runner is caught by a better hunter", out.runner_caught, true)
	check("manhunt: the top hunter is h2", out.highest_hunter_id, "h2")
end
do
	local out = PVP.referee_rank_royale({
		{ id = "x", score = TOWER },
		{ id = "y", score = PLAIN },
		{ id = "z", score = E100 },
		{ id = "w", score = "7" },
	})
	check("royale: the lowest two lose", #out.losers, 2)
	check("royale: w loses", out.is_loser.w, true)
	check("royale: y loses", out.is_loser.y, true)
	check("royale: the tower is safe", out.is_loser.x, nil)
end

-- Teams: the host sums each team's scores as score text.
check("sum of plain scores", S.sum({ "5", "7" }), "12")
check("sum of nothing is zero", S.sum({}), "0")
check("sum skips a malformed score", S.sum({ "5", "banana", "2" }), "7")
check("sum does not fall to text order", S.sum({ "9", "10" }), "19")
check("no number mod: an exponent score stands in for the sum", S.sum({ "5", E100 }), E100)
do
	local function tm(a, b, a_hands, b_hands)
		return PVP.referee_resolve_teams_round(a, b)
	end
	local r = tm({ { score = "5" }, { score = "4" } }, { { score = "10" } })
	check("teams: 9 vs 10, team A loses", r.loser_team, "A")
	check("teams: 9 vs 10 is not a tie", r.equal, false)
	r = tm({ { score = "5" }, { score = "5" } }, { { score = "10" } })
	check("teams: 10 vs 10 ties", r.equal, true)
	r = tm({ { score = "2" } }, { { score = E100 }, { score = "3" } })
	check("teams: an exponent team beats a plain team", r.loser_team, "A")
	r = tm({ { score = TOWER } }, { { score = E100 } })
	check("teams: a tower team beats an exponent team", r.loser_team, "B")
	r = tm({ { score = E100 } }, { { score = E100 } })
	check("teams: equal big teams tie", r.equal, true)
end

-- With a number mod, the sum goes through the mod's own add.
do
	local saved = to_big
	local mt = {}
	mt.__add = function(x, y) return setmetatable({ array = { x.array[1] + y.array[1], x.array[2] or y.array[2] }, sign = 1 }, mt) end
	to_big = function(x)
		if type(x) == "number" then return setmetatable({ array = { x }, sign = 1 }, mt) end
		return setmetatable({ array = x.array, sign = 1 }, mt)
	end
	check("mod: sums with the mod's add", S.sum({ "5", "7" }), "12")
	check("mod: sums exponent scores with the mod's add", S.sum({ "100,1", "100,1" }), "200,1")
	to_big = saved
end

-- The season best a player reports: score text, plus the old number.
PVP.REF = { players = {
	big = { score = "20,2", highest_score = "25.5,2" },
	low = { score = "5", highest_score = "1234" },
	cur = { score = "77" },
	none = {},
	huge = { score = "100,1" },
} }
check("season best text is the highest score", PVP.pvp_score_text("big"), "25.5,2")
check("season best text keeps a whole number", PVP.pvp_score_text("low"), "1234")
check("season best text falls back to the current score", PVP.pvp_score_text("cur"), "77")
check("season best text of nobody is zero", PVP.pvp_score_text("ghost"), "0")
check("season best text of a player with no score is zero", PVP.pvp_score_text("none"), "0")
check("old number of a small score", PVP.pvp_score_metric("low"), 1234)
check("old number caps at 1e15", PVP.pvp_score_metric("huge"), 1e15)
check("old number of a tower caps at 1e15", PVP.pvp_score_metric("big"), 1e15)
check("old number of nobody is zero", PVP.pvp_score_metric("ghost"), 0)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
