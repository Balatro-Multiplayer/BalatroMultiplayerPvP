-- Run from the repo root: lua5.4 tests/unit/queue_hud_test.lua
-- The queue HUD's pure text helpers, loaded with minimal game stubs.
local function noop() end
love = { timer = { getTime = function() return 0 end } }
Game = { update = noop, start_run = noop }
G = {}
PVP = {}
MPAPI = {
	register_card_info_provider = noop,
	ui_element = function() return { update = noop } end,
	matchmaking = {
		RANKED_SPREAD_INITIAL = 150,
		RANKED_SPREAD_EXPAND_RATE = 50,
		RANKED_SPREAD_EXPAND_SECS = 30,
		RANKED_SPREAD_CAP = 600,
	},
}
localize = function(args)
	if type(args) == "table" then
		return args.key .. ":" .. table.concat(args.vars, ",")
	end
	return args
end
dofile("ui/game/card_info_provider.lua")
dofile("ui/queue_hud.lua")
local Q = PVP.QUEUE_HUD

local function eq(got, want, what)
	if got ~= want then
		error(what .. ": got " .. tostring(got) .. ", want " .. tostring(want), 2)
	end
end

eq(Q.format_elapsed(0), "0:00", "elapsed at start")
eq(Q.format_elapsed(65.9), "1:05", "elapsed rounds down")
eq(Q.format_elapsed(-3), "0:00", "elapsed never negative")

local step, total = Q.search_step(150)
eq(step, 1, "first step")
eq(total, 10, "step count from +-150 to +-600 by 50")
eq((Q.search_step(600)), 10, "last step at the cap")
assert(Q.spin_for(150) < Q.spin_for(400), "the swirl spins up as the search widens")
eq(Q.spin_for(600), Q.spin_for(10000), "the swirl stops speeding up at the cap")

-- The fan: a finished riffle leaves every card exactly where the next resting fan puts it, so
-- reordering the cards after it doesn't jump.
do
	local n, f, close = 5, 0.5, function(a, b) return math.abs(a - b) < 1e-9 end
	for i = 1, n do
		local x, _, r = Q.fan_pose(i, n, f, 0, 1, true)
		local j = i == n and 1 or i + 1 -- where the card sits after the reorder
		local rx, _, rr = Q.fan_pose(j, n, f, 0, nil, true)
		assert(close(x, rx) and close(r, rr), "riffle lands card " .. i .. " on slot " .. j)
	end
	local _, y_top = Q.fan_pose(n, n, f, 0, 0.5, true)
	local _, y_rest = Q.fan_pose(n, n, f, 0, nil, true)
	assert(y_top < y_rest, "the riffling card lifts over the fan")
	local wide = Q.fan_pose(1, n, 1, 0, nil, true)
	local tight = Q.fan_pose(1, n, 0, 0, nil, true)
	assert(wide < tight, "the fan opens up as the search widens")
end

local placed = { rating = 1432, isPlacement = false, gamesPlayed = 9, rank = 42 }
local placing = { rating = 640, isPlacement = true, gamesPlayed = 2, placementGames = 5 }
eq(Q.range_text(nil, 150), "...", "range before the rating is read")
eq(Q.range_text(placed, 200), "1232-1632", "range around a placed rating")
eq(Q.range_text(placing, 250), "k_pvp_queue_widening:3,10", "a placing player's range hides the rating")

local elo, rank = Q.card_lines(placed)
eq(elo, "Elo 1432", "placed card Elo")
eq(rank, "#42", "placed card rank")
elo, rank = Q.card_lines(placing)
eq(elo, "k_pvp_placement_progress:2/5", "placing card progress")
eq(rank, "k_pvp_rank_after_placements", "placing card rank line")
eq((Q.card_lines(nil)), "...", "card before the rating is read")
eq((Q.card_lines({ unknown = true })), "", "card whose rating could not be read")

print("queue_hud_test: ok")

-- Smoke: drive queue -> widen -> match -> lobby -> run against stub engine objects, running every
-- delayed event at once, to catch nil indexing in the HUD and reveal paths.
do
	local clock = 0
	love.timer.getTime = function() return clock end
	love.window = { requestAttention = noop }
	local boxes = {}
	local function element()
		return { config = { object = { pulse = noop } }, juice_up = noop }
	end
	UIBox = function(args)
		local b = { alignment = { offset = args.config.offset }, UIRoot = { juice_up = noop }, removed = false }
		function b:align_to_major() end
		function b:remove() self.removed = true end
		function b:get_UIE_by_ID() return element() end
		boxes[#boxes + 1] = b
		return b
	end
	DynaText = function() return {} end
	local function moveable(w, h)
		return { T = { x = 0, y = 0, w = w or 1, h = h or 1, r = 0 }, states = { drag = {}, hover = {} }, juice_up = noop, remove = noop }
	end
	CardArea = function(_, _, w, h)
		local a = moveable(w, h)
		a.cards = {}
		function a:emplace(card) self.cards[#self.cards + 1] = card end
		return a
	end
	Card = function(_, _, w, h) return moveable(w, h) end
	Particles = function() return { remove = noop } end
	UIBox_button = function() return {} end
	Event = function(e) return e end
	mix_colours = function(a) return a end
	play_sound = noop
	sendWarnMessage = function(msg) error(msg) end
	G = {
		UIT = { ROOT = 0, R = 1, C = 2, T = 3, O = 4 },
		C = setmetatable({ UI = setmetatable({}, { __index = function() return {} end }) }, { __index = function() return {} end }),
		ROOM = { jiggle = 0 },
		ROOM_ATTACH = {},
		ARGS = { spin = { real = 0 } },
		CARD_W = 2, CARD_H = 2.7,
		P_CARDS = { S_A = {} },
		P_CENTERS = { c_base = {}, b_red = { pos = {} } },
		SETTINGS = {},
		E_MANAGER = { add_event = function(_, e) if e.trigger == "after" then e.func() end end },
	}
	PVP.LobbyAccess = { RANKED = "ranked", CASUAL = "casual" }
	PVP.ruleset_display_name = function() return "Balanced" end
	PVP.ranked_ticket = function(key) return "ranked:pvp_ranked_" .. key end
	PVP.PVP_GAMEMODES = {}
	PVP.id = "MultiplayerPvP"
	MPAPI.matchmaking.ranked_spread = function(t)
		return math.min(150 + math.floor(t / 30) * 50, 600)
	end
	MPAPI.matchmaking.get_rating = function(_, _, _, player_id, cb)
		cb(nil, { rating = player_id == "opp" and 1500 or 1432, isPlacement = false, rank = 7 })
	end
	MPAPI.matchmaking.get_queue_counts = function(_, cb) cb(nil, { ["ranked:pvp_ranked_balanced"] = { queued = 6 } }) end

	Q.start({ kind = "ranked", key = "balanced" })
	eq(Q.active, true, "queue HUD starts")
	Game.update({}, 0)
	eq(Q.in_queue, 6, "queue count read on the first frame")
	local spin_at_start = G.ARGS.spin.real
	clock = 95
	Game.update({}, 0)
	eq(Q.spread, 300, "range widened after 95 s")
	assert(G.ARGS.spin.real > spin_at_start, "the swirl spun up with the range")
	eq(#Q.fan.area.cards, 5, "the fan has its card backs")
	local top = Q.fan.area.cards[5]
	clock = 95 + 1.2
	Game.update({}, 0) -- a riffle starts
	clock = 95 + 1.2 + 0.5
	Game.update({}, 0) -- and finishes
	eq(Q.fan.area.cards[1], top, "the riffled top card went to the bottom")

	Q.match_found()
	eq(Q.active, false, "HUD stops on a match")
	assert(Q.rv and Q.rv.left and Q.rv.right and Q.rv.vs, "reveal dealt both cards and VS")
	local players = { { id = "me", displayName = "Me" } }
	local lobby = { player_id = "me", get_players = function() return players end }
	Q.lobby_ready(lobby)
	Game.update({}, 0)
	players[2] = { id = "opp", displayName = "Rival" }
	Game.update({}, 0)
	eq(Q.reveal_ratings.opp.rating, 1500, "opponent rating read once they joined")

	Game.start_run({}, {})
	eq(Q.rv, nil, "the run starting ends the reveal")
	eq(G.ARGS.spin.real, 0, "the swirl's spin is put back")
	print("queue_hud_test smoke: ok")
end
