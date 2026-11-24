-- A new game or a Run load starts without this client's clock readings for the old run:
-- the run start time (Seed Change window) and a pending Magnet request.
-- core.lua does not load without the game, so this runs PVP.reset_game_states from its source text.
-- Run from the repo root: luajit tests/unit/run_reset_test.lua
local checks = 0
local function check(condition, message)
	checks = checks + 1
	if not condition then error(message, 2) end
end

local file = assert(io.open("core.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local body = source:match("\n(function PVP%.reset_game_states%(%).-\nend)\n")
check(body ~= nil, "core.lua defines PVP.reset_game_states")

localize = function(key) return key end
PVP = { Score = { ZERO = 0 }, match_log = function() end }
PVP._run_started_at = 12.5
PVP.magnet_request_at = 1700000000
PVP.GAME = { lives = 2 }
assert(load(body, "=core.lua reset_game_states"))()

PVP.reset_game_states()

check(PVP._run_started_at == nil, "the run start time is cleared")
check(PVP.magnet_request_at == nil, "a pending Magnet request is cleared")
check(PVP.GAME.lives == 0, "the fresh match defaults are back")
print(string.format("run_reset_test: ok (%d checks)", checks))
