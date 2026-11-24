-- Run from the repo root: luajit tests/unit/gambling_payout_test.lua
-- A misfire pays the server's amount, copy on the board or not: on main the copy's amount is always $10, and the copy
-- is missing only while it has not reached the board yet (after a crash, the rejoin).
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local paid, juiced, copy
PVP = { UTILS = { get_phantom_joker = function() return copy end } }
G = { E_MANAGER = { add_event = function(_, event) event.func() end } }
Event = function(fields) return fields end
ease_dollars = function(amount) paid[#paid + 1] = amount end
dofile("pvp_api/inbox_game.lua")
local game = PVP.inbox_game

paid, juiced = {}, 0
copy = { juice_up = function() juiced = juiced + 1 end }
game.gambling_payout("j_mp_lets_go_gambling", 10)
eq(paid[1], 10, "with the copy, the server's amount")
eq(juiced, 1, "the copy juices up")

paid = {}
copy = nil
game.gambling_payout("j_mp_lets_go_gambling", 10)
eq(paid[1], 10, "without the copy (not back on the board yet), still the server's amount")

print("gambling_payout_test: " .. checks .. " checks passed")
