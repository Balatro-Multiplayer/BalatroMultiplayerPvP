-- Run from the repo root: luajit tests/unit/status_test.lua
-- The lobby grid's player status (registered by pvp_api/lobby_bridge.lua): out and left players are
-- debuffed, everyone else and every unknown is not.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local registered
G = { STAGES = { RUN = "run", MAIN_MENU = "main_menu" }, STAGE = "run" }
PVP = { NET = {}, READ = { pvp_blind = {}, target = {} }, id = "MultiplayerPvP", LOBBY = { config = {}, deck = {} }, GAME = {}, UTILS = {}, UI = { UTILS = {}, lobby = {} } }
MPAPI = {
	LobbyEvent = {},
	register_player_status_provider = function(mod_id, fn) registered = { mod_id = mod_id, fn = fn } end,
}
dofile("pvp_api/read/_view.lua")
dofile("pvp_api/lobby_bridge.lua")

local view = { players = { a = { status = "playing" }, b = { status = "away" }, c = { status = "out" }, d = { status = "left" }, e = {} } }
eq(registered.mod_id, "MultiplayerPvP", "registered for this mod")
PVP.NET.view = view
for id, want in pairs({ a = false, b = false, c = true, d = true, e = false, z = false }) do
	eq(registered.fn(nil, { id = id }), want, "status of " .. id)
end
G.STAGE = G.STAGES.MAIN_MENU
PVP.NET.view = { match = { stage = "lobby", ended = view } }
for id, want in pairs({ a = false, b = false, c = true, d = true }) do
	eq(registered.fn(nil, { id = id }), want, "waiting room after a game: status of " .. id)
end
PVP.NET.view = { match = { stage = "lobby" } }
eq(registered.fn(nil, { id = "c" }), false, "waiting room before any game: not debuffed")
G.STAGE = G.STAGES.RUN
PVP.NET.view = nil
eq(registered.fn(nil, { id = "c" }), false, "no view is not out")

T.done("status_test")
