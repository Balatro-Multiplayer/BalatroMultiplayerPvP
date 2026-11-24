-- Run from the repo root: luajit tests/unit/pizza_in_shop_test.lua
-- The discard a Pizza gives the loser of a PvP blind shows in the shop, as on main: the item waits
-- out the blind's evaluation screen.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local warnings, queue = {}, {}
sendWarnMessage = function(text) warnings[#warnings + 1] = text end
love = { timer = { getTime = function() return 0 end } }
Event = function(fields) return fields end
G = {
	STAGE = "run",
	STAGES = { RUN = "run" },
	STATES = { BLIND_SELECT = 1, SHOP = 2, SELECTING_HAND = 3, BOOSTER = 9, ROUND_EVAL = 8 },
	STATE = 8,
	STATE_COMPLETE = true,
	GAME = { round_resets = { ante = 1 }, current_round = { discards_left = 0 } },
	E_MANAGER = { add_event = function(_, event) queue[#queue + 1] = event end },
}
PVP = {
	id = "MultiplayerPvP",
	is_pvp_boss = function() return false end,
	GAME = { comeback_bonus = 0, comeback_payout = "none", pizza_discards = 0 },
}
MPAPI = {
	playback = { is_driving = function() return false end },
	get_current_lobby = function() return { mod_id = "MultiplayerPvP" } end,
	send_match_input = function() return true end,
	run_save = { is_staged = function() return false end, save_now = function() end },
}
dofile("pvp_api/_view.lua")
dofile("pvp_api/_match_net_rules.lua")
dofile("pvp_api/match_net.lua")
dofile("pvp_api/inbox_game.lua")
dofile("pvp_api/inbox_handlers.lua")
PVP.match_net.handlers = PVP.inbox_handlers.effects

local pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
G.GAME.pvp_net = pvp_net
PVP.match_net.receive_view(nil, {
	serverTime = 1000,
	lastMessageReceived = 0,
	me = "a",
	match = { run = { id = "run1" } },
	players = {},
	timers = {},
	onlyMine = { inbox = { { itemNumber = 1, effect = "pizza", amount = 1, ante = 1 } }, inboxNewest = 1 },
})
PVP.match_net.update()
for _, event in ipairs(queue) do event.func() end
eq(pvp_net.inboxDone, 0, "the pizza item waits on the evaluation screen")
eq(PVP.GAME.pizza_discards, 0, "and no discard is given there")

-- a shop not yet set up still waits
G.STATE = G.STATES.SHOP
G.STATE_COMPLETE = false
PVP.match_net.update()
eq(pvp_net.inboxDone, 0, "a shop not yet set up does not run it")

G.STATE_COMPLETE = true
PVP.match_net.update()
for _, event in ipairs(queue) do event.func() end
eq(pvp_net.inboxDone, 1, "the pizza item runs in the shop")
eq(PVP.GAME.pizza_discards, 1, "and the discard is given")

print(string.format("pizza_in_shop_test: ok (%d checks)", checks))
