-- Run from the repo root: luajit tests/unit/status_test.lua
-- The lobby grid's player status (registered by pvp_api/lobby_bridge.lua): out and left players are
-- debuffed, everyone else and every unknown is not.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local registered
G = { STAGES = { RUN = "run", MAIN_MENU = "main_menu" }, STAGE = "run" }
PVP = { id = "MultiplayerPvP", match_net = {}, LOBBY = { config = {}, deck = {} }, GAME = {}, UTILS = {}, UI = { UTILS = {} } }
MPAPI = {
	LobbyEvent = {},
	register_player_status_provider = function(mod_id, fn) registered = { mod_id = mod_id, fn = fn } end,
}
dofile("pvp_api/_view.lua")
dofile("pvp_api/lobby_bridge.lua")

local view = { players = { a = { status = "playing" }, b = { status = "away" }, c = { status = "out" }, d = { status = "left" }, e = {} } }
eq(registered.mod_id, "MultiplayerPvP", "registered for this mod")
PVP.match_net.view = view
for id, want in pairs({ a = false, b = false, c = true, d = true, e = false, z = false }) do
	eq(registered.fn(nil, { id = id }), want, "status of " .. id)
end
G.STAGE = G.STAGES.MAIN_MENU
PVP.match_net.view = { match = { stage = "lobby", ended = view } }
for id, want in pairs({ a = false, b = false, c = true, d = true }) do
	eq(registered.fn(nil, { id = id }), want, "waiting room after a game: status of " .. id)
end
PVP.match_net.view = { match = { stage = "lobby" } }
eq(registered.fn(nil, { id = "c" }), false, "waiting room before any game: not debuffed")
G.STAGE = G.STAGES.RUN
PVP.match_net.view = nil
eq(registered.fn(nil, { id = "c" }), false, "no view is not out")

print("status_test: ok (" .. checks .. " checks)")
