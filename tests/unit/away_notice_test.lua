-- Run from the repo root: luajit tests/unit/away_notice_test.lua
-- pvp_api/away_reader.lua + away_screen.lua: while another player is away and the server holds the
-- countdowns, one banner names them; it goes the frame the view says they are back.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local boxes, players = {}, { { id = "me", displayName = "Me" }, { id = "b", displayName = "Bea" }, { id = "c" } }
local driving, practice = false, false
G = {
	STAGES = { RUN = 2 },
	STAGE = 2,
	ROOM_ATTACH = {},
	UIT = { ROOT = 1, C = 2, R = 3, T = 4 },
	C = { CLEAR = {}, RED = {}, UI = { TEXT_LIGHT = {} } },
}
Game = { update = function() end }
function UIBox(spec)
	local box = { definition = spec.definition, config = spec.config, removed = false }
	function box:remove() self.removed = true self.REMOVED = true end
	boxes[#boxes + 1] = box
	return box
end
function localize(arg)
	if type(arg) == "table" then return arg.key .. ":" .. table.concat(arg.vars, "|") end
	return arg == "k_pvp_player_unknown_name" and "????" or arg
end
function sendWarnMessage() end
MPAPI = {
	get_current_lobby = function() return { get_players = function() return players end } end,
	playback = { is_driving = function() return driving end },
}
PVP = {
	match_net = {},
	in_session = function() return true end,
	is_practice_mode = function() return practice end,
}
local now = 500
love = { timer = { getTime = function() return now end } }
dofile("pvp_api/_view.lua")
dofile("pvp_api/away_reader.lua")
dofile("pvp_api/reconnect_screen.lua")
dofile("pvp_api/away_screen.lua")
local reader, screen = PVP.away_reader, PVP.away_screen


-- opponents: the ids the view names as my opponents; statuses: id -> status, or { status =, team = }
local function view(pauses, statuses, opponents)
	local list = { me = { status = "playing" } }
	for id, status in pairs(statuses or {}) do
		list[id] = type(status) == "table" and status or { status = status }
	end
	return {
		me = "me",
		match = { stage = "run", run = { targets = { opponents = opponents or { "b" } } } },
		players = list,
		timers = { deadlines = {}, pauses = pauses },
	}
end
local function away(...) return { { reason = "away", players = { ... }, endsAt = 1 } } end

-- The reader
local ids, held = reader.away_players(view(away("b"), { b = "away" }))
eq(#ids, 1, "one opponent away")
eq(ids[1], "b", "which one")
eq(held, true, "a pause names them: the timers are held")
ids, held = reader.away_players(view({}, { b = "away" }))
eq(ids[1], "b", "away with no pause is still shown")
eq(held, false, "and the timers are not held")
ids, held = reader.away_players(view(away("c"), { b = "away", c = "away" }, { "b", "c" }))
eq(#ids, 2, "two away")
eq(held, true, "one held is enough")
ids, held = reader.away_players(view(away("c"), { b = "away", c = "playing" }))
eq(held, false, "a pause naming someone who is not away holds nothing here")
eq(reader.away_players(view(away("b"), { b = "playing" })), nil, "pause but the view says playing: nobody")
eq(reader.away_players(view(away("b"), {})), nil, "no status is not away")
eq(reader.away_players(view(away("b"), { b = "left" })), nil, "a player who left is not away")
eq(reader.away_players(view(away("b"), { b = "out" })), nil, "nor one who is out")
eq(reader.away_players(view({}, { c = "away" })), nil, "away but not my opponent: nobody")
ids, held = reader.away_players(view(away("c"), { c = "away" }, {}))
eq(ids[1], "c", "a player an away pause names is shown though not my opponent")
eq(held, true, "and the timers are held")
eq(reader.away_players(view(away("c"), { c = "left" }, {})), nil, "a named player who left is not shown")
eq(reader.away_players(view(away("me"), { me = { status = "away" } }, {})), nil, "never me, even when named")
for _, stage in ipairs({ "lobby", "setup", "ended" }) do
	local over = view(away("b"), { b = "away" })
	over.match.stage = stage
	eq(reader.away_players(over), nil, "no banner in stage " .. stage)
end
local no_stage = view(away("b"), { b = "away" })
no_stage.match.stage = nil
eq(reader.away_players(no_stage), nil, "unknown stage: nobody")
eq(reader.away_players(view({}, { b = "away" }, {})), nil, "no opponents: nobody")
eq(reader.away_players(view({ { reason = "animating", players = { "b" }, endsAt = 1 } }, { b = "away" })) ~= nil, true, "an animating pause does not hide an away status")
ids, held = reader.away_players(view({ { reason = "animating", players = { "b" }, endsAt = 1 } }, { b = "away" }))
eq(held, false, "but is not an away hold")
local mine = view({}, { me = { status = "away" }, b = "playing" })
eq(reader.away_players(mine), nil, "my own absence is not shown to me")
-- Teams: a teammate counts, a player on the other team who is not my opponent does not
local teams = view({}, { c = { status = "away", team = "A" }, d = { status = "away", team = "B" } }, { "e" })
teams.players.me.team = "A"
ids = reader.away_players(teams)
eq(#ids, 1, "a teammate is shown")
eq(ids[1], "c", "the teammate, not the other team")
teams.players.me.team = nil
eq(reader.away_players(teams), nil, "no team of mine: no teammates, never a guess")
eq(reader.away_players(nil), nil, "no view: nobody")
eq(reader.away_players({ me = "me" }), nil, "no players: nobody")
eq(reader.away_players({ players = { b = { status = "away" } } }), nil, "me unknown: nobody")
eq(reader.names_line({ "b", "c" }, function(id) return id == "b" and "Bea" or nil end, "unknown"), "Bea, unknown", "an unknown name is the given one")

-- The screen
local function title(box) return box.definition.nodes[1].nodes[1].nodes[1].config.text end
PVP.match_net.view = view(away("b"), { b = "away" })
screen.update()
eq(#boxes, 1, "the banner opens")
eq(title(boxes[1]), "k_pvp_player_away:Bea", "it names the player")
eq(#boxes[1].definition.nodes[1].nodes, 2, "with a second line")
eq(boxes[1].definition.nodes[1].nodes[2].nodes[1].config.text, "k_pvp_timers_held", "that says the timers are held")
screen.update()
eq(#boxes, 1, "the same notice is not opened twice")
PVP.match_net.view = view({}, { b = "away" })
screen.update()
eq(#boxes, 2, "the pause ends but they are still away: a new banner")
eq(boxes[1].removed, true, "the old one is removed")
eq(title(boxes[2]), "k_pvp_player_away:Bea", "still names them")
eq(#boxes[2].definition.nodes[1].nodes, 1, "without the timers line")
PVP.match_net.view = view({}, { b = "away", c = "away" }, { "b", "c" })
screen.update()
eq(#boxes, 3, "a different set of players is a new banner")
eq(boxes[2].removed, true, "the old one is removed")
eq(title(boxes[3]), "k_pvp_player_away:Bea, ????", "both named")
PVP.match_net.view = view({}, { b = "playing", c = "playing" }, { "b", "c" })
screen.update()
eq(boxes[3].removed, true, "the view says they are back: the banner goes")
screen.update()
eq(#boxes, 3, "nothing more opens")

PVP.match_net.view = view(away("b"), { b = "away" })
driving = true
screen.update()
eq(#boxes, 3, "a playback shows none")
driving = false
G.STAGE = 1
screen.update()
eq(#boxes, 3, "outside a run shows none")
G.STAGE = 2
screen.update()
eq(#boxes, 4, "back in the run it shows")
PVP.match_net.view = nil
screen.update()
eq(boxes[4].removed, true, "no view: the banner goes")


-- A rebuilt room or a removed box brings the banner back though nothing else changed.
PVP.match_net.view = view({}, { b = "away" })
screen.update()
local before = #boxes
screen.update()
eq(#boxes, before, "nothing changed: no rebuild")
G.ROOM = {}
screen.update()
eq(#boxes, before + 1, "a new room: the banner is rebuilt")
boxes[#boxes].REMOVED = true
screen.update()
eq(#boxes, before + 2, "a removed box: the banner is rebuilt")

-- The countdown to the forfeit comes from the lobby roster, on the banner.
local function lines(box) return box.definition.nodes[1].nodes end
local function clock_text(box) return lines(box)[2].nodes[1].config.ref_table.text end
players = { { id = "me", displayName = "Me" }, { id = "b", displayName = "Bea", forfeits_at_local = now + 102 }, { id = "c" } }
PVP.match_net.view = view({}, { b = "away" })
screen.update()
local banner = boxes[#boxes]
eq(#lines(banner), 2, "a known forfeit time adds a countdown line")
eq(clock_text(banner), "k_pvp_player_reconnecting_timed:Bea|1:42", "it reads the roster's time")
now = now + 42
local count = #boxes
screen.update()
eq(#boxes, count, "the countdown ticks without a rebuild")
eq(clock_text(banner), "k_pvp_player_reconnecting_timed:Bea|1:00", "and counts down")
players[2].forfeits_at_local = nil
screen.update()
eq(#lines(boxes[#boxes]), 1, "no time from the server: no countdown line")
PVP.match_net.view = view(away("b"), { b = "away" })
players[2].forfeits_at_local = now + 30
screen.update()
eq(#lines(boxes[#boxes]), 3, "title, countdown and the timers line")
eq(screen.in_run(), true, "in a run the banner owns the line")
G.STAGE = 1
eq(screen.in_run(), false, "outside a run it does not")
G.STAGE = 2

print(string.format("away_notice_test: ok (%d checks)", checks))
