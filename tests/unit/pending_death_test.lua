-- Run from the repo root: luajit tests/unit/pending_death_test.lua
-- pvp_api/ui/pending_death.lua: the screen opens while the view's
-- waitingDeaths lists me, closes when it no longer does, and the survivor notice shows once per death.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local opened, closed, noticed, noticed_key
local practice = false
PVP = {
	NET = {}, READ = {},
	GAME = { end_shown = "not yet" },
	UI = {
		show_pending_death_screen = function()
			opened = opened + 1
			PVP.GAME.pending_death_screen = true
		end,
		show_pending_death_notice = function(key)
			noticed = noticed + 1
			noticed_key = key
		end,
		pending_death = {
			close = function()
				closed = closed + 1
				PVP.GAME.pending_death_screen = false
				PVP.GAME.pending_death = nil
			end,
		},
	},
	LOBBY = { in_session = function() return true end },
	PRACTICE = { is_on = function() return practice end },
}
Game = { update = function() end }
G = { STAGES = { RUN = 1 }, STAGE = 1 }
local playing_back = false
MPAPI = { playback = { is_driving = function() return playing_back end } }
sendWarnMessage = function() end
dofile("pvp_api/read/_view.lua")
dofile("pvp_api/ui/pending_death.lua")
T.ticked(PVP.UI.pending_death)
local reader = PVP.UI.pending_death

local function view_of(waiting)
	return { me = "a", match = { run = { waitingDeaths = waiting } } }
end

-- reader
eq(reader.mine(nil), nil, "no view: unknown")
eq(reader.mine({ me = "a", match = {} }), nil, "no run: unknown")
eq(reader.mine(view_of({})), nil, "none listed")
eq(reader.mine(view_of({ { player = "b", blindKey = "x", waitingFor = { "a" } } })), nil, "another's death is not mine")
eq(reader.mine(view_of({ { player = "a", blindKey = "x", waitingFor = { "b" } } })).blindKey, "x", "mine is found")
eq(reader.wait_key({ waitingFor = { "b" } }), "k_pvp_pending_death_wait", "one to wait for")
eq(reader.wait_key({ waitingFor = { "b", "c" } }), "k_pvp_pending_death_wait_many", "several to wait for")
eq(#reader.waiting_on_me(view_of({ { player = "b", blindKey = "x", waitingFor = { "a" } } })), 1, "a death waits on me")
eq(#reader.waiting_on_me(view_of({ { player = "a", blindKey = "x", waitingFor = { "a" } } })), 0, "my own does not")

-- screen
opened, closed, noticed = 0, 0, 0
PVP.NET = { view = view_of({ { player = "a", blindKey = "x", waitingFor = { "b" } } }) }
PVP.UI.pending_death.update()
eq(opened, 1, "opens while the view lists me")
PVP.UI.pending_death.update()
eq(opened, 1, "opens once")
eq(PVP.GAME.pending_death.blindKey, "x", "the entry is kept for the wait line")
PVP.NET.view = view_of({})
PVP.UI.pending_death.update()
eq(closed, 1, "closes when the view no longer lists me")
PVP.UI.pending_death.update()
eq(closed, 1, "closes once")

PVP.GAME.end_shown = "by result"
PVP.NET.view = view_of({ { player = "a", blindKey = "x", waitingFor = { "b" } } })
PVP.UI.pending_death.update()
eq(opened, 1, "does not open after the result")
PVP.GAME.end_shown = "not yet"

PVP.NET.view = nil
PVP.UI.pending_death.update()
eq(opened + closed, 2, "no view changes nothing")

PVP.NET.view = view_of({ { player = "b", blindKey = "x", waitingFor = { "a" } } })
PVP.UI.pending_death.update()
PVP.UI.pending_death.update()
eq(noticed, 1, "the notice shows once per waiting death")

-- out with no result is the loss screen (pvp_api/ui/finish.lua), not a wait
local function out_view(result, status, waiting)
	local view = view_of(waiting or {})
	view.match.result = result
	view.players = { a = { status = status or "out" }, b = { status = "playing" } }
	return view
end
local listed = { { player = "a", blindKey = "x", waitingFor = { "b" } } }
eq(reader.waiting(out_view(nil)), nil, "out with no result is not a reason to wait")
eq(reader.waiting(out_view(nil, "out", listed)).blindKey, "x", "a listed death still is")

-- Teams: every member is out when the shared lives are gone, one death is listed per team; the whole team waits
local function team_view(waiting)
	local view = view_of(waiting)
	view.players = { a = { status = "out", team = "A" }, b = { status = "playing", team = "A" }, c = { status = "playing", team = "B" } }
	return view
end
local b_waits = { { player = "b", blindKey = "x", waitingFor = { "c" } } }
eq(reader.waiting(team_view(b_waits)).blindKey, "x", "my teammate's death is a reason to wait")
eq(reader.waiting(team_view({ { player = "c", blindKey = "x", waitingFor = { "b" } } })), nil, "the other team's is not")
eq(reader.waiting(view_of(b_waits)), nil, "no teams in the view: a teammate is unknown")
opened, closed = 0, 0
PVP.GAME.pending_death_screen = false
PVP.NET.view = team_view(b_waits)
PVP.UI.pending_death.update()
eq(opened, 1, "teams: the waiting screen opens for the whole team")
PVP.NET.view = team_view({})
PVP.UI.pending_death.update()
eq(closed, 1, "and closes when the death settles")

opened, closed = 0, 0
PVP.GAME.pending_death_screen = false
PVP.NET.view = out_view(nil)
PVP.UI.pending_death.update()
PVP.UI.pending_death.update()
eq(opened, 0, "out with no result opens no waiting screen")

playing_back = true
PVP.NET.view = out_view(nil, "playing", listed)
PVP.UI.pending_death.update()
eq(opened, 0, "never opens during a playback")
playing_back = false
PVP.UI.pending_death.update()
eq(opened, 1, "and opens after it")

-- no screen in a practice run or a contested match, whatever the view lists
opened, closed = 0, 0
PVP.GAME.pending_death_screen = false
PVP.NET.view = view_of({ { player = "a", blindKey = "x", waitingFor = { "b" } } })
practice = true
PVP.UI.pending_death.update()
eq(opened, 0, "practice never opens it")
practice = false
PVP.GAME.end_shown = "by contest"
PVP.UI.pending_death.update()
eq(opened, 0, "a contested match never opens it")
PVP.GAME.end_shown = "not yet"
PVP.UI.pending_death.update()
eq(opened, 1, "and opens without them")

-- the survivor notice: its wording follows the player count, and a death is told once per run
local function players_of(count)
	local players = {}
	for i = 1, count do players["p" .. i] = { status = "playing" } end
	return { players = players }
end
eq(reader.survivor_key(players_of(2)), "k_pvp_pending_death_survivor", "two players end the game")
eq(reader.survivor_key(players_of(3)), "k_pvp_pending_death_survivor_many", "three players settle one death")
eq(reader.survivor_key(players_of(1)), "k_pvp_pending_death_survivor_many", "one player does not promise it")
eq(reader.survivor_key({}), "k_pvp_pending_death_survivor_many", "no player list does not promise it")
eq(reader.survivor_key(nil), "k_pvp_pending_death_survivor_many", "no view does not promise it")

local function waiting_view(run_id, count, entries)
	local view = view_of(entries)
	view.match.run.id = run_id
	view.players = players_of(count).players
	return view
end
local on_me = { { player = "b", blindKey = "x", waitingFor = { "a" } } }
noticed = 0
PVP.NET.view = waiting_view("r1", 2, on_me)
PVP.UI.pending_death.update()
eq(noticed, 1, "a death waiting on me is told")
eq(noticed_key, "k_pvp_pending_death_survivor", "with two players it ends the game")
PVP.NET.view = waiting_view("r1", 2, {})
PVP.UI.pending_death.update()
PVP.NET.view = waiting_view("r1", 2, on_me)
PVP.UI.pending_death.update()
eq(noticed, 1, "a death that leaves the list and returns is not told again")
PVP.NET.view = waiting_view("r2", 3, on_me)
PVP.UI.pending_death.update()
eq(noticed, 2, "a new run tells it again")
eq(noticed_key, "k_pvp_pending_death_survivor_many", "with three players it only settles it")

T.done("pending_death_test")
