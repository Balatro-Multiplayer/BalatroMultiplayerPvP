-- Run from the repo root: luajit tests/unit/ante_nemesis_test.lua
-- The ante's Nemesis is read from the server: pvp.nemesis.byAnte[the ante I am at in pvp.round].each. An ante
-- the server has not frozen is unknown (no ids), and the Phantom rows and the trap row are re-sorted when the
-- ids read from the state change.
local states, listeners, lobby, sorts, refreshes

local passed, failed = 0, 0
local function equal(got, want, what)
	assert(got == want, ("%s: got %s, wanted %s"):format(what or "value", tostring(got), tostring(want)))
end

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("ok   " .. name)
	else
		failed = failed + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function setup()
	states, listeners, sorts, refreshes = {}, {}, 0, 0
	lobby = { mod_id = "pvp", player_id = "me", _game = { started = { run_id = "r1" } } }
	MPAPI = {
		get_current_lobby = function()
			return lobby
		end,
		get_state = function(key)
			return states[key]
		end,
		on_state = function(key, fn)
			listeners[key] = fn
		end,
	}
	PVP = {
		id = "pvp",
		nemesis_jokers = {},
		nemesis_jokers_hidden = {},
		sort_phantoms_by_ante_nemesis = function()
			sorts = sorts + 1
		end,
		TRAP_ROW = {
			refresh = function()
				refreshes = refreshes + 1
			end,
		},
	}
	dofile("pvp_api/_net_basics.lua")
	dofile("lib/opponent_record.lua")
	dofile("lib/ante_nemesis.lua")
end

local function round(ante, run)
	states["pvp.round"] = { runId = run or "r1", players = { me = { ante = ante } } }
end

local function nemesis(by_ante, run)
	states["pvp.nemesis"] = { runId = run or "r1", byAnte = by_ante }
end

local function ids()
	local list = PVP.ante_nemesis_ids()
	return list and table.concat(list, ",") or "nil"
end

test("the row of the ante I am at names my Nemesis", function()
	setup()
	round(2)
	nemesis({ ["1"] = { each = { "old" }, one = "old" }, ["2"] = { each = { "new" }, one = "new" } })
	equal(ids(), "new")
	equal(PVP.is_ante_nemesis("new"), true)
	equal(PVP.is_ante_nemesis("old"), false)
end)

test("the row is read by server ante: reaching the next ante reads that ante's row", function()
	setup()
	nemesis({ ["1"] = { each = { "a" }, one = "a" }, ["2"] = { each = { "b" }, one = "b" } })
	round(1)
	equal(ids(), "a")
	round(2)
	equal(ids(), "b")
end)

test("an ante the server has not frozen is unknown: unknown (nil, not empty)", function()
	setup()
	round(3)
	nemesis({ ["2"] = { each = { "b" }, one = "b" } })
	equal(ids(), "nil")
	equal(PVP.is_ante_nemesis("b"), false)
end)

test("a known ante nobody was my Nemesis in has no ids", function()
	setup()
	round(1)
	nemesis({ ["1"] = { each = {} } })
	equal(ids(), "")
end)

test("a Manhunt runner's Nemesis is every hunter of the row", function()
	setup()
	round(1)
	nemesis({ ["1"] = { each = { "h1", "h2", "h3" } } })
	equal(ids(), "h1,h2,h3")
	equal(PVP.is_ante_nemesis("h2"), true)
end)

test("no state yet, or the state of another run: no ids", function()
	setup()
	equal(ids(), "nil")
	round(1, "r0")
	nemesis({ ["1"] = { each = { "a" } } }, "r0")
	equal(ids(), "nil")
end)

test("no PvP lobby: no ids", function()
	setup()
	round(1)
	nemesis({ ["1"] = { each = { "a" } } })
	lobby = nil
	equal(ids(), "nil")
end)

test("a mid-ante change of the target does not move it (the row is frozen)", function()
	setup()
	round(1)
	nemesis({ ["1"] = { each = { "a" }, one = "a" } })
	PVP.current_target_id = function()
		return "someone_else"
	end
	equal(ids(), "a")
end)

test("the rows are re-sorted when the ids read from the state change, once", function()
	setup()
	round(1)
	nemesis({ ["1"] = { each = { "a" } }, ["2"] = { each = { "b" } } })
	listeners["pvp.nemesis"]()
	equal(sorts, 1)
	equal(refreshes, 1)
	listeners["pvp.round"]()
	equal(sorts, 1, "same ids: nothing to sort")
	round(2)
	listeners["pvp.round"]()
	equal(sorts, 2)
	equal(refreshes, 2)
end)

test("rebuilt rows with the same ids are sorted again after the reset", function()
	setup()
	round(1)
	nemesis({ ["1"] = { each = { "a" } } })
	PVP.sync_ante_nemesis()
	equal(sorts, 1)
	PVP.sync_ante_nemesis()
	equal(sorts, 1, "same rows, same ids: nothing to sort")
	PVP.reset_ante_nemesis_sort()
	PVP.sync_ante_nemesis()
	equal(sorts, 2, "new cards, same ids")
	equal(refreshes, 2)
end)

test("no Nemesis rows built (menu, between runs): nothing is sorted", function()
	setup()
	PVP.nemesis_jokers = nil
	round(1)
	nemesis({ ["1"] = { each = { "a" } } })
	listeners["pvp.nemesis"]()
	equal(sorts, 0)
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
