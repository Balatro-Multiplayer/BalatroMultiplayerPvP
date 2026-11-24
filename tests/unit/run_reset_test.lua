-- A new game or a Run load starts without this client's clock readings for the old run:
-- the run start time (Seed Change window) and a pending Magnet request.
-- core.lua does not load without the game, so this runs PVP.LOBBY.reset_game from its source text.
-- Run from the repo root: luajit tests/unit/run_reset_test.lua
local T = dofile("tests/support/check.lua")
local check = T.check

local file = assert(io.open("core.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local body = source:match("\n(function PVP%.LOBBY%.reset_game%(%).-\nend)\n")
check(body ~= nil, "core.lua defines PVP.LOBBY.reset_game")

localize = function(key) return key end
PVP = { LOBBY = {}, SCORE = { ZERO = 0 }, match_log = function() end }
PVP.GAME = { run_started_at = 12.5, magnet_request_at = 1700000000, lives = 2 }
assert(load(body, "=core.lua reset_game"))()

PVP.LOBBY.reset_game()

check(PVP.GAME.run_started_at == nil, "the run start time is cleared")
check(PVP.GAME.magnet_request_at == nil, "a pending Magnet request is cleared")
check(PVP.GAME.lives == 0, "the fresh match defaults are back")
T.done("run_reset_test")
