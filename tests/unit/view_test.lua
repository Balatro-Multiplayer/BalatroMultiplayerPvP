-- Run from the repo root: luajit tests/unit/view_test.lua
-- pvp_api/_view.lua: the shared reads of the match net's view.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

PVP = {}
dofile("pvp_api/_view.lua")
local view = PVP.view

local from = {
	me = "me",
	players = { a = { status = "playing" }, c = { status = "out" }, d = { status = "left" }, e = {} },
	match = { run = {
		id = "r1",
		players = { a = { lives = 3 }, z = { lives = 0 }, n = {}, c = { lives = 2 } },
		targets = { opponents = { "a" } },
		currentPvpBlind = { blindKey = "2:Boss", players = { me = "ready" } },
	} },
}

eq(view.run(from).id, "r1", "run")
eq(view.run(nil), nil, "no view, no run")
eq(view.run({ match = {} }), nil, "no run")
eq(view.run_player(from, "a").lives, 3, "run_player")
eq(view.run_player(from, "q"), nil, "an unlisted player")
eq(view.blind_key(2, "Boss"), "2:Boss", "blind_key")
eq(view.pvp_blind_key(3), "3:Boss", "pvp_blind_key")
eq(view.pvp_blind_key(nil), nil, "no ante, no key")
eq(view.opponent_id(from), "a", "opponent_id")
eq(view.opponent_id({ match = { run = {} } }), nil, "no targets")

for _, row in ipairs({ { "a", 3 }, { "z", 0 }, { "n", nil }, { "q", nil } }) do
	eq(view.lives_of(from, row[1]), row[2], "lives_of " .. row[1])
end
eq(view.lives_of(nil, "a"), nil, "no view is unknown")

-- is_out: status out or left, or lives 0; no view or no status is not out
for _, row in ipairs({ { "a", false }, { "c", true }, { "d", true }, { "e", false }, { "z", true }, { "q", false } }) do
	eq(view.is_out(from, row[1]), row[2], "is_out " .. row[1])
end
eq(view.is_out(nil, "c"), false, "no view is not out")
-- back in the lobby the game that ended says who is out; the lobby's own statuses do not
local lobby = { me = "a", match = { stage = "lobby", lobby = {}, ended = from }, players = { a = { status = "lobby" }, c = { status = "lobby" } } }
eq(view.is_out(lobby, "c"), true, "lobby after a game: out in the game that ended")
eq(view.is_out(lobby, "d"), true, "and left")
eq(view.is_out(lobby, "a"), false, "and one who was not out")
eq(view.is_out({ me = "a", match = { stage = "lobby", lobby = {} }, players = { c = { status = "out" } } }, "c"), false, "lobby with no ended game: nobody is out")

local open, mine = view.my_pvp_blind(from, "2:Boss")
eq(open.blindKey, "2:Boss", "my_pvp_blind open")
eq(mine, "ready", "my_pvp_blind mine")
eq(view.my_pvp_blind(from, "3:Boss"), nil, "another blind's")
eq(view.my_pvp_blind(from, nil), nil, "no blind key")

eq(view.is_my_run(from, { runId = "r1" }), true, "my run")
eq(view.is_my_run(from, { runId = "r0" }), false, "another run")
eq(view.is_my_run(from, nil), false, "no record")
eq(view.is_my_run(nil, { runId = "r1" }), false, "no view")

-- what the screens have shown: once per key, changed per name, forgotten by prefix
eq(view.once("a 1"), true, "a key is new the first time")
eq(view.once("a 1"), false, "and not again")
eq(view.once("a 2"), true, "another key is new")
eq(view.changed("x", nil), false, "nothing held equals nil")
eq(view.changed("x", "v"), true, "a first value is a change")
eq(view.changed("x", "v"), false, "the same value is not")
eq(view.changed("x", "w"), true, "another value is")
eq(view.changed("x", "v"), true, "going back is a change too: only the last value is held")
eq(view.changed("a y", 1), true, "a second name is its own")
view.forget("a ")
eq(view.once("a 1"), true, "a forgotten key is new again")
eq(view.changed("a y", 1), true, "a forgotten name holds nothing")
eq(view.changed("x", "v"), false, "other names stay")
view.changed("x", nil)
eq(view.changed("x", nil), false, "setting nil holds nil")
eq(view.changed("x", "v"), true, "and the next value is a change")

-- a new run starts the marks empty; the same run, or no run, keeps them
local function run_view(id) return { match = { stage = "playing", run = { id = id } } } end
view.follow_run(run_view("r1"))
view.changed("y", "v")
view.once("k")
view.follow_run(run_view("r1"))
view.follow_run(nil)
view.follow_run({ match = { stage = "lobby", ended = run_view("r1") } })
eq(view.changed("y", "v"), false, "the same run keeps a mark, also back in the lobby")
eq(view.once("k"), false, "and a key")
view.follow_run(run_view("r2"))
eq(view.changed("y", "v"), true, "a new run holds nothing")
eq(view.once("k"), true, "and knows no key")

print("view_test: ok (" .. checks .. " checks)")
