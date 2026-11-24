-- Run from the repo root: luajit tests/unit/finish_reader_test.lua
-- pvp_api/finish_reader.lua: the bodies of vote, forfeit and endGame, what each kind of result means
-- for me, the shown-once marker, when my endGame is due, and another player's end of game.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

PVP = {}
dofile("pvp_api/_view.lua")
dofile("pvp_api/finish_reader.lua")
local reader = PVP.finish_reader

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
eq(PVP.view.game(running), running, "a running game: its own view")
local lobby = { me = "a", match = { stage = "lobby", result = nil, run = nil, lobby = {}, ended = running }, players = {} }
eq(PVP.view.game(lobby), running, "the lobby: the game that ended")
eq(reader.my_end(PVP.view.game(lobby)).screen, "win", "so the win still shows after the lobby view arrives")
eq(PVP.view.game({ me = "a", match = { stage = "lobby", lobby = {} }, players = {} }), nil, "a lobby with no ended game: none")
eq(PVP.view.game(nil), nil, "no view: none")

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

print(string.format("finish_reader_test: ok (%d checks)", checks))
