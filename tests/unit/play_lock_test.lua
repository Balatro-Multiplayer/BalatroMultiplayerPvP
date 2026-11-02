-- Plain Lua test for lib/play_lock.lua (the double-Play guard, no game needed).
-- Run from the repo root: luajit tests/unit/play_lock_test.lua
PVP = {}

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local now = 0
local queue = {}
local in_session = true
love = {
	timer = {
		getTime = function()
			return now
		end,
	},
}
G = {
	GAME = {},
	E_MANAGER = {
		add_event = function(_, e)
			queue[#queue + 1] = e
		end,
	},
}
function Event(e)
	return e
end
function PVP.in_session()
	return in_session
end

dofile("lib/play_lock.lua")
local PL = PVP.PlayLock

local plays = 0
local function play()
	plays = plays + 1
end
local function drain()
	while #queue > 0 do
		table.remove(queue, 1).func()
	end
end

check("first play runs", PL.run(play), true)
check("second play before the queue drains is dropped", PL.run(play), false)
check("only one hand was played", plays, 1)
drain()
check("play after the queue drains runs", PL.run(play), true)
check("two hands were played", plays, 2)

drain()
now = 100
PL.run(play)
now = 105
check("lock still holds under 10s", PL.run(play), false)
now = 110
check("lock lifts after 10s", PL.run(play), true)
drain()

PL.run(play)
G.GAME = {}
check("a new run frees the lock", PL.run(play), true)
drain()

local before = plays
local function boom()
	error("play failed")
end
check("a raising play propagates", pcall(PL.run, boom), false)
check("a raising play leaves no lock", PL.run(play), true)
check("the play after a raise ran", plays, before + 1)
drain()

in_session = false
PL.reset()
check("outside a session the first play runs", PL.run(play), true)
check("outside a session a second play runs", PL.run(play), true)
check("outside a session nothing is queued", #queue, 0)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
