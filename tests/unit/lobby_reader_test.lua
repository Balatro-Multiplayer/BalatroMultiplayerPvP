-- Run from the repo root: luajit tests/unit/lobby_reader_test.lua
-- pvp_api/lobby_reader.lua: what the lobby stage shows, from literal views.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

PVP = {}
dofile("pvp_api/lobby_reader.lua")
local reader = PVP.lobby_reader

local function lobby_view(ready, away, start)
	return { me = "a", match = { stage = "lobby", lobby = { ready = ready, away = away or {}, start = start } } }
end

eq(reader.lobby_of(nil), nil, "no view, no lobby")
eq(reader.lobby_of({ match = { stage = "run", run = {} } }), nil, "another stage is not the lobby")
eq(reader.ready_state(nil, "a", false), "waiting", "no view: waiting, never a guess")
local view = lobby_view({ a = false, b = true })
eq(reader.ready_state(view, "a", false), "not_ready", "the view says not ready")
eq(reader.ready_state(lobby_view({ a = true, b = true }), "a", false), "ready", "the view says ready")
eq(reader.ready_state(view, "a", true), "waiting", "an unconfirmed Ready: waiting")
eq(reader.next_ready(view, "a"), true, "a press asks for the opposite")
eq(reader.next_ready(lobby_view({ a = true }), "a"), false, "and back again")
eq(reader.next_ready(nil, "a"), true, "no view reads as not ready")
local by = reader.ready_by_player(view, { "a", "b" })
eq(by.a, false, "the tally follows the view (a)")
eq(by.b, true, "the tally follows the view (b)")
eq(reader.present_count(view), 2, "both seated players are here")
eq(reader.present_count(lobby_view({ a = true, b = true }, { "b" })), 1, "an away player is not counted")
eq(reader.present_count(nil), 0, "no view, nobody")

local answered = lobby_view({ a = true, b = true }, {}, { number = 3, refused = "not_all_ready" })
eq(reader.start_answer(answered, 3).refused, "not_all_ready", "the answer to my Start")
eq(reader.start_answer(answered, 4), nil, "an answer to another input is not mine")
eq(reader.start_answer(answered, nil), nil, "no Start asked, no answer read")
eq(reader.start_answer(lobby_view({ a = true }), 3), nil, "no answer yet")
eq(reader.start_answer(lobby_view({ a = true }, {}, { number = 3 }), 3).refused, nil, "an answer with no refusal")

print(string.format("lobby_reader_test: ok (%d checks)", checks))
