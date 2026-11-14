-- Run from the repo root: luajit tests/unit/enemy_score_view_test.lua
-- The pure view of the enemy's score in the "pvp.round" state (lib/enemy_score_view.lua).
PVP = { Score = {
	parse = function(text)
		return type(text) == "string" and text:match("^%d+$") or nil
	end,
} }
dofile("lib/_state_value.lua")
dofile("lib/enemy_score_view.lua")
local View = PVP.EnemyScoreView

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

local function round(players, extra)
	local value = { runId = "r1", roundId = 3, phase = "playing", players = players }
	for key, entry in pairs(extra or {}) do
		value[key] = entry
	end
	return value
end

local OPEN = round({ me = { handsLeft = 3 }, they = { handsLeft = 2 } })
local OPEN_SCORES = round({ me = { score = "10" }, they = { score = "1200", highestScore = "5000" } })

check("masked: no score key gives nil", View.score(OPEN, "r1", "they"), nil)
check("masked: no highestScore key gives nil", View.highest(OPEN, "r1", "they"), nil)
check("the score text is returned", View.score(OPEN_SCORES, "r1", "they"), "1200")
check("the highest score text is returned", View.highest(OPEN_SCORES, "r1", "they"), "5000")
check(
	"a numeric run id matches its text",
	View.score(round({ they = { score = "7" } }, { runId = 1 }), "1", "they"),
	"7"
)
check("another run gives nil", View.score(OPEN_SCORES, "r0", "they"), nil)
check("no current run gives nil", View.score(OPEN_SCORES, nil, "they"), nil)
check("another run's highest gives nil", View.highest(OPEN_SCORES, "r0", "they"), nil)
check("a nil value gives nil", View.score(nil, "r1", "they"), nil)
check("a string value gives nil", View.score("x", "r1", "they"), nil)
check("a number value gives nil (highest)", View.highest(5, "r1", "they"), nil)
check("players that is not a table gives nil", View.score({ runId = "r1", players = "x" }, "r1", "they"), nil)
check("no players key gives nil", View.score({ runId = "r1" }, "r1", "they"), nil)
check("an entry that is not a table gives nil", View.score(round({ they = "x" }), "r1", "they"), nil)
check("an unknown player gives nil", View.score(OPEN_SCORES, "r1", "other"), nil)
check("no target gives nil", View.score(OPEN_SCORES, "r1", nil), nil)
check("a score that is not text gives nil", View.score(round({ they = { score = 5 } }), "r1", "they"), nil)
check("an empty score gives nil", View.score(round({ they = { score = "" } }), "r1", "they"), nil)
check("my own entry is read like any other", View.score(OPEN_SCORES, "r1", "me"), "10")

check("round_is_mine: same run and round", View.round_is_mine(OPEN, "r1", 3), true)
check("round_is_mine: the round id compares as a number", View.round_is_mine(OPEN, "r1", "3"), true)
check("round_is_mine: another round", View.round_is_mine(OPEN, "r1", 2), false)
check("round_is_mine: another run", View.round_is_mine(OPEN, "r0", 3), false)
check("round_is_mine: no round of mine yet", View.round_is_mine(OPEN, "r1", nil), false)
check("round_is_mine: no run", View.round_is_mine(OPEN, nil, 3), false)
check("round_is_mine: not a table", View.round_is_mine(nil, "r1", 3), false)
check("round_is_mine: no round id in the value", View.round_is_mine({ runId = "r1" }, "r1", 3), false)

check("a malformed score counts as absent", View.score(round({ they = { score = "abc" } }), "r1", "they"), nil)
check(
	"a malformed highest score counts as absent",
	View.highest(round({ they = { highestScore = "1e" } }), "r1", "they"),
	nil
)
check("hands: the opponent's hands left", View.hands(round({ they = { handsLeft = 2 } }), "r1", "they"), 2)
check("hands: absent gives nil", View.hands(round({ they = {} }), "r1", "they"), nil)
check("hands: another run gives nil", View.hands(round({ they = { handsLeft = 2 } }), "r0", "they"), nil)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
