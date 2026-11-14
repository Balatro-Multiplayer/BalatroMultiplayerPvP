-- Run from the repo root: luajit tests/unit/lives_lookup_test.lua
-- PVP.lives_of / shown_opponent_lives / lives_text: lives come from the server's cache only;
-- an unknown count is nil and shows as "???".
PVP = {}
dofile("lib/lives_lookup.lua")

local failures = 0
local function check(label, got, want)
	if got ~= want then
		failures = failures + 1
		print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
	end
end

check("no cache entry is unknown", PVP.lives_of("b", { cache = {}, starting_lives = 4 }), nil)
check("no cache at all is unknown", PVP.lives_of("b", {}), nil)
check("the server cache beats the own counter", PVP.lives_of("me", { self_id = "me", own_lives = 3, cache = { me = 2 } }), 2)
check("no cache entry for my own id is unknown", PVP.lives_of("me", { self_id = "me", own_lives = 3, cache = {} }), nil)
check("the cache entry of another player", PVP.lives_of("b", { self_id = "me", own_lives = 3, cache = { me = 2, b = 5 } }), 5)
check("a cached 0 is a value", PVP.lives_of("b", { cache = { b = 0 } }), 0)

check("nemesis with no entry is unknown", PVP.shown_opponent_lives({ nemesis_id = "b", cache = {}, starting_lives = 4 }), nil)
check(
	"nobody known is unknown",
	PVP.shown_opponent_lives({ self_id = "me", player_ids = { "me", "b" }, cache = { me = 3 }, starting_lives = 4 }),
	nil
)
check(
	"highest of the others",
	PVP.shown_opponent_lives({ self_id = "me", player_ids = { "me", "b", "c" }, cache = { me = 9, b = 2, c = 3 } }),
	3
)

check("defensive bonus with unknown enemy lives", PVP.defensive_bonus(nil, 3, 10), 0)
check("defensive bonus with unknown own lives", PVP.defensive_bonus(4, nil, 10), 0)
check("defensive bonus with a negative difference", PVP.defensive_bonus(1, 4, 10), 0)
check("defensive bonus with a positive difference", PVP.defensive_bonus(4, 1, 10), 30)

check("a player at 0 is out", PVP.lives_out({ b = 0 }, "b"), true)
check("a player with lives is not out", PVP.lives_out({ b = 2 }, "b"), false)
check("a player missing from the cache is unknown", PVP.lives_out({}, "b"), nil)
check("no cache at all is unknown", PVP.lives_out(nil, "b"), nil)

check("text of a count", PVP.lives_text(3), "3")
check("text of a zero", PVP.lives_text(0), "0")
check("text of unknown", PVP.lives_text(nil), "???")

if failures > 0 then
	os.exit(1)
end
print("lives_lookup_test: ok")
