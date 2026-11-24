-- Run from the repo root: luajit tests/unit/finish_screen_test.lua
-- pvp_api/finish_screen.lua: votes, forfeit and endGame go out once and never from a replay; the end of
-- the match is shown once, only when the view says so, also after a rejoin; other players' jokers and
-- decks come from the view. A stub net records send(kind, body).
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

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

-- As the screens tick does each frame: follow the run, then update.
local function ticked(screen)
	local update = screen.update
	screen.update = function()
		PVP.view.follow_run(PVP.match_net.view)
		return update()
	end
	return screen
end

local function fresh()
	sent, dispatched, refreshed, chat, pending_ended, warnings = {}, {}, 0, {}, 0, {}
	playing_back, waiting_for, send_works = false, {}, true
	net.view = nil
	PVP = {
		match_net = net,
		GAME = { end_shown = "not yet", stats = { reroll_count = 2, reroll_cost_total = 9 } },
		UTILS = { card_to_string = function(card) return card.name end },
		UI = {
			refresh_end_game_jokers = function() refreshed = refreshed + 1 end,
		},
		Score = { greater = function(a, b) return tonumber(a) > tonumber(b) end },
		in_session = function() return true end,
		is_practice_mode = function() return false end,
		end_pending_death = function() pending_ended = pending_ended + 1 end,
		game_effects = {
			win = function() dispatched[#dispatched + 1] = "winGame" end,
			lose = function() dispatched[#dispatched + 1] = "loseGame" end,
			draw = function() dispatched[#dispatched + 1] = "drawGame" end,
		},
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
	dofile("pvp_api/_view.lua")
	dofile("pvp_api/run_reader.lua")
	dofile("pvp_api/finish_reader.lua")
	dofile("pvp_api/finish_screen.lua")
	return ticked(PVP.finish_screen)
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
PVP.is_practice_mode = function() return true end
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

print(string.format("finish_screen_test: ok (%d checks)", checks))
