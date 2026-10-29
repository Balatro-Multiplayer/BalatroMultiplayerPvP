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
check("3 players offer a contest", C.should_offer("casual", 3, true), true)
check("ranked 4 players", C.should_offer("ranked", 4, true), true)
check("private 3 players keep the plain forfeit", C.should_offer("private", 3, true), false)
check("3 players, no server referee", C.should_offer("casual", 3, false), false)
check("1 player", C.should_offer("ranked", 1, true), false)
check("no server referee", C.should_offer("ranked", 2, false), false)

local players = {
	{ id = "me", displayName = "Me" },
	{ id = "a", displayName = "Ann" },
	{ id = "b", displayName = "Bob" },
	{ id = "c", displayName = "Cy" },
}
local function ids(list)
	local out = {}
	for _, p in ipairs(list) do
		out[#out + 1] = p.id
	end
	return table.concat(out, ",")
end
check("opponents leave out me", ids(C.opponents(players, "me", nil)), "a,b,c")
check("opponents leave out the dead", ids(C.opponents(players, "me", { b = 0 })), "a,c")
check("opponents keep the unknown", ids(C.opponents(players, "me", { a = 3 })), "a,b,c")
check("opponents of nobody", ids(C.opponents(nil, "me", nil)), "")
check("opponent without a name shows its id", C.opponents({ { id = "x" } }, "me", nil)[1].displayName, "x")

check("2 players: everyone sees it", C.scope(2, "me", "me"), C.Scope.EVERYONE)
check("2 players: the other sees it", C.scope(2, "a", "me"), C.Scope.EVERYONE)
check("3 players: the contester", C.scope(3, "me", "me"), C.Scope.CONTESTER)
check("3 players: a bystander", C.scope(3, "a", "me"), C.Scope.BYSTANDER)
check("no start snapshot counts as 2", C.scope(nil, "a", "me"), C.Scope.EVERYONE)

check("none error", C.error_key(nil), "k_pvp_contest_failed")
check("already contested", C.error_key({ message = "already_contested" }), "k_pvp_contest_already")
check("server too old", C.error_key({ kind = "server_too_old" }), "k_pvp_contest_old_server")
check("string reason", C.error_key("not_in_game"), "k_pvp_contest_over")
check("unknown", C.error_key({ message = "weird" }), "k_pvp_contest_failed")

if failures > 0 then
	os.exit(1)
end
