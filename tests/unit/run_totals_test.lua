-- Run from the repo root: luajit tests/unit/run_totals_test.lua
PVP = {}
dofile("lib/run_totals.lua")
local next_total = PVP.run_totals.next_total

local function eq(actual, expected, message)
	assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

-- Totals are in G.GAME.pvp_net, go up by one per action, count each key alone, and come back from a save.
local pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
eq(next_total(pvp_net, "skip"), 1, "the first action is 1")
eq(next_total(pvp_net, "skip"), 2, "then 2")
eq(next_total(pvp_net, "sell:3"), 1, "another key counts alone")
eq(next_total(pvp_net, "effect:pizza"), 1, "each effect has its own count")
eq(pvp_net.totals.skip, 2, "the total is kept in pvp_net.totals")

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = copy(item) end
	return out
end
local loaded = copy(pvp_net)
eq(next_total(loaded, "skip"), 3, "a loaded save goes on from its own total")
eq(pvp_net.totals.skip, 2, "and the live game is not touched")

local none, why = next_total(nil, "skip")
eq(none, nil, "no run: no total")
eq(why, "no run to count in", "and the reason")
eq(next_total({}, ""), nil, "an empty key is refused")
eq(next_total({}, 4), nil, "a key must be text")
local no_totals, no_totals_why = next_total({ runId = "run1" }, "skip")
eq(no_totals, nil, "a run with no totals table is refused, not given one")
eq(no_totals_why, "no totals", "and the reason")

print("run_totals_test: ok")
