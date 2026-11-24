-- Run from the repo root: luajit tests/unit/pvp_blind_screen_test.lua
-- pvp_api/pvp_blind_screen.lua: when the game takes its hands from the server, when blindStart goes out,
-- handScored only from a real PvP blind, and the timer-out text. A stub net records send(kind, body).
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

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
	match_net = net,
	GAME = { enemy = {} },
	Score = {
		ZERO = "0",
		from_game_value = function(value) return tostring(value) end,
		to_game_value = function(text) return tonumber(text) end,
	},
	in_session = function() return true end,
	is_practice_mode = function() return false end,
	is_pvp_boss = function() return on_boss end,
	game_effects = {
		show_enemy_location = function() end,
		show_lives = function() end,
		end_pvp_blind = function() end,
		start_pvp_blind = function() end,
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

dofile("pvp_api/_view.lua")
dofile("pvp_api/entry_reader.lua")
dofile("pvp_api/pvp_blind_reader.lua")
dofile("pvp_api/pvp_blind_screen.lua")
local screen = PVP.pvp_blind_screen
PVP.GAME.hands_source = { kind = "game" }

-- What a load and a fresh entry set (lib/run_save.lua, entry_screen.lua).
local function take_hands_from_server() PVP.GAME.hands_source = PVP.pvp_blind_reader.hands_source_loaded() end
local function blind_start_at_first_hand()
	local key = PVP.view.entry_key(G.GAME.pvp_net.runId, PVP.view.pvp_blind_key(G.GAME.round_resets.ante))
	PVP.GAME.hands_source = PVP.pvp_blind_reader.hands_source_entered("fresh", key)
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
PVP.game_effects.show_lives = function(lives)
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
PVP.view.forget("pvp_blind ")
local locations, eased = {}, {}
PVP.game_effects.show_enemy_location = function(location) locations[#locations + 1] = location end
PVP.current_ruleset = function() return {} end
PVP.UI = { ease_enemy_score = function(score) eased[#eased + 1] = score end }
PVP.Score.greater = function(a, b) return b == nil or tonumber(a) > tonumber(b) end
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
PVP.view.follow_run(net.view)
screen.update()
eq(#locations, 5, "the next game does not show Selecting from the last game's Ready")

print(string.format("pvp_blind_screen_test: ok (%d checks)", checks))
