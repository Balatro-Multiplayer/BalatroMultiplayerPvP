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
