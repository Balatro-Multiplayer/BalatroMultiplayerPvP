-- Run from the repo root: luajit tests/unit/pvp_blind_test.lua
-- The PvP blind: what the reader allows and shows, then the screen's hands, sends and opponent side.
local T = dofile("tests/support/check.lua")
local eq, same = T.eq, T.same

-- pvp_api/read/pvp_blind.lua: what the PvP blind allows and shows, from literal views.
do
	T.fresh()
	PVP = { NET = {}, READ = {}, UI = {} }
	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/read/blind_start.lua")
	dofile("pvp_api/read/pvp_blind.lua")
	local reader = PVP.READ.pvp_blind

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
	local entered_key, enter = PVP.READ.blind_start.next_entry(nil, closed, entry_game)
	eq(entered_key, "run1/" .. KEY, "the entered key")
	same(enter, { kind = "already over", blind_key = KEY }, "enter with no blindStart")
	eq(select(2, PVP.READ.blind_start.next_entry(entered_key, closed, entry_game)), nil, "not entered twice")
	eq(select(2, PVP.READ.blind_start.next_entry(nil, closed, game_at({ at_blind_select = false, on_boss = true, button = "boss" }))), nil, "only at blind select")
	eq(select(2, PVP.READ.blind_start.next_entry(nil, closed, game_at({ at_blind_select = true, on_boss = false, button = "boss" }))), nil, "only on the boss blind")
	eq(select(2, PVP.READ.blind_start.next_entry(nil, closed, game_at({ at_blind_select = true, on_boss = true, button = "boss", inbox_done = 2 }))), nil, "after my items are done")
	eq(select(2, PVP.READ.blind_start.next_entry(nil, view(nil), entry_game)), nil, "no result, no entry")
	eq(select(2, PVP.READ.blind_start.next_entry(nil, closed, game_at({ at_blind_select = true, on_boss = true }))), nil, "no button, no entry")

	-- A closed blind I was not paired in: no forced entry, no end screen. Being in scores or endedBy counts.
	local not_mine = view(nil, { finishedPvpBlinds = { { blindKey = KEY, losers = { "b" }, scores = { b = "5", c = "9" }, endedBy = { b = "hands", c = "hands" } } } })
	eq(select(2, PVP.READ.blind_start.next_entry(nil, not_mine, entry_game)), nil, "a blind I was not in is not entered")
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
	local V = PVP.READ.view
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
end

-- pvp_api/ui/pvp_blind.lua: when the game takes its hands from the server, when blindStart goes out,
-- handScored only from a real PvP blind, and the timer-out text. A stub net records send(kind, body).
do
	T.fresh()
	local sent = {}
	local net = {
		view = nil,
		send = function(kind, body)
			sent[#sent + 1] = { kind = kind, body = body }
			return #sent
		end,
	}
	local on_boss = false
	local said = {}

	PVP = {
		READ = {},
		RULES = {},
		NET = net,
		GAME = { enemy = {} },
		SCORE = {
			ZERO = "0",
			from_game_value = function(value) return tostring(value) end,
			to_game_value = function(text) return tonumber(text) end,
		},
		LOBBY = { in_session = function() return true end },
		PRACTICE = { is_on = function() return false end },
		UTILS = { is_pvp_blind = function() return on_boss end },
		UI = {
			match = {
				show_enemy_location = function() end,
				show_lives = function() end,
				end_pvp_blind = function() end,
				start_pvp_blind = function() end,
			},
		},
	}
	Game = { update = function() end }
	G = {
		STAGES = { RUN = 1 },
		STAGE = 1,
		STATES = { SELECTING_HAND = 1, BLIND_SELECT = 2, SHOP = 3 },
		STATE = 3,
		STATE_COMPLETE = true,
		GAME = {
			pvp_net = { runId = "run1", inboxDone = 4 },
			round_resets = { ante = 3, hands = 4 },
			current_round = { hands_left = 4 },
			chips = 0,
		},
		hand = { highlighted = {} },
		play = { cards = {} },
		HUD = {
			get_UIE_by_ID = function() return { config = { object = { update = function() end } } } end,
			recalculate = function() end,
		},
	}
	function localize(key) return key end
	warned = 0
	function sendWarnMessage() warned = warned + 1 end
	function number_format(value) return tostring(value) end
	function attention_text(args) said[#said + 1] = args.text end

	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/read/blind_start.lua")
	dofile("pvp_api/read/pvp_blind.lua")
	dofile("pvp_api/ui/pvp_blind.lua")
	local screen = PVP.UI.pvp_blind
	PVP.GAME.hands_source = { kind = "game" }

	-- What a load and a fresh entry set (lib/run_save.lua, pvp_api/ui/blind_start.lua).
	local function take_hands_from_server() PVP.GAME.hands_source = PVP.READ.pvp_blind.hands_source_loaded() end
	local function blind_start_at_first_hand()
		local key = PVP.READ.view.entry_key(G.GAME.pvp_net.runId, PVP.READ.view.pvp_blind_key(G.GAME.round_resets.ante))
		PVP.GAME.hands_source = PVP.READ.pvp_blind.hands_source_entered("fresh", key)
	end

	local function view(pvp_blind)
		return {
			me = "a",
			onlyMine = { inboxNewest = 4 },
			match = { run = { id = "run1", currentPvpBlind = pvp_blind, finishedPvpBlinds = {}, targets = { opponents = {} } } },
		}
	end

	-- A player's part of a playing blind, in the stages the view has.
	local NOT_ENTERED = { stage = "not entered" }
	local function entered(hands, score) return { stage = "entered", handsLeft = hands, score = { kind = "shown", score = score } } end
	local function played(hands, score) return { stage = "played a hand", handsLeft = hands, score = { kind = "shown", score = score } } end
	local function done(ended_by, hands, score) return { stage = "done", endedBy = ended_by, handsLeft = hands, score = { kind = "shown", score = score } } end

	local function playing(mine)
		return view({ stage = "playing", blindKey = "3:Boss", players = { a = mine, b = NOT_ENTERED } })
	end

	local function count(kind)
		local n = 0
		for _, message in ipairs(sent) do
			if message.kind == kind then n = n + 1 end
		end
		return n
	end

	local function pick_a_hand(hands_left)
		on_boss = true
		G.STATE = G.STATES.SELECTING_HAND
		G.STATE_COMPLETE = true
		G.GAME.current_round.hands_left = hands_left
	end

	-- A load in the shop, then a fresh PvP blind: the game keeps its own hands and Play is allowed.
	net.view = view(nil)
	take_hands_from_server()
	screen.update()
	net.view = playing(NOT_ENTERED)
	G.STATE = G.STATES.BLIND_SELECT
	screen.update()
	blind_start_at_first_hand()
	pick_a_hand(7)
	net.view = playing(entered(4, "0"))
	screen.update()
	eq(G.GAME.current_round.hands_left, 7, "a load in the shop leaves the next blind's hands alone")
	eq(count("blindStart"), 1, "and its blindStart goes out")
	eq(sent[#sent].body.handsLeft, 7, "with the hands after the blind's gains")
	eq(screen.may_play(), true, "Play is allowed in the fresh blind")

	-- A load at blind select, same ante: the fresh entry takes the marker with it.
	on_boss = false
	G.STATE = G.STATES.BLIND_SELECT
	take_hands_from_server()
	screen.update()
	blind_start_at_first_hand()
	pick_a_hand(6)
	net.view = playing(entered(4, "0"))
	screen.update()
	eq(G.GAME.current_round.hands_left, 6, "a load at blind select leaves the blind's hands alone")
	eq(screen.may_play(), true, "and Play is allowed")

	-- A load inside the blind: Play waits, then the hands and score come from the view.
	on_boss = true
	take_hands_from_server()
	G.STATE_COMPLETE = false
	screen.update()
	eq(screen.may_play(), false, "after a load Play waits for the view's hands")
	G.STATE_COMPLETE = true
	G.GAME.current_round.hands_left = 4
	net.view = playing(played(2, "300"))
	screen.update()
	eq(G.GAME.current_round.hands_left, 2, "the hands come from the view")
	eq(G.GAME.chips, 300, "and the score")
	eq(screen.may_play(), true, "then Play is allowed")
	screen.update()
	eq(count("blindStart"), 2, "nothing more is sent")

	-- A load while the HUD is not built: nothing is applied and the source is not spent; it applies later.
	take_hands_from_server()
	G.GAME.current_round.hands_left = 4
	G.GAME.chips = 0
	net.view = playing(played(2, "300"))
	local hud = G.HUD
	G.HUD = nil
	screen.update()
	eq(G.GAME.current_round.hands_left, 4, "no HUD: the hands are left alone")
	eq(screen.may_play(), false, "and the source is not spent, Play waits")
	G.HUD = hud
	screen.update()
	eq(G.GAME.current_round.hands_left, 2, "with the HUD the hands apply")
	eq(G.GAME.chips, 300, "and the score")
	eq(screen.may_play(), true, "and Play is allowed")

	-- A marker of an earlier blind never reaches the next one.
	G.STATE_COMPLETE = false
	take_hands_from_server()
	screen.update()
	G.STATE_COMPLETE = true
	G.GAME.round_resets.ante = 4
	net.view = view({ stage = "playing", blindKey = "4:Boss", players = { a = played(1, "9"), b = NOT_ENTERED } })
	G.GAME.current_round.hands_left = 5
	screen.update()
	eq(G.GAME.current_round.hands_left, 5, "a marker of another blind is dropped")
	eq(screen.may_play(), true, "and does not block Play")
	G.GAME.round_resets.ante = 3

	-- A load inside the blind when the view holds no hands for me yet: nothing is resent here (the input
	-- queue owns a lost blindStart); Play waits and the hands are taken once the view has me.
	take_hands_from_server()
	G.GAME.current_round.hands_left = 3
	G.GAME.chips = 120
	net.view = playing(NOT_ENTERED)
	local before = count("blindStart")
	screen.update()
	screen.update()
	eq(count("blindStart"), before, "no blindStart is resent by the screen")
	eq(screen.may_play(), false, "Play waits while the view has me not entered")
	net.view = playing(entered(3, "120"))
	screen.update()
	eq(screen.may_play(), true, "and is allowed once the view has me")

	-- A load while the last hand's scoring did not arrive: the screen sets the hands and sends nothing.
	take_hands_from_server()
	G.GAME.current_round.hands_left = 1
	before = count("handScored")
	net.view = playing(played(0, "500"))
	screen.update()
	eq(G.GAME.current_round.hands_left, 0, "the hands come from the view")
	eq(count("handScored"), before, "no handScored is resent by the screen")
	G.GAME.current_round.hands_left = 3

	-- A load while a fresh blind's blindStart is due: the load's source replaces it and the screen sends no
	-- blindStart (the input queue sends only inputs that were made).
	on_boss = false
	G.STATE = G.STATES.BLIND_SELECT
	net.view = playing(NOT_ENTERED)
	screen.update()
	blind_start_at_first_hand()
	take_hands_from_server()
	pick_a_hand(4)
	before = count("blindStart")
	screen.update()
	eq(count("blindStart"), before, "a load takes over a due blindStart: the screen sends none")

	-- The due marker is keyed by the game's own run: a view that names another run does not lose it.
	on_boss = false
	G.STATE = G.STATES.BLIND_SELECT
	net.view = playing(NOT_ENTERED)
	screen.update()
	blind_start_at_first_hand()
	pick_a_hand(4)
	net.view = view({ stage = "playing", blindKey = "3:Boss", players = { a = NOT_ENTERED, b = NOT_ENTERED } })
	net.view.match.run.id = "run2"
	before = count("blindStart")
	screen.update()
	eq(count("blindStart"), before + 1, "blindStart goes out when the view's run id differs from the game's")
	eq(sent[#sent].body.blindKey, "3:Boss", "and carries the game's blind")
	screen.update()
	eq(count("blindStart"), before + 1, "once")

	-- Same, when the view names another blind than the game's: the game's blind is the one sent.
	on_boss = false
	G.STATE = G.STATES.BLIND_SELECT
	net.view = playing(NOT_ENTERED)
	screen.update()
	blind_start_at_first_hand()
	pick_a_hand(4)
	net.view = view({ stage = "playing", blindKey = "5:Small", players = { a = NOT_ENTERED, b = NOT_ENTERED } })
	before = count("blindStart")
	screen.update()
	eq(count("blindStart"), before + 1, "blindStart goes out when the view names another blind")
	eq(sent[#sent].body.blindKey, "3:Boss", "with the game's blind key, not the view's")

	-- A due marker of a blind the game has left is dropped, and says so.
	on_boss = false
	G.STATE = G.STATES.BLIND_SELECT
	screen.update()
	blind_start_at_first_hand()
	G.GAME.round_resets.ante = 4
	pick_a_hand(4)
	net.view = view({ stage = "playing", blindKey = "4:Boss", players = { a = NOT_ENTERED, b = NOT_ENTERED } })
	before = count("blindStart")
	warned = 0
	screen.update()
	eq(count("blindStart"), before, "no blindStart for a blind the game has left")
	eq(warned, 1, "the dropped marker is logged")
	G.GAME.round_resets.ante = 3

	-- handScored comes only from a real PvP blind.
	before = count("handScored")
	on_boss = false
	screen.hand_scored("10", 2)
	eq(count("handScored"), before, "no handScored outside a PvP blind")
	on_boss = true
	screen.hand_scored("10", 2)
	eq(count("handScored"), before + 1, "handScored inside one")

	-- A hand gained inside a PvP blind sends the new hands left; a lost hand or one outside a PvP blind sends nothing.
	before = count("handScored")
	G.GAME.current_round.hands_left = 3
	G.GAME.chips = 40
	screen.hands_gained(0)
	screen.hands_gained(-1)
	on_boss = false
	screen.hands_gained(1)
	eq(count("handScored"), before, "no handScored for a hand lost, or gained outside a PvP blind")
	on_boss = true
	G.GAME.current_round.hands_played = 0
	screen.hands_gained(1)
	eq(count("handScored"), before, "a hand gained before my first hand waits for blindStart or the first handScored")
	G.GAME.current_round.hands_played = 1
	screen.hands_gained(1)
	eq(count("handScored"), before + 1, "a hand gained in a PvP blind is sent")
	eq(sent[#sent].body.handsLeft, 3, "with the hands left now")
	eq(sent[#sent].body.score, "40", "and the score as it stands")
	G.GAME.current_round.hands_left = 4
	G.GAME.chips = 0

	-- My timer ended my blind: the text shows once.
	net.view = playing(done("timer", 2, "10"))
	screen.update()
	screen.update()
	eq(#said, 1, "the timer-out text shows once")
	eq(said[1], "k_pvp_timer_out", "with its own text")
	eq(screen.may_play(), false, "and Play stays off")

	-- The blind that costs my last life ends the game: the next view is the lobby's, with the game that
	-- ended in it. My last life lost is read from there.
	local shown_lives = {}
	PVP.UI.match.show_lives = function(lives)
		shown_lives[#shown_lives + 1] = lives
		PVP.GAME.lives = lives
	end
	PVP.GAME.lives = 1
	local last = playing(done("hands", 0, "5"))
	last.match.run.players = { a = { lives = 0 }, b = { lives = 2 } }
	net.view = { me = "a", match = { stage = "lobby", lobby = {}, ended = last } }
	pick_a_hand(0)
	before = #sent
	screen.update()
	screen.update()
	eq(shown_lives[1], 0, "the last life lost shows from the game that ended")
	eq(#shown_lives, 1, "once")
	eq(#sent, before, "an ended game takes no inputs")

	-- The opponent's side: Ready while the blind waits, then hands and score, each shown once per change,
	-- and again for a new blind.
	PVP.READ.view.forget("pvp_blind ")
	local locations, eased = {}, {}
	PVP.UI.match.show_enemy_location = function(location) locations[#locations + 1] = location end
	PVP.RULES.current = function() return {} end
	PVP.UI.ease_enemy_score = function(score) eased[#eased + 1] = score end
	PVP.SCORE.greater = function(a, b) return b == nil or tonumber(a) > tonumber(b) end
	PVP.GAME.enemy = {}
	PVP.GAME.lives = nil
	on_boss = false
	G.STATE = G.STATES.BLIND_SELECT
	local function opponent_view(blind, ante_key)
		local seen = view(blind)
		seen.match.run.targets.opponents = { "b" }
		seen.match.run.currentPvpBlind.blindKey = ante_key or "3:Boss"
		return seen
	end
	net.view = opponent_view({ stage = "waiting", players = { a = "ready", b = "ready" } })
	screen.update()
	screen.update()
	eq(locations[1], "loc_ready", "a Ready opponent shows Ready")
	eq(#locations, 1, "once")
	net.view = opponent_view({ stage = "waiting", players = { a = "ready", b = "not ready" } })
	screen.update()
	eq(locations[2], "loc_selecting", "and Selecting when it lifts")
	eq(#locations, 2, "once")
	net.view = opponent_view({ stage = "waiting", players = { a = "not ready", b = "ready" } })
	screen.update()
	eq(locations[3], "loc_ready", "Ready again")
	local nobody_ready = opponent_view({ stage = "waiting", players = { a = "not ready", b = "not ready" } })
	nobody_ready.match.run.currentPvpBlind = nil
	net.view = nobody_ready
	screen.update()
	eq(locations[4], "loc_selecting", "the waiting blind gone (nobody Ready) shows Selecting")
	eq(#locations, 4, "once")
	net.view = opponent_view({ stage = "playing", players = { a = played(3, "10"), b = played(2, "500") } })
	screen.update()
	screen.update()
	eq(#locations, 4, "a playing blind leaves the location to the progress feed")
	eq(PVP.GAME.enemy.hands, 2, "the opponent's hands show")
	eq(PVP.GAME.enemy.real_score, "500", "and the score")
	eq(#eased, 1, "the score eases once")
	net.view = opponent_view({ stage = "playing", players = { a = played(3, "10"), b = played(1, "500") } })
	screen.update()
	eq(PVP.GAME.enemy.hands, 1, "a changed hands count shows")
	eq(#eased, 1, "an unchanged score does not ease again")
	net.view = opponent_view({ stage = "playing", players = { a = played(3, "10"), b = played(1, "500") } }, "4:Boss")
	G.GAME.round_resets.ante = 4
	screen.update()
	eq(#eased, 2, "another blind shows the same score again")
	G.GAME.round_resets.ante = 3
	net.view = opponent_view({ stage = "waiting", players = { a = "not ready", b = "ready" } })
	screen.update()
	eq(locations[5], "loc_ready", "Ready at the end of a game")
	local next_game = opponent_view({ stage = "waiting", players = { a = "not ready", b = "not ready" } })
	next_game.match.run.id = "run2"
	next_game.match.run.currentPvpBlind = nil
	net.view = next_game
	PVP.READ.view.follow_run(net.view)
	screen.update()
	eq(#locations, 5, "the next game does not show Selecting from the last game's Ready")
end

T.done("pvp_blind_test")
