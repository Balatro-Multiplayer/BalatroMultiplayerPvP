-- Run from the repo root: luajit tests/unit/clocks_net_test.lua
-- pvp_api/clocks_net.lua over the real lib/clock_view.lua: the server's "pvp.clocks" state feeds
-- each player's clock, stored for the lobby and run it was read in.
local state, opts, logs, now, lobby

local function setup(o)
	opts = o or {}
	state, logs, now = {}, {}, 100
	lobby = { mod_id = "pvp", player_id = "me", _game = { started = { run_id = "run1" } } }
	PVP = {
		id = "pvp",
		match_log = function(level, message)
			logs[#logs + 1] = level .. " " .. message
		end,
	}
	love = {
		timer = {
			getTime = function()
				return now
			end,
		},
	}
	MPAPI = {
		get_current_lobby = function()
			if opts.no_lobby then return nil end
			return lobby
		end,
		get_state = function(key)
			return state[key]
		end,
		on_state = function() end,
	}
	dofile("lib/_state_value.lua")
	dofile("lib/clock_view.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/clocks_net.lua")
end

local function wire(fields)
	local entry = { ms = 10000, running = true, rate = 1, n = 1, spent = false }
	for name, value in pairs(fields or {}) do
		entry[name] = value
	end
	return entry
end

local failures = 0
local function test(name, fn, o)
	setup(o)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

test("a listed player's clock counts from its arrival", function()
	PVP.ClocksNet.evaluate({ me = wire({ rate = 2 }) })
	now = 101
	equal(PVP.ClocksNet.read("me").ms, 8000)
end)

test("a player the server does not list is unknown, not 0", function()
	PVP.ClocksNet.evaluate({ me = wire() })
	equal(PVP.ClocksNet.read("they").known, false)
end)

test("no PvP lobby: nothing is stored and nothing is read", function()
	PVP.ClocksNet.evaluate({ me = wire() })
	opts.no_lobby = true
	equal(PVP.ClocksNet.read("me").known, false)
	PVP.ClocksNet.evaluate({ me = wire() })
	opts.no_lobby = false
	equal(PVP.ClocksNet.read("me").known, false)
end)

test("another mod's lobby is not read", function()
	lobby.mod_id = "other"
	PVP.ClocksNet.evaluate({ me = wire() })
	equal(PVP.ClocksNet.read("me").known, false)
end)

test("an absent key clears every clock", function()
	PVP.ClocksNet.evaluate({ me = wire(), they = wire() })
	PVP.ClocksNet.evaluate(nil)
	equal(PVP.ClocksNet.read("me").known, false)
	equal(PVP.ClocksNet.read("they").known, false)
end)

test("a push of the same n keeps the countdown it has", function()
	PVP.ClocksNet.evaluate({ me = wire({ ms = 10000 }) })
	now = 102
	PVP.ClocksNet.evaluate({ me = wire({ ms = 10000 }) })
	equal(PVP.ClocksNet.read("me").ms, 8000)
end)

test("a snapshot of the same n re-bases, and a later push of the frozen time keeps that base", function()
	PVP.ClocksNet.evaluate({ me = wire({ ms = 10000 }) })
	now = 102
	PVP.ClocksNet.on_snapshot()
	PVP.ClocksNet.evaluate({ me = wire({ ms = 7000 }) })
	equal(PVP.ClocksNet.read("me").ms, 7000)
	now = 103
	PVP.ClocksNet.evaluate({ me = wire({ ms = 10000 }), they = wire({ n = 2 }) })
	equal(PVP.ClocksNet.read("me").ms, 6000)
end)

test("a new n restarts the countdown from the pushed time", function()
	PVP.ClocksNet.evaluate({ me = wire({ ms = 10000 }) })
	now = 102
	PVP.ClocksNet.evaluate({ me = wire({ ms = 5000, n = 2 }) })
	equal(PVP.ClocksNet.read("me").ms, 5000)
end)

test("a rejected entry drops only that player and is logged", function()
	PVP.ClocksNet.evaluate({ me = wire(), they = wire({ ms = -1 }) })
	equal(PVP.ClocksNet.read("me").known, true)
	equal(PVP.ClocksNet.read("they").known, false)
	equal(#logs, 1)
	assert(logs[1]:find("they", 1, true) and logs[1]:find("ms", 1, true), logs[1])
end)

test("a new run does not keep the earlier run's clock at the same n", function()
	PVP.ClocksNet.evaluate({ me = wire({ ms = 10000 }) })
	now = 105
	lobby._game.started.run_id = "run2"
	equal(PVP.ClocksNet.read("me").known, false)
	PVP.ClocksNet.evaluate({ me = wire({ ms = 70000 }) })
	equal(PVP.ClocksNet.read("me").ms, 70000)
end)

test("a new lobby does not keep the earlier lobby's clock at the same n", function()
	PVP.ClocksNet.evaluate({ me = wire({ ms = 10000 }) })
	now = 105
	lobby = { mod_id = "pvp", player_id = "me", _game = { started = { run_id = "run1" } } }
	equal(PVP.ClocksNet.read("me").known, false)
	PVP.ClocksNet.evaluate({ me = wire({ ms = 70000 }) })
	equal(PVP.ClocksNet.read("me").ms, 70000)
end)

test("on_connected reads the state again", function()
	state["pvp.clocks"] = { me = wire() }
	PVP.ClocksNet.on_connected()
	equal(PVP.ClocksNet.read("me").known, true)
end)

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
