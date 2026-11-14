-- Plain Lua test for lib/trap_row.lua: the row shows only live traps held by a Nemesis whose key is a trap center
-- of this client (the server does not check keys), and names the others as refused.
-- Run from the repo root: luajit tests/unit/trap_row_test.lua
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

local added, logs, state
PVP = {
	StateValue = {
		same_run = function(value, run_id)
			return type(value) == "table" and tostring(value.runId) == run_id
		end,
	},
	nemesis_consumeables = { cards = {}, T = { x = 0, y = 0, w = 1 } },
	ante_nemesis_ids = function()
		return { "they" }
	end,
	current_run_id = function()
		return "r1"
	end,
	match_log = function(_, text)
		logs[#logs + 1] = text
	end,
}
MPAPI = {
	get_current_lobby = function()
		return { player_id = "me" }
	end,
	get_state = function()
		return state
	end,
}
G = {
	P_CENTERS = {
		c_mp_trap_alarm = { set = "Trap" },
		c_mp_trap_wrong_set = { set = "Tarot" },
		c_fool = { set = "Tarot" },
	},
	CARD_W = 1,
	CARD_H = 1,
	E_MANAGER = { add_event = function() end },
}
Card = {}
Event = function(args)
	return args
end
dofile("lib/trap_row.lua")

local function trap(id, key, holder, trap_state)
	return { id = id, key = key, owner = "me", holder = holder or "they", state = trap_state or "live" }
end

local function is_trap(key)
	return key == "c_mp_trap_alarm"
end

test("project: a live trap with a trap key is wanted", function()
	local row = PVP.TRAP_ROW.project({ runId = "r1", traps = { trap(1, "c_mp_trap_alarm") } }, "r1", { "they" }, is_trap)
	equal(#row.wanted, 1)
	equal(#row.refused, 0)
end)

test("project: a live trap whose key is not a trap is skipped and named", function()
	local value = { runId = "r1", traps = { trap(1, "c_fool"), trap(2, "c_mp_trap_alarm"), trap(3, nil) } }
	local row = PVP.TRAP_ROW.project(value, "r1", { "they" }, is_trap)
	equal(#row.wanted, 1)
	equal(row.wanted[1].id, 2)
	equal(row.refused[1].key .. "," .. row.refused[2].key, "c_fool,nil")
	equal(row.refused[1].row_key, "they:1")
end)

test("project: a fired trap still marks its row, whatever its key", function()
	local value = { runId = "r1", traps = { trap(1, "c_fool", "they", { fired = {} }) } }
	local row = PVP.TRAP_ROW.project(value, "r1", { "they" }, is_trap)
	equal(row.fired["they:1"], true)
	equal(#row.refused, 0)
end)

test("refresh: a card whose center is missing, not a trap or not in the trap set is not built and is logged", function()
	logs = {}
	local built = {}
	Card = function(_, _, _, _, _, center)
		built[#built + 1] = center
		return {
			ability = {},
			states = { click = {}, drag = {} },
		}
	end
	function PVP.nemesis_consumeables:emplace() end
	state = {
		runId = "r1",
		traps = {
			trap(1, "c_mp_trap_missing"),
			trap(2, "c_mp_trap_wrong_set"),
			trap(3, "c_fool"),
			trap(4, "c_mp_trap_alarm"),
		},
	}
	PVP.TRAP_ROW.refresh()
	equal(#built, 1, "cards built")
	equal(built[1], G.P_CENTERS.c_mp_trap_alarm)
	equal(#logs, 3, "logged")
	PVP.TRAP_ROW.refresh()
	equal(#logs, 3, "logged once per trap, not again on the next refresh")
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
