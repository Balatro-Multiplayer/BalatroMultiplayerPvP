-- Run from the repo root: luajit tests/unit/finish_test.lua
-- The end of the game: the reader's bodies and results, the screen's sends and end screen, and the rank line.
local T = dofile("tests/support/check.lua")
local eq = T.eq

-- pvp_api/read/finish.lua: the bodies of vote, forfeit and endGame, what each kind of result means
-- for me, the shown-once marker, when my endGame is due, and another player's end of game.
do
	T.fresh()
	PVP = { NET = {}, READ = {}, UI = {} }
	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/read/finish.lua")
	local reader = PVP.READ.finish

	-- vote
	local vote = reader.vote("draw", true)
	eq(vote.topic, "draw", "a draw vote names its topic")
	eq(vote.yes, true, "and says yes")
	eq(reader.vote("seed", false).yes, false, "a seed vote can say no")
	eq(reader.vote("seed", true).topic, "seed", "a seed vote names its topic")
	eq(reader.vote("kick", true), nil, "an unknown topic is not sent")
	eq(reader.vote("draw", "yes"), nil, "a vote that is not a boolean is not sent")
	eq(reader.vote("draw", nil), nil, "a vote with no answer is not sent")

	-- forfeit
	eq(next(reader.forfeit()), nil, "a forfeit has an empty body")

	-- endGame
	local body = reader.end_game("jokers", "deck", 3, 15)
	eq(body.jokers, "jokers", "endGame carries the jokers")
	eq(body.deck, "deck", "and the deck")
	eq(body.stats.rerollCount, 3, "and the reroll count")
	eq(body.stats.rerollCostTotal, 15, "and what rerolls cost")
	eq(reader.end_game("", "", 0, 0).jokers, "", "empty text is a valid endGame")
	eq(reader.end_game(nil, "d", 0, 0), nil, "no jokers text: not sent")
	eq(reader.end_game("j", 5, 0, 0), nil, "a deck that is not text: not sent")
	eq(reader.end_game("j", "d", -1, 0), nil, "a negative count: not sent")
	eq(reader.end_game("j", "d", 0, 1.5), nil, "a fractional count: not sent")
	local big_deck = string.rep("d", 5900)
	local trimmed = reader.end_game("jokers", big_deck, 0, 0)
	eq(trimmed.deck, "", "too much text leaves the longer part out")
	eq(trimmed.jokers, "jokers", "and keeps the jokers")
	local both = reader.end_game(string.rep("j", 5900), "deck", 0, 0)
	eq(both.jokers, "", "also when the jokers are the longer part")
	eq(both.deck, "deck", "the small deck still goes")
	local tie = reader.end_game(string.rep("j", 3000), string.rep("d", 3000), 0, 0)
	eq(tie.deck, "", "equal parts over the limit leave the deck out")
	eq(#tie.jokers, 3000, "and keep the jokers")
	local twice = reader.end_game(string.rep("j", 5900), string.rep("d", 5900), 0, 0)
	eq(twice.deck, "", "two parts each over the limit: the deck goes")
	eq(twice.jokers, "", "and the jokers too")

	-- jokers on leaving a shop
	eq(reader.jokers("abc").jokers, "abc", "the jokers text goes as it is")
	eq(reader.jokers(""), nil, "empty text is not sent")
	eq(reader.jokers(nil), nil, "no text is not sent")
	eq(reader.jokers(5), nil, "text that is not text is not sent")

	-- the end of the match, for me
	local function view(result, mine, run)
		return {
			me = "a",
			match = { stage = "run", result = result, run = run == nil and { id = "run1" } or run },
			players = { a = mine or { status = "playing" }, b = { status = "playing" }, c = { status = "playing" } },
		}
	end
	local function ended(result, mine)
		return reader.my_end(view(result, mine))
	end

	eq(reader.my_end(nil), nil, "no view: nothing")
	eq(reader.my_end(view(nil)), nil, "no result and still playing: nothing")
	eq(reader.my_end({ me = "a", match = { stage = "lobby" }, players = {} }), nil, "no run: nothing")

	-- Back in the lobby, the end is read from the game that ended, which the server keeps until the next start.
	local running = view({ kind = "win", winners = { "a" }, rated = true })
	eq(PVP.READ.view.game(running), running, "a running game: its own view")
	local lobby = { me = "a", match = { stage = "lobby", result = nil, run = nil, lobby = {}, ended = running }, players = {} }
	eq(PVP.READ.view.game(lobby), running, "the lobby: the game that ended")
	eq(reader.my_end(PVP.READ.view.game(lobby)).screen, "win", "so the win still shows after the lobby view arrives")
	eq(PVP.READ.view.game({ me = "a", match = { stage = "lobby", lobby = {} }, players = {} }), nil, "a lobby with no ended game: none")
	eq(PVP.READ.view.game(nil), nil, "no view: none")

	local win = ended({ kind = "win", winners = { "a" }, rated = true })
	eq(win.screen, "win", "a win with me among the winners")
	eq(win.rank, "counts", "a rated one")
	eq(ended({ kind = "win", winners = { "b" }, rated = true }).screen, "lose", "a win by another is my loss")
	eq(ended({ kind = "win", winners = { "b", "c" }, rated = true }).screen, "lose", "a team win without me is my loss")
	eq(ended({ kind = "win", winners = { "c", "a" }, rated = true }).screen, "win", "a team win with me in it is my win")
	eq(ended({ kind = "win", winners = {}, rated = true }).screen, "lose", "a win with nobody named is my loss")
	eq(ended({ kind = "win", winners = { "a" }, rated = false }).rank, "not_counted", "an unrated win says so")
	eq(ended({ kind = "win", winners = { "b" }, rated = false }).rank, "not_counted", "an unrated loss says so")
	eq(ended({ kind = "win", winners = { "a" } }).rank, "unsaid", "a win that does not say stays unsaid")

	local draw = ended({ kind = "draw", rated = true })
	eq(draw.screen, "draw", "a draw is a draw screen")
	eq(draw.rank, "counts", "a rated draw")
	eq(ended({ kind = "draw", rated = false }).rank, "not_counted", "an unrated draw")
	eq(ended({ kind = "draw" }).rank, "unsaid", "a draw that does not say stays unsaid")

	eq(ended({ kind = "win", rated = true }), nil, "a win that names no winners shows nothing, not a loss")
	eq(ended({ kind = "win", winners = "a", rated = true }), nil, "winners that are not a list show nothing")
	local abandoned = ended({ kind = "abandoned" })
	eq(abandoned.screen, "draw", "an abandoned game is a draw screen")
	eq(abandoned.rank, "not_counted", "and does not count for rank")
	eq(ended({ kind = "agreed" }), nil, "a result only a pre-run leave makes has no screen here")
	eq(ended({ kind = "dodged", dodgedBy = { "b" } }), nil, "nor has a dodge")
	eq(ended({ kind = "restarted" }), nil, "a restart has no end screen")
	eq(ended({ kind = "contested" }), nil, "a contest has its own screen")
	eq(ended({ kind = "unheard_of" }), nil, "a kind this mod does not know shows nothing")

	-- places
	eq(ended({ kind = "win", winners = { "a" } }, { status = "out", place = 1 }).place, 1, "my place comes through")
	eq(ended({ kind = "win", winners = { "b" } }, { status = "out", place = 3 }).place, 3, "also in third")
	eq(ended({ kind = "win", winners = { "b" } }, { status = "out" }).place, nil, "no place stays unknown")
	eq(ended({ kind = "draw" }, { status = "out", place = 2 }).place, 2, "a draw carries my place")
	eq(ended({ kind = "abandoned" }, { status = "out", place = 2 }).place, 2, "so does an abandoned game")

	-- out before a result: the loss at once, as the live game does; the match need not be over
	local early = ended(nil, { status = "out", place = 2 })
	eq(early.screen, "lose", "out of the match with no result yet: the loss")
	eq(early.rank, "unsaid", "the result has not said whether it counts")
	eq(early.place, 2, "with my place")
	eq(ended(nil, { status = "left" }).screen, "lose", "a leaver has the loss too")
	eq(ended(nil, { status = "away" }), nil, "away shows nothing")
	eq(ended(nil, { status = "playing" }), nil, "playing shows nothing")
	-- out, then the result arrives: the result's own answer
	eq(ended({ kind = "win", winners = { "a", "c" } }, { status = "out", place = 1 }).screen, "win", "out with a result: my team wins, a win")
	eq(ended({ kind = "win", winners = { "b", "c" } }, { status = "out", place = 3 }).screen, "lose", "out with a result: the other team wins, a loss")

	-- Teams: the live game sends no elimination there (a forfeiter or a member whose team's lives are gone waits
	-- for the team's result, which can still be a win or a draw); a leaver still loses at once
	local function team_view(result, status, waiting)
		local team_run = { id = "run1", waitingDeaths = waiting or {}, teamLives = { A = 0, B = 2 } }
		return {
			me = "a",
			match = { stage = "run", result = result, run = team_run },
			players = {
				a = { status = status or "out", team = "A" },
				b = { status = "playing", team = "A" },
				c = { status = "playing", team = "B" },
			},
		}
	end
	local b_waits = { { player = "b", blindKey = "x", waitingFor = { "c" } } }
	eq(reader.my_end(team_view(nil)), nil, "teams: a forfeiter has no end before the result")
	eq(reader.my_end(team_view(nil, "out", b_waits)), nil, "teams: out while my teammate's death waits: no end yet")
	eq(reader.my_end(team_view(nil, "left")).screen, "lose", "teams: a leaver loses at once")
	eq(reader.my_end(team_view(nil, "left")).by, "out", "an end with no result is by out")
	eq(reader.my_end(team_view({ kind = "win", winners = { "a", "b" } })).by, "result", "an end with a result is by result")
	eq(reader.my_end(team_view({ kind = "win", winners = { "a", "b" } })).screen, "win", "teams: the team's win is the forfeiter's win")
	eq(reader.my_end(team_view({ kind = "win", winners = { "c" } })).screen, "lose", "teams: the other team's win is a loss")
	eq(reader.my_end(team_view({ kind = "draw" }, "out", b_waits)).screen, "draw", "teams: the draw that settles it is my end")

	-- a rejoin into an ended match: the first view says it is over
	local rejoin = reader.my_end(view({ kind = "win", winners = { "b" }, rated = true }, { status = "out", place = 2 }))
	eq(rejoin.screen, "lose", "a rejoin into an ended match shows the end")
	eq(rejoin.place, 2, "with my place")
	eq(reader.my_end(view(nil)), nil, "no end, nothing to show")

	-- when my endGame is due
	eq(reader.end_game_due(nil, view(nil)), nil, "playing: not due")
	eq(reader.end_game_due(nil, view(nil, { status = "out" })), "run1", "out: due")
	eq(reader.end_game_due(nil, view(nil, { status = "left" })), "run1", "left: due")
	eq(reader.end_game_due(nil, view(nil, { status = "away" })), nil, "away: not due")
	eq(reader.end_game_due(nil, view({ kind = "draw" })), "run1", "a result: due")
	eq(reader.end_game_due("run1", view({ kind = "draw" })), nil, "sent for this run: not due")
	eq(reader.end_game_due("run0", view({ kind = "draw" }, nil, { id = "run2" })), "run2", "a new run: due again")
	eq(reader.end_game_due(nil, { me = "a", match = { stage = "lobby", result = {} }, players = {} }), nil, "no run: not due")

	-- another player's end of game
	local function decode(text)
		if text == "bad" then return nil end
		return { { key = text } }
	end
	local function with_end(sent)
		local v = view({ kind = "draw" })
		v.players.b.endGame = sent
		return v
	end
	eq(reader.other_end(view(nil), "b", decode), nil, "no endGame in the view: unknown")
	eq(reader.other_end(view(nil), "zed", decode), nil, "a player not in the view: unknown")
	local other = reader.other_end(with_end({ jokers = "j_joker", deck = "H-2" }), "b", decode)
	eq(other.jokers[1].key, "j_joker", "their jokers are decoded")
	eq(other.deck, "H-2", "and their deck is the text")
	local blank = reader.other_end(with_end({ jokers = "", deck = "" }), "b", decode)
	eq(blank.jokers, nil, "empty jokers are unknown, not none")
	eq(blank.deck, nil, "an empty deck is unknown, not empty")
	eq(reader.other_end(with_end({ jokers = "bad", deck = "H-2" }), "b", decode).jokers, nil, "jokers that do not decode are unknown")
	eq(reader.other_end(with_end({ jokers = "bad", deck = "H-2" }), "b", decode).deck, "H-2", "the deck is still known")

	-- the newest jokers of a player who has sent no endGame
	local function with_latest(jokers, sent)
		local v = view(nil)
		v.players.b.jokers = jokers
		v.players.b.endGame = sent
		return v
	end
	local live = reader.other_end(with_latest("j_live"), "b", decode)
	eq(live.jokers[1].key, "j_live", "their newest jokers show while they have no endGame")
	eq(live.deck, nil, "and their deck is unknown")
	eq(reader.other_end(with_latest(nil), "b", decode), nil, "no jokers and no endGame: unknown")
	eq(reader.other_end(with_latest(""), "b", decode), nil, "empty live jokers text: unknown")
	eq(reader.other_end(with_latest("j_live", { jokers = "j_end", deck = "H-2" }), "b", decode).jokers[1].key, "j_end", "the endGame's jokers replace them")
	eq(reader.other_end(with_latest("j_live", { jokers = "", deck = "H-2" }), "b", decode).jokers[1].key, "j_live", "an endGame with no jokers leaves them")
	eq(reader.other_end(with_latest("bad"), "b", decode).jokers, nil, "live jokers that do not decode are unknown")
	local first = reader.other_end(with_latest("j_one"), "b", decode).mark
	eq(first ~= reader.other_end(with_latest("j_two"), "b", decode).mark, true, "newer jokers change the mark")
	eq(first ~= reader.other_end(with_latest("j_one", { jokers = "j_one", deck = "H-2" }), "b", decode).mark, true, "an endGame changes the mark")
	eq(first, reader.other_end(with_latest("j_one"), "b", decode).mark, "the same view has the same mark")

	-- the best score over the closed blinds
	local function greater(a, b) return tonumber(a) > tonumber(b) end
	local function with_pvp_blinds(pvp_blinds)
		local v = view(nil)
		v.match.run.finishedPvpBlinds = pvp_blinds
		return v
	end
	eq(reader.best_score(view(nil), "a", greater), nil, "no blinds: unknown")
	eq(reader.best_score(nil, "a", greater), nil, "no view: unknown")
	eq(reader.best_score(with_pvp_blinds({ { scores = { a = "50", b = "70" } }, { scores = { a = "90" } }, { scores = { a = "20" } } }), "a", greater), "90", "the highest of mine")
	eq(reader.best_score(with_pvp_blinds({ { scores = { a = "50", b = "70" } } }), "b", greater), "70", "another player's own")
	eq(reader.best_score(with_pvp_blinds({ { scores = { a = "50" } } }), "c", greater), nil, "a player with no score is unknown")
	eq(reader.best_score(with_pvp_blinds({ { scores = {} }, { endedBy = { a = "x" } } }), "a", greater), nil, "a blind without my score adds nothing")

	-- vote progress
	local function with_votes(votes, run_id, players)
		local v = view(nil, nil, { id = run_id or "run1", votes = votes })
		if players then v.players = players end
		return v
	end
	local function none() return { draw = {}, seed = {} } end
	local marker, lines = reader.vote_progress(nil, with_votes({ draw = { "a" }, seed = {} }))
	eq(#lines, 0, "the first view of a run prints nothing")
	eq(marker.draw, 1, "and remembers the draw count")
	eq(marker.run, "run1", "and the run")
	marker, lines = reader.vote_progress(marker, with_votes({ draw = { "a" }, seed = {} }))
	eq(#lines, 0, "an unchanged count prints nothing")
	marker, lines = reader.vote_progress(marker, with_votes({ draw = { "a", "b" }, seed = {} }))
	eq(#lines, 1, "a new vote prints a line")
	eq(lines[1].topic, "draw", "for its topic")
	eq(lines[1].count, 2, "with the count")
	eq(lines[1].total, 3, "and the players in the match")
	marker, lines = reader.vote_progress(marker, with_votes({ draw = { "a", "b" }, seed = { "c" } }, "run1", { a = { status = "playing" }, b = { status = "left" }, c = { status = "out" }, d = { status = "away" } }))
	eq(lines[1].topic, "seed", "a seed vote prints for the seed")
	eq(lines[1].total, 2, "only players playing or away are counted: not one who left or is out")
	marker, lines = reader.vote_progress(marker, with_votes(none()))
	eq(#lines, 0, "votes cleared print nothing")
	eq(marker.draw, 0, "and the marker follows")
	marker, lines = reader.vote_progress(marker, with_votes({ draw = { "a" }, seed = {} }, "run2"))
	eq(#lines, 0, "a new run starts silently")
	eq(marker.run, "run2", "on its own marker")
	local kept, none_lines = reader.vote_progress(marker, with_votes({ draw = { "a" } }))
	eq(kept, marker, "a view with no seed list changes nothing")
	eq(#none_lines, 0, "and prints nothing")
	eq(select(1, reader.vote_progress(nil, view(nil, nil, { id = "run1" }))), nil, "a view with no votes at all leaves no marker")
end

-- pvp_api/ui/finish.lua: votes, forfeit and endGame go out once and never from a replay; the end of
-- the match is shown once, only when the view says so, also after a rejoin; other players' jokers and
-- decks come from the view. A stub net records send(kind, body).
do
	T.fresh()
	local sent, dispatched, refreshed, chat, pending_ended, warnings
	local playing_back, waiting_for, send_works
	local net = {}
	function net.send(kind, body)
		if not send_works then return nil end
		sent[#sent + 1] = { kind = kind, body = body }
		return #sent
	end
	function net.send_live(kind, body)
		if not body or playing_back then return nil end
		return net.send(kind, body)
	end
	function net.waiting(kind)
		return waiting_for[kind] or false
	end

	local function fresh()
		sent, dispatched, refreshed, chat, pending_ended, warnings = {}, {}, 0, {}, 0, {}
		playing_back, waiting_for, send_works = false, {}, true
		net.view = nil
		PVP = {
			NET = net,
			READ = {},
			GAME = { end_shown = "not yet", stats = { reroll_count = 2, reroll_cost_total = 9 } },
			UTILS = { card_to_string = function(card) return card.name end },
			UI = {
				refresh_end_game_jokers = function() refreshed = refreshed + 1 end,
				pending_death = { close = function() pending_ended = pending_ended + 1 end },
				match = {
					win = function() dispatched[#dispatched + 1] = "winGame" end,
					lose = function() dispatched[#dispatched + 1] = "loseGame" end,
					draw = function() dispatched[#dispatched + 1] = "drawGame" end,
				},
			},
			SCORE = { greater = function(a, b) return tonumber(a) > tonumber(b) end },
			LOBBY = { in_session = function() return true end },
			PRACTICE = { is_on = function() return false end },
		}
		localize = function(key) return "t:" .. key end
		MPAPI = {
			chat = { addMessage = function(text) chat[#chat + 1] = text end },
			playback = { is_driving = function() return playing_back end },
			encode = function(list)
				local keys = {}
				for _, joker in ipairs(list) do keys[#keys + 1] = joker.key end
				return table.concat(keys, ",")
			end,
			decode = function(text)
				local list = {}
				for key in text:gmatch("[^,]+") do list[#list + 1] = { key = key } end
				return list
			end,
		}
		Game = { update = function() end }
		G = {
			STAGES = { RUN = 1 },
			STAGE = 1,
			GAME = { pvp_net = { runId = "run1" } },
			C = { BLUE = "blue" },
			jokers = { cards = { { config = { center = { key = "j_joker" } }, ability = {} } } },
			playing_cards = { { name = "H-2" }, { name = "S-K" } },
		}
		sendWarnMessage = function(text) warnings[#warnings + 1] = text end
		dofile("pvp_api/read/_view.lua")
		dofile("pvp_api/read/run.lua")
		dofile("pvp_api/read/finish.lua")
		dofile("pvp_api/ui/finish.lua")
		return T.ticked(PVP.UI.finish)
	end

	local function view(result, mine, run_id, other)
		return {
			me = "a",
			match = {
				stage = "run",
				result = result,
				run = { id = run_id or "run1", targets = { opponents = { "b" } } },
			},
			players = {
				a = mine or { status = "playing" },
				b = other or { status = "playing" },
			},
		}
	end

	local function count(kind)
		local n = 0
		for _, message in ipairs(sent) do
			if message.kind == kind then n = n + 1 end
		end
		return n
	end

	local screen

	-- votes
	screen = fresh()
	net.view = view(nil)
	screen.vote("draw")
	eq(count("vote"), 1, "a draw vote goes out")
	eq(sent[1].body.topic, "draw", "with its topic")
	eq(sent[1].body.yes, true, "and a yes")
	screen.vote("seed")
	eq(sent[2].body.topic, "seed", "a seed vote has its own topic")
	waiting_for.vote = true
	screen.vote("draw")
	eq(count("vote"), 2, "while a vote is not confirmed, none goes out")
	eq(screen.waiting("vote"), true, "and the button shows it waits")
	eq(screen.waiting("forfeit"), false, "a forfeit is not waiting")
	waiting_for.vote = nil
	playing_back = true
	screen.vote("draw")
	eq(count("vote"), 2, "a replay sends no vote")
	playing_back = false
	eq(screen.vote("kick"), nil, "an unknown topic sends nothing")
	eq(count("vote"), 2, "also not by this route")

	-- forfeit
	screen = fresh()
	screen.forfeit()
	eq(count("forfeit"), 0, "no view: no forfeit")
	net.view = view(nil)
	screen.forfeit()
	eq(count("forfeit"), 1, "a forfeit goes out")
	eq(next(sent[1].body), nil, "with an empty body")
	screen.forfeit()
	eq(count("forfeit"), 1, "once per run")
	net.view = view(nil, nil, "run2")
	screen.forfeit()
	eq(count("forfeit"), 2, "a new run can forfeit again")
	screen = fresh()
	net.view = view(nil)
	waiting_for.forfeit = true
	screen.forfeit()
	eq(count("forfeit"), 0, "not while a forfeit waits")
	waiting_for.forfeit = nil
	playing_back = true
	screen.forfeit()
	eq(count("forfeit"), 0, "a replay forfeits nothing")
	playing_back = false
	send_works = false
	screen.forfeit()
	send_works = true
	screen.forfeit()
	eq(count("forfeit"), 1, "a forfeit the net did not take can be tried again")

	-- endGame
	screen = fresh()
	net.view = view(nil)
	screen.update()
	eq(count("endGame"), 0, "still playing: no endGame")
	net.view = view(nil, { status = "out" })
	screen.update()
	eq(count("endGame"), 1, "out: endGame goes out")
	local body = sent[#sent].body
	eq(body.jokers, "j_joker", "with my jokers")
	eq(body.deck, "H-2;S-K", "my deck")
	eq(body.stats.rerollCount, 2, "my reroll count")
	eq(body.stats.rerollCostTotal, 9, "and what they cost")
	screen.update()
	screen.update()
	eq(count("endGame"), 1, "once, however often the screen updates")
	net.view = view({ kind = "draw" }, { status = "out" })
	screen.update()
	eq(count("endGame"), 1, "a result for the same run adds none")
	G.GAME.pvp_net.runId = "run2"
	net.view = view({ kind = "draw" }, { status = "out" }, "run2")
	screen.update()
	eq(count("endGame"), 2, "a new run sends its own")

	screen = fresh()
	net.view = view({ kind = "win", winners = { "a" } })
	screen.update()
	eq(count("endGame"), 1, "a result with me still in sends it")
	screen = fresh()
	playing_back = true
	net.view = view(nil, { status = "out" })
	screen.update()
	eq(count("endGame"), 0, "a replay sends no endGame")
	playing_back = false
	screen.update()
	eq(count("endGame"), 1, "and the real one goes after it")
	screen = fresh()
	send_works = false
	net.view = view(nil, { status = "out" })
	screen.update()
	send_works = true
	screen.update()
	eq(count("endGame"), 1, "an endGame the net did not take is tried again")
	screen = fresh()
	net.view = view(nil, { status = "left" })
	screen.update()
	eq(count("endGame"), 1, "left: endGame goes out")

	-- the result is shown once, and only once the view says so
	screen = fresh()
	net.view = view(nil)
	screen.update()
	eq(#dispatched, 0, "no result: no screen")
	net.view = view({ kind = "win", winners = { "a" }, rated = true })
	screen.update()
	eq(dispatched[1], "winGame", "a win shows the win screen")
	eq(PVP.GAME.end_shown, "by result", "and marks the result handled")
	eq(PVP.GAME.end_rank, "counts", "a rated game is marked as counting")
	screen.update()
	screen.update()
	eq(#dispatched, 1, "once")

	screen = fresh()
	net.view = view({ kind = "win", winners = { "b" }, rated = true }, { status = "out" })
	screen.update()
	eq(dispatched[1], "loseGame", "another's win shows my loss")
	screen = fresh()
	net.view = view({ kind = "draw", rated = true })
	screen.update()
	eq(dispatched[1], "drawGame", "a draw shows the draw screen")
	screen = fresh()
	net.view = view({ kind = "abandoned" })
	screen.update()
	eq(dispatched[1], "drawGame", "an abandoned game shows a draw screen")
	eq(PVP.GAME.end_rank, "not_counted", "that does not count for rank")
	screen = fresh()
	net.view = view({ kind = "win", winners = { "a" }, rated = false })
	screen.update()
	eq(PVP.GAME.end_rank, "not_counted", "an unrated win is marked")
	screen = fresh()
	net.view = view({ kind = "restarted" })
	screen.update()
	eq(#dispatched, 0, "a restart shows no end screen")
	screen = fresh()
	net.view = view({ kind = "contested" })
	screen.update()
	eq(#dispatched, 0, "a contest shows none of its own here")

	screen = fresh()
	PVP.GAME.end_shown = "by contest"
	net.view = view({ kind = "win", winners = { "a" } })
	screen.update()
	eq(#dispatched, 0, "a contested game keeps its own screen")
	screen = fresh()
	PVP.GAME.end_shown = "by result"
	net.view = view({ kind = "win", winners = { "a" } })
	screen.update()
	eq(#dispatched, 0, "a result already shown is not shown again")
	screen = fresh()
	G.STAGE = 2
	net.view = view({ kind = "win", winners = { "a" } })
	screen.update()
	eq(#dispatched, 0, "outside a run nothing is shown")
	eq(count("endGame"), 0, "and nothing is sent")
	-- out before the match has a result: the loss at once, and the result that follows adds nothing
	screen = fresh()
	net.view = view(nil, { status = "out", place = 2 })
	screen.update()
	screen.update()
	eq(dispatched[1], "loseGame", "out with no result shows the loss at once")
	eq(#dispatched, 1, "once")
	eq(PVP.GAME.end_shown, "by out", "and marks the end handled")
	eq(count("endGame"), 1, "and my endGame goes out")
	eq(pending_ended, 1, "and a pending death is cleared")
	net.view = view({ kind = "win", winners = { "a", "c" }, rated = true }, { status = "out", place = 1 })
	screen.update()
	screen.update()
	eq(#dispatched, 1, "out, then my side wins: no second screen")
	eq(PVP.GAME.end_rank, "counts", "but the result still says the game counts")
	screen = fresh()
	net.view = view(nil, { status = "out" })
	screen.update()
	net.view = view({ kind = "win", winners = { "b", "c" }, rated = true }, { status = "out" })
	screen.update()
	eq(#dispatched, 1, "out, then the other side wins: no second screen")
	eq(dispatched[1], "loseGame", "the loss stays")
	screen = fresh()
	net.view = view(nil, { status = "left" })
	screen.update()
	eq(dispatched[1], "loseGame", "left shows the loss")
	screen = fresh()
	net.view = view(nil, { status = "away" })
	screen.update()
	eq(#dispatched, 0, "away shows nothing")
	screen = fresh()
	PVP.GAME.end_shown = "by contest"
	net.view = view(nil, { status = "out" })
	screen.update()
	eq(#dispatched, 0, "a contested game keeps its own screen")
	-- Teams: out (a forfeit, or the team's lives gone) is no end; the team's result is, a win for them too
	local function team_view(result, status)
		local v = view(result, { status = status or "out", team = "A" }, "run1", { status = "playing", team = "A" })
		v.match.run.teamLives = { A = 0, B = 2 }
		return v
	end
	screen = fresh()
	net.view = team_view(nil)
	screen.update()
	screen.update()
	eq(#dispatched, 0, "teams: a forfeiter sees no end screen before the result")
	eq(PVP.GAME.end_shown, "not yet", "and the end is not marked handled")
	eq(count("endGame"), 1, "but their endGame still goes out")
	net.view = team_view({ kind = "win", winners = { "a", "b" }, rated = false })
	screen.update()
	eq(dispatched[1], "winGame", "teams: their team's win shows the win")
	eq(#dispatched, 1, "once")
	screen = fresh()
	net.view = team_view(nil, "left")
	screen.update()
	eq(dispatched[1], "loseGame", "teams: a leaver still loses at once")
	screen = fresh()
	net.view = view({ kind = "win", rated = true }, { status = "out" })
	screen.update()
	eq(#dispatched, 0, "a win that names no winners shows no screen")

	-- the pending death is cleared when the end shows
	screen = fresh()
	net.view = view({ kind = "draw" })
	screen.update()
	eq(pending_ended, 1, "showing the end clears a pending death")

	-- a practice game shows and sends nothing
	screen = fresh()
	PVP.PRACTICE.is_on = function() return true end
	net.view = view({ kind = "win", winners = { "a" } }, { status = "out" })
	screen.update()
	eq(#dispatched, 0, "practice shows no end")
	eq(#sent, 0, "and sends nothing")

	-- the markers belong to the game on screen: the same run loaded again in the same process starts over
	screen = fresh()
	net.view = view({ kind = "win", winners = { "b" }, rated = true }, { status = "out" })
	screen.update()
	screen.forfeit()
	eq(#dispatched, 1, "the end shows")
	eq(count("endGame"), 1, "my endGame goes")
	eq(count("forfeit"), 1, "and my forfeit")
	screen.update()
	screen.forfeit()
	eq(#dispatched + count("endGame") + count("forfeit"), 3, "nothing again in the same game, also after a reconnect")
	G.GAME = { pvp_net = { runId = "run1" } }
	PVP.GAME = { end_shown = "not yet", stats = { reroll_count = 2, reroll_cost_total = 9 } }
	screen.update()
	screen.forfeit()
	eq(#dispatched, 2, "a reloaded game shows the end of the same run again")
	eq(count("endGame"), 2, "sends its endGame again")
	eq(count("forfeit"), 2, "and can forfeit again")

	-- another run's players are not carried over
	screen = fresh()
	net.view = view({ kind = "draw" }, { status = "out" }, "run1", { status = "out", endGame = { jokers = "j_a", deck = "D-3" } })
	screen.update()
	eq(refreshed, 1, "their end in the first run refreshes")
	G.GAME.pvp_net.runId = "run2"
	net.view = view({ kind = "draw" }, { status = "out" }, "run2", { status = "out", endGame = { jokers = "j_a", deck = "D-3" } })
	screen.update()
	eq(refreshed, 2, "the same player's end in the next run refreshes again")

	-- the Forfeit button presses: one forfeit per run, however often it is pressed
	screen = fresh()
	net.view = view(nil)
	screen.forfeit()
	screen.forfeit()
	eq(count("forfeit"), 1, "a second press sends nothing more")
	net.view = view(nil, { status = "out" })
	screen.forfeit()
	eq(count("forfeit"), 1, "pressed while out: still once")

	-- vote progress in chat
	local function with_votes(votes, run_id)
		local v = view(nil, nil, run_id)
		v.match.run.votes = votes
		return v
	end
	screen = fresh()
	net.view = with_votes({ draw = { "a" }, seed = {} })
	screen.update()
	eq(#chat, 0, "the first view prints nothing, however many votes it holds")
	net.view = with_votes({ draw = { "a", "b" }, seed = {} })
	screen.update()
	screen.update()
	eq(#chat, 1, "a new vote prints one line")
	eq(chat[1], "t:k_draw_vote: 2/2", "with the topic's words and the count")
	net.view = with_votes({ draw = { "a", "b" }, seed = { "b" } })
	screen.update()
	eq(chat[2], "t:k_seed_vote: 1/2", "a seed vote has its own words")
	playing_back = true
	net.view = with_votes({ draw = { "a", "b" }, seed = { "a", "b" } })
	screen.update()
	eq(#chat, 2, "a replay prints nothing")
	playing_back = false
	screen.update()
	eq(#chat, 2, "and the count it moved is not printed after it")
	G.GAME = { pvp_net = { runId = "run1" } }
	net.view = with_votes({ draw = { "a" }, seed = {} })
	screen.update()
	net.view = with_votes({ draw = { "a", "b" }, seed = {} })
	eq(#chat, 2, "a load starts silent")
	screen.update()
	eq(#chat, 3, "and counts from there")

	-- the best score
	screen = fresh()
	net.view = view(nil)
	eq(screen.best_score_of("a"), nil, "no blind yet: unknown")
	net.view.match.run.finishedPvpBlinds = { { scores = { a = "40", b = "90" } }, { scores = { a = "70" } } }
	eq(screen.best_score_of("a"), "70", "my best from the view")
	eq(screen.best_score_of("b"), "90", "another's best from the view")

	-- a rejoin or load into a match that already ended
	screen = fresh()
	net.view = view({ kind = "win", winners = { "b" }, rated = true }, { status = "out", place = 2 })
	screen.update()
	eq(dispatched[1], "loseGame", "the first view of an ended match shows its end")
	eq(count("endGame"), 1, "and sends my endGame")
	screen.update()
	eq(#dispatched, 1, "once")
	eq(count("endGame"), 1, "once")

	-- the pending result of another run does not show
	screen = fresh()
	net.view = view({ kind = "win", winners = { "a" } }, nil, "run1")
	screen.update()
	PVP.GAME.end_shown = "not yet"
	G.GAME.pvp_net.runId = "run2"
	net.view = view({ kind = "draw" }, nil, "run2")
	screen.update()
	eq(dispatched[2], "drawGame", "a later run shows its own end")

	-- a new game meeting the old run's view shows nothing and marks nothing; its own result shows once
	screen = fresh()
	net.view = view({ kind = "win", winners = { "b" }, rated = true }, { status = "out" }, "run1")
	screen.update()
	eq(#dispatched, 1, "the first game's end shows")
	G.GAME = { pvp_net = { runId = "run2" } }
	PVP.GAME = { end_shown = "not yet", stats = { reroll_count = 0, reroll_cost_total = 0 } }
	screen.update()
	screen.update()
	eq(#dispatched, 1, "a new game on the old run's view shows no end")
	eq(PVP.GAME.end_shown, "not yet", "and marks nothing handled")
	eq(count("endGame"), 1, "and sends no endGame")
	net.view = view({ kind = "win", winners = { "a" }, rated = true }, nil, "run2")
	screen.update()
	screen.update()
	eq(dispatched[2], "winGame", "its own result shows later")
	eq(#dispatched, 2, "once")
	eq(count("endGame"), 2, "with its own endGame")
	screen = fresh()
	G.GAME = {}
	net.view = view({ kind = "draw" })
	screen.update()
	eq(#dispatched + #sent, 0, "a game with no record of a run shows and sends nothing")

	-- other players' jokers and decks
	screen = fresh()
	net.view = view({ kind = "draw" }, { status = "out" })
	screen.update()
	eq(refreshed, 0, "no one else has sent anything: no refresh")
	eq(screen.jokers_of("b"), nil, "their jokers are unknown")
	eq(screen.deck_of("b"), nil, "and their deck")
	net.view = view({ kind = "draw" }, { status = "out" }, "run1", { status = "out", endGame = { jokers = "j_a,j_b", deck = "D-3" } })
	screen.update()
	eq(refreshed, 1, "their end of game refreshes the open screen")
	eq(#screen.jokers_of("b"), 2, "their jokers are read from the view")
	eq(screen.jokers_of("b")[2].key, "j_b", "in order")
	eq(screen.deck_of("b"), "D-3", "and their deck")
	screen.update()
	eq(refreshed, 1, "once")
	eq(screen.jokers_of("a")[1].key, "j_joker", "mine are read from my game, not the view")
	net.view = view({ kind = "draw" }, { status = "out" }, "run1", { status = "out", endGame = { jokers = "", deck = "" } })
	eq(screen.jokers_of("b"), nil, "empty jokers are unknown")
	eq(screen.deck_of("b"), nil, "an empty deck is unknown")

	-- back in the lobby: the other player's jokers, deck and best score come from the game that ended
	screen = fresh()
	local ended_game = view({ kind = "draw" }, { status = "out" }, "run1", { status = "out", endGame = { jokers = "j_a,j_b", deck = "D-3" } })
	ended_game.match.run.finishedPvpBlinds = { { scores = { a = "40", b = "90" } } }
	net.view = { me = "a", match = { stage = "lobby", lobby = {}, ended = ended_game }, players = { a = { status = "lobby" }, b = { status = "lobby" } } }
	eq(#screen.jokers_of("b"), 2, "in the lobby the other player's jokers are read from the ended game")
	eq(screen.deck_of("b"), "D-3", "and their deck")
	eq(screen.best_score_of("b"), "90", "and their best score")
	eq(screen.jokers_of("a")[1].key, "j_joker", "mine are still from my game")

	-- a player's deck: mine is not the view's to give
	screen = fresh()
	net.view = view({ kind = "draw" }, { status = "out" }, "run1", { status = "out", endGame = { jokers = "", deck = "D-3;H-4" } })
	eq(screen.deck_of("b"), "D-3;H-4", "another player's deck is read from the view")
	eq(screen.deck_of("c"), nil, "a player the view does not list has none")
	net.view = view(nil)
	eq(screen.deck_of("b"), nil, "no end of game in the view: no deck")
	net.view = nil
	eq(screen.deck_of("b"), nil, "no view: no deck")

	-- my jokers go up on leaving a shop
	screen = fresh()
	net.view = view(nil)
	screen.send_jokers()
	eq(count("jokers"), 1, "leaving a shop sends my jokers")
	eq(sent[1].body.jokers, "j_joker", "as the encoded list of my jokers")
	screen.send_jokers()
	eq(count("jokers"), 2, "each shop exit sends them again")
	playing_back = true
	screen.send_jokers()
	eq(count("jokers"), 2, "a replay sends nothing")
	playing_back = false
	send_works = false
	eq(screen.send_jokers(), nil, "an input the net cannot take is not counted as sent")
	send_works = true
	local held = G.jokers.cards
	G.jokers.cards = {}
	local before = count("jokers")
	screen.send_jokers()
	eq(count("jokers"), before, "no jokers text is not sent")
	eq(#warnings, 1, "and says so in the log")
	G.jokers.cards = held

	-- a player who is still playing shows the jokers they sent last; their endGame replaces them
	screen = fresh()
	net.view = view({ kind = "draw" }, { status = "out" }, "run1", { status = "playing", jokers = "j_a" })
	screen.update()
	eq(refreshed, 1, "their newest jokers refresh the open end screen")
	eq(screen.jokers_of("b")[1].key, "j_a", "and are what the screen shows for them")
	eq(screen.deck_of("b"), nil, "their deck is unknown")
	screen.update()
	eq(refreshed, 1, "once")
	net.view = view({ kind = "draw" }, { status = "out" }, "run1", { status = "playing", jokers = "j_a,j_b" })
	screen.update()
	eq(refreshed, 2, "newer jokers refresh it again")
	eq(#screen.jokers_of("b"), 2, "and show")
	net.view = view({ kind = "draw" }, { status = "out" }, "run1", { status = "out", endGame = { jokers = "j_end", deck = "D-3" } })
	screen.update()
	eq(refreshed, 3, "their endGame refreshes it again")
	eq(screen.jokers_of("b")[1].key, "j_end", "and replaces the jokers")
	eq(screen.deck_of("b"), "D-3", "with their deck")
end

-- ui/game/game_end.lua: the rank line of the end screen, by what the result said.
do
	T.fresh()
	G = { FUNCS = { exit_overlay_menu = function() end }, UIDEF = {} }
	create_UIBox_game_over = function() end
	create_UIBox_win = function() end
	Game = { delete_run = function() end }
	MPAPI = {}
	PVP = { UI = { end_screen = {} }, GAME = {}, MATCH_PLAYERS = { State = { ROSTER = 1, LEFT = 2, PLAYING = 3 } } }
	localize = function(key) return "text:" .. key end
	dofile("ui/game/game_end.lua")

	local function line(rank)
		PVP.GAME.end_rank = rank
		return PVP.UI.end_info_line()
	end

	eq(line("counts").text, "text:k_pvp_game_counts", "a game that counts says so")
	eq(line("not_counted").text, "text:k_pvp_game_unrated", "a game that does not count says so")
	eq(line("not_counted").scale, 0.4, "the casual line keeps its size")
	eq(line("not_counted").padding, 0.05, "and its padding")
	eq(line("counts").scale < line("not_counted").scale, true, "the new ranked line is the compact one")
	eq(line("unsaid"), nil, "a result that did not say shows no line")
	eq(line(nil), nil, "no result shows no line")
end

T.done("finish_test")
