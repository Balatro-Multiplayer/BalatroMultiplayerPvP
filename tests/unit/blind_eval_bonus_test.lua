-- Run from the repo root: luajit tests/unit/blind_eval_bonus_test.lua
-- A player who loses a PvP blind on hands is paid the comeback bonus at that blind's cash-out: the
-- evaluate_round wrapper in overrides/game.lua runs the waiting comebackBonus item before the game's
-- own evaluation, which reads comeback_payout.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local warnings, queue = {}, {}
sendWarnMessage = function(text) warnings[#warnings + 1] = text end
love = { timer = { getTime = function() return 0 end } }
Event = function(fields) return fields end
G = {
	STAGE = "run",
	STAGES = { RUN = "run" },
	STATES = { BLIND_SELECT = 1, SHOP = 2, SELECTING_HAND = 3, BOOSTER = 9, ROUND_EVAL = 8 },
	STATE = 8,
	STATE_COMPLETE = false,
	GAME = { round_resets = { ante = 1 } },
	E_MANAGER = { add_event = function(_, event) queue[#queue + 1] = event end },
}
PVP = { NET = {}, READ = {}, UI = {}, id = "MultiplayerPvP", UTILS = { is_pvp_blind = function() return false end }, GAME = { comeback_bonus = 0, comeback_payout = "none" } }
MPAPI = {
	playback = { is_driving = function() return false end },
	get_current_lobby = function() return { mod_id = "MultiplayerPvP" } end,
	send_match_input = function() return true end,
	run_save = { is_staged = function() return false end, save_now = function() end },
}
dofile("pvp_api/read/_view.lua")
dofile("pvp_api/net/_rules.lua")
dofile("pvp_api/net/server_link.lua")
dofile("pvp_api/net/inbox.lua")
PVP.NET.handlers = PVP.NET.inbox.effects

-- the wrapper chunk of overrides/game.lua, loaded with the game's own evaluation stubbed
local file = assert(io.open("overrides/game.lua", "r"))
local text = file:read("*a")
file:close()
local marker = "-- Hook for end of pvp context"
local start = assert(text:find(marker, 1, true), "wrapper not found")
local chunk = text:sub(start)

local seen
G.FUNCS = {
	evaluate_round = function()
		seen = { payout = PVP.GAME.comeback_payout, bonus = PVP.GAME.comeback_bonus }
	end,
}
SMODS = { calculate_context = function() end }
assert((loadstring or load)(chunk))()

local pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
G.GAME.pvp_net = pvp_net
PVP.NET.receive_view(nil, {
	serverTime = 1000,
	lastMessageReceived = 0,
	me = "a",
	match = { run = { id = "run1" } },
	players = {},
	timers = {},
	onlyMine = { inbox = { { itemNumber = 1, effect = "comebackBonus", amount = 3 } }, inboxNewest = 1 },
})
eq(pvp_net.inboxDone, 0, "the item has not run yet in the evaluation state")

G.FUNCS.evaluate_round()
eq(seen.payout, "pending", "the evaluation sees the bonus open")
eq(seen.bonus, 3, "and its amount")

for _, event in ipairs(queue) do event.func() end
eq(pvp_net.inboxDone, 1, "the item's number moved")

G.FUNCS.evaluate_round()
eq(seen.bonus, 3, "a later evaluation does not add it again")
eq(#warnings, 0, "no warning logged")

T.done("blind_eval_bonus_test")
