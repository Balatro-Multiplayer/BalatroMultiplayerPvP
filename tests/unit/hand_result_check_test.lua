-- Plain Lua test: the replay's hand_result check waits for the hand to finish scoring.
-- A recorded hand_result is dispatched right after the play, while the hand is still scoring, so
-- PVP.GAME.score still holds the earlier hand's score. Comparing at once warned on correct replays.
-- Run from the repo root: luajit tests/unit/hand_result_check_test.lua
-- Needs the MPAPI repo next to this one (BalatroMultiplayerAPI/lib/big_score.lua).
local now = 0
love = { timer = { getTime = function() return now end } }
local warnings = {}
MPAPI = { sendWarnMessage = function(message) warnings[#warnings + 1] = message end }
PVP = { GAME = { score = "0" } }
dofile("../BalatroMultiplayerAPI/lib/big_score.lua")
dofile("lib/score.lua")
dofile("lib/hand_result_check.lua")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local waiters = {}
local function wait_for(predicate, callback) waiters[#waiters + 1] = { predicate = predicate, callback = callback } end
local function poll()
	local pending = waiters
	waiters = {}
	for _, w in ipairs(pending) do
		if w.predicate() then w.callback() else waiters[#waiters + 1] = w end
	end
end

-- The score lands after the check was made: no warning.
PVP.check_hand_result_when_scored("500", wait_for)
poll()
check("no warning while the hand is scoring", #warnings, 0)
PVP.GAME.score = "500"
poll()
check("no warning once the score matches", #warnings, 0)
check("the check is done", #waiters, 0)

-- A score that never matches warns once, after the wait.
PVP.GAME.score = "500"
PVP.check_hand_result_when_scored("900", wait_for)
poll()
check("a mismatch does not warn at once", #warnings, 0)
now = now + PVP.HAND_RESULT_CHECK_TIMEOUT_SECONDS + 1
poll()
check("a mismatch warns after the wait", #warnings, 1)
check("the warning names both scores", warnings[1]:find("recorded=900", 1, true) ~= nil and warnings[1]:find("real=500", 1, true) ~= nil, true)

if failures > 0 then
	os.exit(1)
end
