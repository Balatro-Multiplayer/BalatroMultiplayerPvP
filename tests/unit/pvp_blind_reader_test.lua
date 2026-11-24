-- Run from the repo root: luajit tests/unit/pvp_blind_reader_test.lua
-- pvp_api/pvp_blind_reader.lua: what the PvP blind allows and shows, from literal views.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local function show(value)
	if type(value) ~= "table" then return tostring(value) end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. show(value[key]) end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function same(actual, expected, message) eq(show(actual), show(expected), message) end

PVP = {}
dofile("pvp_api/_view.lua")
dofile("pvp_api/entry_reader.lua")
dofile("pvp_api/pvp_blind_reader.lua")
local reader = PVP.pvp_blind_reader

local KEY = "2:Boss"
local function may_play(v) return reader.may_play(v, KEY) end
local function opponent_now(v) return reader.opponent_now(v, KEY) end

-- A player's part of a playing blind, in each stage the view has.
local function shown(score) return { kind = "shown", score = score } end
local NOT_ENTERED = { stage = "not entered" }
local function entered(hands, score) return { stage = "entered", handsLeft = hands, score = shown(score) } end
local function played(hands, score) return { stage = "played a hand", handsLeft = hands, score = shown(score) } end
local function hidden(hands) return { stage = "played a hand", handsLeft = hands, score = { kind = "hidden" } } end
local function scoring(hands, score) return { stage = "scoring a hand", handsLeft = hands, score = shown(score) } end
local function done(ended_by, hands, score)
	return { stage = "done", endedBy = ended_by, handsLeft = hands, score = score and shown(score) or { kind = "none yet" } }
end

-- A view: `blind` is nil for none, else { stage = "waiting" | "playing" (default playing), me, opponent, blindKey }.
-- A waiting blind's parts are "ready" / "not ready"; a playing blind's parts come from the helpers above.
local function view(pvp_blind, extra)
	extra = extra or {}
	local players = pvp_blind and { a = pvp_blind.me or NOT_ENTERED, b = pvp_blind.opponent or NOT_ENTERED } or nil
	return {
		me = "a",
		onlyMine = { inboxNewest = extra.last_item_sent or 4 },
		match = {
			run = {
				id = "run1",
				players = { a = { lives = extra.lives or 4 }, b = { lives = 4 } },
				targets = { opponents = { "b" } },
				finishedPvpBlinds = extra.finishedPvpBlinds or {},
				currentPvpBlind = pvp_blind and { stage = pvp_blind.stage or "playing", blindKey = pvp_blind.blindKey or KEY, players = players } or nil,
			},
		},
	}
end

local function game_at(fields)
	local out = { blind_key = KEY, inbox_done = 4 }
	for k, v in pairs(fields or {}) do out[k] = v end
	return out
end

-- may_play: no hand without a view, without a playing blind, or once my blind is over; every stage of mine.
eq(may_play(nil), false, "no view, no play")
eq(may_play(view(nil)), false, "no blind, no play")
eq(may_play(view({ stage = "waiting", me = "ready", opponent = "ready" })), false, "a blind still waiting, no play")
eq(may_play(view({ me = NOT_ENTERED })), true, "stage not entered: the blind plays")
eq(may_play(view({ me = entered(3, "0") })), true, "stage entered: a hand is allowed")
eq(may_play(view({ me = played(2, "100") })), true, "stage played a hand: a hand is allowed")
eq(may_play(view({ me = done("hands", 0, "250") })), false, "stage done: no play")
eq(may_play(view({ me = done("timer", nil, nil), opponent = NOT_ENTERED })), false, "a timer run-out ends play")

-- A blind of another Boss than the game's (a leftover one, 362) is not mine to read: no Play, no opponent, no entry, no timer end.
local other = { blindKey = "3:Boss", me = played(2, "100"), opponent = played(3, "500") }
eq(may_play(view(other)), false, "another Boss's blind does not allow Play")
eq(opponent_now(view(other)), nil, "another Boss's blind shows no opponent")
eq(opponent_now(view({ blindKey = "3:Boss", stage = "waiting", me = "ready", opponent = "ready" })), nil, "another Boss's waiting blind shows no Ready")
same(reader.hands_after_load(view(other), game_at()), { kind = "not yet" }, "another Boss's blind sets nothing after a load")

-- hand_played: handsLeft is after the play; no hand to play sends nothing.
same(reader.hand_played({ blind_key = KEY, hands_left = 4, highlighted = 2, selecting_hand = true }), { blindKey = KEY, handsLeft = 3 }, "a play sends the hands after it")
same(reader.hand_played({ blind_key = KEY, hands_left = 1, highlighted = 5, selecting_hand = true }), { blindKey = KEY, handsLeft = 0 }, "the last hand sends 0")
eq(reader.hand_played({ blind_key = KEY, hands_left = 0, highlighted = 2, selecting_hand = true }), nil, "no hands left, nothing")
eq(reader.hand_played({ blind_key = KEY, hands_left = 3, highlighted = 0, selecting_hand = true }), nil, "no cards, nothing")
eq(reader.hand_played({ blind_key = KEY, hands_left = 3, highlighted = 2, selecting_hand = false }), nil, "not picking a hand, nothing")

-- hands_after_load: hands and score from the view after a load; nothing is resent.
local load_cases = {
	{ "stage played a hand: both set, nothing resent", view({ me = played(2, "300") }), game_at(), { kind = "set hands", hands_left = 2, score = "300" } },
	{ "stage entered: both set", view({ me = entered(4, "0") }), game_at(), { kind = "set hands", hands_left = 4, score = "0" } },
	{ "a save's own hands never win: the view's 1 is set", view({ me = played(1, "90") }), game_at(), { kind = "set hands", hands_left = 1, score = "90" } },
	{ "stage not entered (blindStart not confirmed yet): ask again", view({ me = NOT_ENTERED }), game_at(), { kind = "not yet" } },
	{ "stage done before entering: nothing to send", view({ me = done("timer", nil, nil) }), game_at(), { kind = "nothing to set" } },
	{ "last hand played, handScored not confirmed yet: set, nothing resent", view({ me = played(0, "250") }), game_at(), { kind = "set hands", hands_left = 0, score = "250" } },
	{ "stage done: hands and score set, nothing resent", view({ me = done("hands", 0, "250") }), game_at(), { kind = "set hands", hands_left = 0, score = "250" } },
	{ "an item of mine is not done yet: not ready", view({ me = played(2, "300") }, { last_item_sent = 6 }), game_at(), { kind = "not yet" } },
	{ "hands but my score hidden: refused", view({ me = hidden(2) }), game_at(), { kind = "not yet" } },
	{ "a waiting blind of this blind: not ready, nothing set", view({ stage = "waiting", me = "ready", opponent = "ready" }), game_at(), { kind = "not yet" } },
	{ "no view blind and no result: not ready", view(nil), game_at(), { kind = "not yet" } },
	{ "no open blind but a result of mine for this blind: ready, nothing set", view(nil, { finishedPvpBlinds = { { blindKey = KEY, losers = {}, endedBy = { a = "hands" } } } }), game_at(), { kind = "nothing to set" } },
	{ "a result I was not in: not ready", view(nil, { finishedPvpBlinds = { { blindKey = KEY, losers = {}, scores = { b = "5" }, endedBy = { b = "hands" } } } }), game_at(), { kind = "not yet" } },
	{ "another blind's blind open, this blind's result in: ready", view({ blindKey = "3:Boss", me = entered(3, "0") }, { finishedPvpBlinds = { { blindKey = KEY, losers = {}, endedBy = { a = "hands" } } } }), game_at(), { kind = "nothing to set" } },
	{ "another blind's blind open, no result: not ready", view({ blindKey = "3:Boss", me = entered(3, "0") }), game_at(), { kind = "not yet" } },
}
for _, case in ipairs(load_cases) do
	same(reader.hands_after_load(case[2], case[3]), case[4], case[1])
end

-- result_of: the blind's result with who lost and whether the timer did it (the screen shows it once per key).
local result = { blindKey = KEY, losers = { "a" }, endedBy = { a = "timer", b = "hands" }, close = "played out" }
local closed = view(nil, { finishedPvpBlinds = { result } })
local shown_key, change = reader.result_of(closed, game_at())
eq(shown_key, "run1/" .. KEY, "the result's key is the entry key")
same(change, { lost = true, timer_lost = true }, "a timer loss")
_, change = reader.result_of(view(nil, { finishedPvpBlinds = { { blindKey = KEY, losers = { "b" }, endedBy = { a = "hands", b = "hands" }, close = "played out" } } }), game_at())
same(change, { lost = false, timer_lost = false }, "a win")
_, change = reader.result_of(view(nil, { finishedPvpBlinds = { { blindKey = KEY, losers = {}, endedBy = { a = "hands", b = "hands" }, close = "played out" } } }), game_at())
same(change, { lost = false, timer_lost = false }, "a closed blind nobody lost")
_, change = reader.result_of(view(nil, { finishedPvpBlinds = { { blindKey = KEY, losers = { "a" }, endedBy = { a = "hands", b = "hands" }, close = "forced" } } }), game_at())
same(change, { lost = true, timer_lost = false }, "a forced close that cost me is a loss")
eq(select(2, reader.result_of(view(nil, { finishedPvpBlinds = { { blindKey = "1:Boss", losers = {}, endedBy = {} } } }), game_at())), nil, "another blind's result is not this one's")
eq(select(2, reader.result_of(view({ me = NOT_ENTERED }), game_at())), nil, "an open blind has no result")
eq(select(2, reader.result_of(nil, game_at())), nil, "no view, no result")

-- entry_reader.next_entry: a closed blind is entered once at blind select, with no blindStart.
local entry_game = game_at({ at_blind_select = true, on_boss = true, button = "boss" })
local entered_key, enter = PVP.entry_reader.next_entry(nil, closed, entry_game)
eq(entered_key, "run1/" .. KEY, "the entered key")
same(enter, { kind = "already over", blind_key = KEY }, "enter with no blindStart")
eq(select(2, PVP.entry_reader.next_entry(entered_key, closed, entry_game)), nil, "not entered twice")
eq(select(2, PVP.entry_reader.next_entry(nil, closed, game_at({ at_blind_select = false, on_boss = true, button = "boss" }))), nil, "only at blind select")
eq(select(2, PVP.entry_reader.next_entry(nil, closed, game_at({ at_blind_select = true, on_boss = false, button = "boss" }))), nil, "only on the boss blind")
eq(select(2, PVP.entry_reader.next_entry(nil, closed, game_at({ at_blind_select = true, on_boss = true, button = "boss", inbox_done = 2 }))), nil, "after my items are done")
eq(select(2, PVP.entry_reader.next_entry(nil, view(nil), entry_game)), nil, "no result, no entry")
eq(select(2, PVP.entry_reader.next_entry(nil, closed, game_at({ at_blind_select = true, on_boss = true }))), nil, "no button, no entry")

-- A closed blind I was not paired in: no forced entry, no end screen. Being in scores or endedBy counts.
local not_mine = view(nil, { finishedPvpBlinds = { { blindKey = KEY, losers = { "b" }, scores = { b = "5", c = "9" }, endedBy = { b = "hands", c = "hands" } } } })
eq(select(2, PVP.entry_reader.next_entry(nil, not_mine, entry_game)), nil, "a blind I was not in is not entered")
eq(select(2, reader.result_of(not_mine, game_at())), nil, "a blind I was not in shows no result")
local by_score = view(nil, { finishedPvpBlinds = { { blindKey = KEY, losers = {}, scores = { a = "5" }, endedBy = {} } } })
same(select(2, reader.result_of(by_score, game_at())), { lost = false, timer_lost = false }, "my score alone makes the result mine")
local by_end = view(nil, { finishedPvpBlinds = { { blindKey = KEY, losers = {}, scores = {}, endedBy = { a = "hands" } } } })
same(select(2, reader.result_of(by_end, game_at())), { lost = false, timer_lost = false }, "my ending alone makes the result mine")

-- blind_start: due at the first pick-a-hand, with the hands then (after Burglar-style gains), once.
local due_game = { key = "run1/" .. KEY, blind_key = KEY, selecting_hand = false, hands_left = 4, score = "0" }
eq(reader.blind_start({ kind = "blind start due", key = "run1/" .. KEY }, due_game), nil, "nothing before the first pick-a-hand")
due_game.selecting_hand, due_game.hands_left = true, 7
same(reader.blind_start({ kind = "blind start due", key = "run1/" .. KEY }, due_game), { blindKey = KEY, handsLeft = 7, score = "0" }, "the hands the player really starts with")
eq(reader.blind_start({ kind = "game" }, due_game), nil, "once sent and cleared, nothing more")
eq(reader.blind_start({ kind = "blind start due", key = "run1/3:Boss" }, due_game), nil, "another blind's entry is not due here")

-- The hands_source transitions: a table of (what happens, source computed, source expected).
local K1, K2 = "run1/2:Boss", "run1/3:Boss"
local FROM_SERVER = { kind = "from server", key = nil }
local transition_cases = {
	{ "a load", reader.hands_source_loaded(), FROM_SERVER },
	{ "a fresh entry", reader.hands_source_entered("fresh", K1), { kind = "blind start due", key = K1 } },
	{ "an entry into a blind in play", reader.hands_source_entered("already playing", K1), { kind = "from server", key = K1 } },
	{ "an entry into a closed blind", reader.hands_source_entered("already over", K1), { kind = "from server", key = K1 } },
	{ "a frame binds a loaded source to the game's key", reader.hands_source_at(FROM_SERVER, K1), { kind = "from server", key = K1 } },
	{ "a frame keeps a source of this blind", reader.hands_source_at({ kind = "from server", key = K1 }, K1), { kind = "from server", key = K1 } },
	{ "a frame drops a source of another blind", reader.hands_source_at({ kind = "from server", key = K1 }, K2), { kind = "game" } },
	{ "a frame drops a due blindStart of another blind", reader.hands_source_at({ kind = "blind start due", key = K1 }, K2), { kind = "game" } },
	{ "a frame without a run record settles to the game", reader.hands_source_at({ kind = "from server", key = K1 }, nil), { kind = "game" } },
	{ "a frame leaves the game's own", reader.hands_source_at({ kind = "game" }, K1), { kind = "game" } },
	{ "blindStart sent spends a due blindStart", reader.hands_source_done({ kind = "blind start due", key = K1 }, "blind start sent"), { kind = "game" } },
	{ "blindStart sent leaves hands from the server", reader.hands_source_done({ kind = "from server", key = K1 }, "blind start sent"), { kind = "from server", key = K1 } },
	{ "hands settled spends hands from the server", reader.hands_source_done({ kind = "from server", key = K1 }, "hands settled"), { kind = "game" } },
	{ "a result spends hands from the server", reader.hands_source_done({ kind = "from server", key = K1 }, "result shown"), { kind = "game" } },
	{ "a result leaves a due blindStart", reader.hands_source_done({ kind = "blind start due", key = K1 }, "result shown"), { kind = "blind start due", key = K1 } },
}
for _, case in ipairs(transition_cases) do
	same(case[2], case[3], case[1])
end
eq(reader.hands_from_server_waiting({ kind = "from server", key = nil }, K1), true, "unbound hands wait")
eq(reader.hands_from_server_waiting({ kind = "from server", key = K2 }, K1), false, "another blind's hands do not wait here")
eq(reader.hands_from_server_waiting({ kind = "blind start due", key = K1 }, K1), false, "a due blindStart is not hands from the server")
eq(reader.blind_start_waiting({ kind = "blind start due", key = K1 }, K1), true, "a due blindStart waits")
eq(reader.blind_start_waiting({ kind = "blind start due", key = K1 }, K2), false, "not for another blind")

-- timer_out: the entry key when my own timer ended my blind (the screen shows it once per key).
eq(reader.timer_out(view({ me = done("timer", 2, "10") }), game_at()), "run1/" .. KEY, "my timer ending my blind gives its key")
eq(reader.timer_out(view({ me = done("hands", 0, "10") }), game_at()), nil, "a hands ending is not a timer one")
eq(reader.timer_out(view({ me = done("hands", 1, "10") }), game_at()), nil, "a hands ending is not a timer one")
eq(reader.timer_out(view({ me = NOT_ENTERED, opponent = done("timer", 2, "10") }), game_at()), nil, "the opponent's timer is not mine")
eq(reader.timer_out(view({ blindKey = "3:Boss", me = done("timer", 2, "10") }), game_at()), nil, "another blind's blind")
eq(reader.timer_out(view({ me = played(2, "10") }), game_at()), nil, "still playing: not a timer end")
eq(reader.timer_out(view({ stage = "waiting", me = "ready", opponent = "ready" }), game_at()), nil, "a waiting blind has no timer end")

-- lives_change: one show per drop however often the same view arrives.
local lives = 4
local shows = 0
local function change_to(view_lives)
	local found = reader.lives_change(lives, view(nil, { lives = view_lives }))
	if not found then return nil end
	lives = found.lives
	if found.show then shows = shows + 1 end
	return found
end
eq(change_to(4), nil, "same lives, nothing")
same(change_to(3), { lives = 3, show = true }, "a drop is shown")
eq(change_to(3), nil, "the same view again shows nothing")
eq(change_to(3), nil, "and again")
eq(shows, 1, "one show for one drop")
same(change_to(1), { lives = 1, show = true }, "a drop of two is one show")
same(change_to(2), { lives = 2, show = false }, "a rise is set quietly")
eq(shows, 2, "two drops, two shows")
same(reader.lives_change(nil, view(nil, { lives = 4 })), { lives = 4, show = false }, "lives not known yet are set, not shown")
eq(reader.lives_change(4, nil), nil, "no view, nothing")

-- opponent: Ready while the blind waits, hands and score once it plays, each only when changed.
local waiting_ready = view({ stage = "waiting", me = "ready", opponent = "ready" })
local waiting_not = view({ stage = "waiting", me = "ready", opponent = "not ready" })
local playing = view({ me = played(2, "100"), opponent = played(3, "500") })
eq(reader.ready_look(opponent_now(waiting_ready)), "shown", "a Ready opponent in a waiting blind shows Ready")
eq(reader.ready_look(opponent_now(waiting_not)), nil, "an unready one shows none")
eq(reader.ready_look(opponent_now(playing)), nil, "a playing blind clears the Ready")
eq(reader.ready_look(nil), nil, "no opponent, none")

-- The opponent in every stage of a playing blind, and a score the view hides from me.
same(opponent_now(view({ me = NOT_ENTERED, opponent = NOT_ENTERED })), { waiting = false, ready = false, hands = nil, score = nil }, "opponent not entered: no hands, no score")
same(opponent_now(view({ me = NOT_ENTERED, opponent = entered(4, "0") })), { waiting = false, ready = false, hands = 4, score = "0" }, "opponent entered")
same(opponent_now(view({ me = NOT_ENTERED, opponent = hidden(3) })), { waiting = false, ready = false, hands = 3, score = nil }, "opponent's score hidden until I play a hand")
same(opponent_now(view({ me = played(3, "50"), opponent = played(3, "700") })), { waiting = false, ready = false, hands = 3, score = "700" }, "opponent played a hand, score shown")
same(opponent_now(view({ me = played(3, "50"), opponent = scoring(2, "700") })), { waiting = false, ready = false, hands = nil, score = "700" }, "opponent scoring a hand: hands wait for the score")
same(opponent_now(view({ me = played(3, "50"), opponent = done("hands", 0, "900") })), { waiting = false, ready = false, hands = 0, score = "900" }, "opponent done")
same(opponent_now(view({ me = played(3, "50"), opponent = done("timer", nil, nil) })), { waiting = false, ready = false, hands = nil, score = nil }, "opponent done before entering")
eq(opponent_now(view({ me = NOT_ENTERED, opponent = NOT_ENTERED })) ~= nil, true, "an opponent who has not entered is still shown")
local lone = view({ me = NOT_ENTERED })
lone.match.run.targets.opponents = {}
eq(opponent_now(lone), nil, "no paired opponent, nothing shown")

-- Teams: the HUD score is the other team's total; hands and Ready stay the paired opponent's.
local function teams_view(my_team, sums)
	local teams = view({ me = NOT_ENTERED, opponent = played(2, "40") })
	teams.players = { a = { team = my_team }, b = { team = "B" } }
	teams.match.run.targets.teamScores = sums
	return teams
end
same(opponent_now(teams_view("A", { A = "10", B = "30" })), { waiting = false, ready = false, hands = 2, score = "30" }, "team A sees team B's total")
same(opponent_now(teams_view("B", { A = "10", B = "30" })), { waiting = false, ready = false, hands = 2, score = "10" }, "team B sees team A's total")
same(opponent_now(teams_view("A", nil)), { waiting = false, ready = false, hands = 2, score = nil }, "totals hidden: unknown, never the card target's score")
same(opponent_now(view({ me = NOT_ENTERED, opponent = played(2, "40") })), { waiting = false, ready = false, hands = 2, score = "40" }, "other modes keep the opponent's own score")
local no_target = teams_view("A", { A = "10", B = "30" })
no_target.match.run.targets.opponents = {}
same(opponent_now(no_target), { waiting = false, ready = false, hands = nil, score = "30" }, "no card target: the team total still shows")

-- A view that arrives with the blind already closed (a rejoin after the opponent's last hand): the
-- opponent's final score comes from the closed entry, so the game still shows it.
local closed_entry = { blindKey = KEY, losers = {}, scores = { a = "1520", b = "58" }, endedBy = { a = "hands", b = "hands" } }
same(opponent_now(view(nil, { finishedPvpBlinds = { closed_entry } })), { waiting = false, ready = false, hands = nil, score = "58" }, "a closed blind still shows the opponent's final score")
eq(opponent_now(view(nil, { finishedPvpBlinds = { { blindKey = "1:Boss", losers = {}, scores = { a = "1", b = "2" }, endedBy = { a = "hands", b = "hands" } } } })), nil, "another blind's result shows no opponent")
eq(opponent_now(view(nil, { finishedPvpBlinds = { { blindKey = KEY, losers = {}, scores = { a = "1" }, endedBy = { a = "hands", b = "timer" } } } })), nil, "an opponent with no final score shows none")

-- One score function for the open and the closed blind, every mode (views.score_of / team_score_of).
local V = PVP.view
eq(V.score_of(view({ me = played(1, "10"), opponent = played(1, "77") }), KEY, "b"), "77", "open blind: the opponent's shown score")
eq(V.score_of(view({ me = played(1, "10"), opponent = hidden(1) }), KEY, "b"), nil, "open blind: a hidden score is nil")
eq(V.score_of(view(nil, { finishedPvpBlinds = { closed_entry } }), KEY, "b"), "58", "closed blind: the entry's score")
eq(V.score_of(view(nil, { finishedPvpBlinds = { closed_entry } }), "1:Boss", "b"), nil, "another blind's entry is not this one's")

-- Teams, closed: the other team's total comes from the closed entry, the same reader answer as the open blind.
local function teams_closed(sums)
	local value = teams_view("A", { A = "1", B = "2" })
	value.match.run.currentPvpBlind = nil
	value.match.run.targets.teamScores = nil
	value.match.run.finishedPvpBlinds = { { blindKey = KEY, losers = {}, scores = { a = "6", b = "4" }, endedBy = { a = "hands", b = "hands" }, teamScores = sums } }
	return value
end
same(opponent_now(teams_closed({ A = "10", B = "30" })), { waiting = false, ready = false, hands = nil, score = "30" }, "closed Teams blind: the other team's total")
eq(V.team_score_of(teams_closed({ A = "10", B = "30" }), KEY, "A"), "10", "closed Teams blind: either team's total")
eq(opponent_now(teams_closed(nil)), nil, "closed Teams blind with no totals shows none")

print(string.format("pvp_blind_reader_test: ok (%d checks)", checks))
