-- Plain Lua test for lib/contest.lua (pure decision logic, no game needed).
-- Run from the repo root: lua5.4 tests/unit/contest_test.lua
PVP = { LobbyAccess = { PRIVATE = "private", PRACTICE = "practice", RANKED = "ranked", CASUAL = "casual" } }
dofile("lib/contest.lua")
local C = PVP.Contest

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

check("ranked 2 players", C.should_offer("ranked", 2, true), true)
check("casual 2 players", C.should_offer("casual", 2, true), true)
check("private lobby keeps the plain forfeit", C.should_offer("private", 2, true), false)
check("practice keeps the plain forfeit", C.should_offer("practice", 1, false), false)
check("no kind known", C.should_offer(nil, 2, true), false)
check("3 players keep the plain forfeit", C.should_offer("casual", 3, true), false)
check("1 player", C.should_offer("ranked", 1, true), false)
check("no server referee", C.should_offer("ranked", 2, false), false)

check("none error", C.error_key(nil), "k_pvp_contest_failed")
check("already contested", C.error_key({ message = "already_contested" }), "k_pvp_contest_already")
check("server too old", C.error_key({ kind = "server_too_old" }), "k_pvp_contest_old_server")
check("string reason", C.error_key("not_in_game"), "k_pvp_contest_over")
check("unknown", C.error_key({ message = "weird" }), "k_pvp_contest_failed")

if failures > 0 then
	os.exit(1)
end
