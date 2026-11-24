-- Run from the repo root: luajit tests/unit/entry_screen_test.lua
-- pvp_api/entry_screen.lua: a PvP blind is entered once per game (G.GAME), socket rejoins included; a loaded game enters again. A rejoin
-- forgets the view for a moment (match_net.on_join); the countdown already running must not get a twin,
-- or both run select_blind and the second finds no blind select.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

PVP = { GAME = {}, UI = {} }
dofile("pvp_api/_view.lua")
dofile("pvp_api/entry_reader.lua")

local net = { view = nil }
function net.waiting() return false end
local pending
function net.latest_waiting() return pending end
function net.add_view_listener() end
PVP.match_net = net

local starts = 0
PVP.game_effects = { start_pvp_blind = function() starts = starts + 1 end }
PVP.pvp_blind_reader = { hands_source_entered = function() return nil end }
PVP.boss_select_button = function() return {} end
localize = function(key) return key end

G = {
	STAGE = 1,
	STAGES = { RUN = 1 },
	STATE = 7,
	STATES = { BLIND_SELECT = 7 },
	GAME = { pvp_net = { runId = "run1", inboxDone = 4 }, blind_on_deck = "Boss", round_resets = { ante = 2 } },
}

dofile("pvp_api/entry_screen.lua")
local screen = PVP.entry_screen

local function view(run_id, ante)
	ante = ante or 2
	return {
		me = "a",
		players = { a = {}, b = {} },
		onlyMine = { inboxNewest = 4 },
		match = {
			run = {
				id = run_id,
				players = { a = { ante = ante } },
				targets = { myBoss = "plays" },
				currentPvpBlind = { stage = "playing", blindKey = ante .. ":Boss", players = { a = { stage = "not entered" }, b = { stage = "not entered" } } },
			},
		},
	}
end

net.view = view("run1")
screen.update()
eq(starts, 1, "the playing blind is entered")
screen.update()
eq(starts, 1, "the same view again enters nothing")

-- A rejoin: one frame with no view, then the same blind, still "not entered" (blindStart goes after select_blind).
net.view = nil
screen.update()
net.view = view("run1")
screen.update()
eq(starts, 1, "a rejoin does not start a second countdown")

-- A rejoin that loads the Run save at blind select (same process, a new game) enters the blind the server has me in.
local played = G.GAME
G.GAME = { pvp_net = { runId = "run1", inboxDone = 4 }, blind_on_deck = "Boss", round_resets = { ante = 2 } }
local loaded = view("run1")
loaded.match.run.currentPvpBlind.players.a.stage = "entered"
net.view = loaded
screen.update()
eq(starts, 2, "a loaded game enters the blind again")
screen.update()
eq(starts, 2, "and only once")
G.GAME = played
starts = 1

-- The next ante's PvP blind in the same run is its own entry.
G.GAME.round_resets.ante = 3
net.view = view("run1", 3)
screen.update()
eq(starts, 2, "the next ante's blind is entered")

-- A new run's blind is its own entry.
G.GAME.pvp_net.runId = "run2"
G.GAME.round_resets.ante = 2
net.view = view("run2")
screen.update()
eq(starts, 3, "another run's blind is entered")

-- My press on its way: the button shows it, while what the rest of the game reads as my Ready is the server's.
local function waiting_view()
	local v = view("run2")
	v.match.run.currentPvpBlind = { stage = "waiting", blindKey = "2:Boss", players = { a = "not ready", b = "ready" } }
	return v
end
net.view = waiting_view()
pending = { kind = "ready", ready = true, blindKey = "2:Boss" }
screen.update()
eq(PVP.GAME.ready_blind_text, "b_unready", "the button shows the Ready on its way")
eq(PVP.GAME.ready_blind, false, "the game reads the server's Ready")

-- The blind opens on my Ready while my cancel is on its way (the server refuses it): the blind is entered once.
G.GAME.round_resets.ante = 4
pending = { kind = "ready", ready = false, blindKey = "4:Boss" }
net.view = view("run2", 4)
screen.update()
eq(starts, 4, "the opened blind is entered though a cancel is on its way")
screen.update()
eq(starts, 4, "and only once")
pending = nil

print("entry_screen_test: ok (" .. checks .. " checks)")
