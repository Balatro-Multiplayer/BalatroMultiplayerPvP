-- Run from the repo root: luajit tests/unit/playback_skip_test.lua
-- A skip seen in a replay of the other player adds one to their skips only when there is no live
-- view: with a view, the view owns the count (run_screen.lua).
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local handlers = {}
MPAPI = {
	OPCODE = setmetatable({ SKIP_BLIND = "skip_blind" }, { __index = function(_, key) return key end }),
	playback = {
		register_handler = function(_, opcode, fn) handlers[opcode] = fn end,
	},
}
PVP = {
	UTILS = { AREA = {} },
	GAME = { enemy = {} },
	match_net = { view = nil },
}

dofile("lib/playback_handlers.lua")
local skip = handlers.skip_blind
eq(type(skip), "function", "the skip handler is registered")

PVP.GAME.enemy = {}
skip({}, { is_pov = false })
eq(PVP.GAME.enemy.skips, 1, "no view: the skip is counted")
skip({}, { is_pov = false })
eq(PVP.GAME.enemy.skips, 2, "and counted again")

PVP.match_net.view = { match = { run = {} } }
skip({}, { is_pov = false })
eq(PVP.GAME.enemy.skips, 2, "a live view: the view's count is left alone")

PVP.match_net = nil
skip({}, { is_pov = false })
eq(PVP.GAME.enemy.skips, 3, "no net at all: the skip is counted")

print(string.format("playback_skip_test: %d checks ok", checks))
