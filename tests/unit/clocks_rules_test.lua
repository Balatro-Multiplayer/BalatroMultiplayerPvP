-- Run from the repo root: luajit tests/unit/clocks_rules_test.lua
-- PVP.UTILS.clocks_of reads the server's clock rules (pvp.rules.clocks) of one run; a missing or
-- malformed piece is unknown (nil), never a default. PVP.has_pvp_clock is true only when they say so.
PVP = { UTILS = {} }
local state, run_id = {}, "r1"
MPAPI = {
	get_state = function(key)
		return state[key]
	end,
}
PVP.current_run_id = function()
	return run_id
end
dofile("lib/_state_value.lua")
dofile("lib/ruleset_utils.lua")

local failures = 0
local function check(name, got, want)
	if got == want then
		print("ok   " .. name)
	else
		failures = failures + 1
		print(("FAIL %s: got %s, wanted %s"):format(name, tostring(got), tostring(want)))
	end
end

local function rules(clocks, rid)
	return { runId = rid or "r1", clocks = clocks }
end
local pvp_clock = { baseMs = 60000, handMs = 15000 }

local rows = {
	{ "no rules: unknown", nil, nil },
	{ "another run's rules: unknown", rules({ ante = "bank" }, "r2"), nil },
	{ "no clocks: unknown", { runId = "r1" }, nil },
	{ "an ante kind not in the set: unknown", rules({ ante = "weird" }), nil },
	{ "a pvp clock missing handMs: unknown", rules({ ante = "bank", pvp = { baseMs = 1 } }), nil },
	{ "a personal clock with no kind: unknown", rules({ ante = "personal", personal = {} }), nil },
	{ "a pvp clock that is not a table: unknown", rules({ ante = "bank", pvp = "x" }), nil },
	{ "a personal clock that is not a table: unknown", rules({ ante = "bank", personal = 5 }), nil },
	{ "the personal ante with no personal clock: unknown", rules({ ante = "personal" }), nil },
}
for _, row in ipairs(rows) do
	state["pvp.rules"] = row[2]
	check("clocks_rules: " .. row[1], PVP.clocks_rules(), row[3])
	check("has_pvp_clock: " .. row[1], PVP.has_pvp_clock(), false)
end

state["pvp.rules"] = { runId = "r1", clocks = { ante = "bank" } }
local got = PVP.clocks_rules()
check("well-formed rules with only ante set: the clocks, not unknown", got ~= nil and got.ante, "bank")

state["pvp.rules"] = rules({ ante = "bank", pvp = pvp_clock })
got = PVP.clocks_rules()
check("bank + pvp: ante", got.ante, "bank")
check("bank + pvp: pvp clock", got.pvp, pvp_clock)
check("bank + pvp: no personal", got.personal, nil)
check("bank + pvp: has_pvp_clock", PVP.has_pvp_clock(), true)

state["pvp.rules"] = rules({ ante = "personal", personal = { kind = "pressure", baseMs = 300000 } })
got = PVP.clocks_rules()
check("personal: kind", got.personal.kind, "pressure")
check("personal: no pvp clock", got.pvp, nil)
check("personal: has_pvp_clock false", PVP.has_pvp_clock(), false)

state["pvp.rules"] = rules({ ante = "none" })
check("none: known, has_pvp_clock false", PVP.clocks_rules() ~= nil and PVP.has_pvp_clock() == false, true)

state["pvp.rules"] = { runId = 1, clocks = { ante = "bank", pvp = pvp_clock } }
run_id = "1"
check("run ids compare as strings", PVP.has_pvp_clock(), true)

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
