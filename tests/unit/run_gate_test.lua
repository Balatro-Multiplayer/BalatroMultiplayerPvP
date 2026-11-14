-- Run from the repo root: luajit tests/unit/run_gate_test.lua
-- pvp_api/run_gate.lua: true only for the live server lobby with the run in play. It keeps no
-- state, so it follows the game and nothing can leave it closed.
local current

local function setup()
	PVP = {}
	current = { _nakama = true }
	MPAPI = {
		get_current_lobby = function()
			return current
		end,
	}
	G = { STAGE = "run", STAGES = { RUN = "run" }, GAME = { round_resets = {} } }
	dofile("pvp_api/run_gate.lua")
end

local function equal(got, want, what)
	assert(got == want, ("%s: got %s, wanted %s"):format(what or "value", tostring(got), tostring(want)))
end

local failures = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

test("the live server lobby with a run in play is open", function()
	setup()
	equal(PVP.RunGate.loaded(), true)
end)

test("an offline lobby (practice, a rejoin's playback) is closed", function()
	setup()
	current = { _nakama = false, _local_mode = true }
	equal(PVP.RunGate.loaded(), false)
end)

test("no lobby, or a detached lobby still holding its messages, is closed", function()
	setup()
	current = nil
	equal(PVP.RunGate.loaded(), false)
	current = { _nakama = true, _holding = true }
	equal(PVP.RunGate.loaded(), false)
	current._holding = false
	equal(PVP.RunGate.loaded(), true, "released, it is open again")
end)

test("closed outside a run or before the game state exists", function()
	setup()
	G.STAGE = "menu"
	equal(PVP.RunGate.loaded(), false)
	G.STAGE = "run"
	G.GAME = nil
	equal(PVP.RunGate.loaded(), false)
	G.GAME = {}
	equal(PVP.RunGate.loaded(), false)
	G.GAME = { round_resets = {} }
	equal(PVP.RunGate.loaded(), true)
end)

if failures > 0 then os.exit(1) end
print("run_gate_test: ok")
