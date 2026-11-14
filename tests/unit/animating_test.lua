-- Run from the repo root: luajit tests/unit/animating_test.lua
-- lib/animating.lua is pure: whether the player is animating, whether a timer context that freezes for
-- animations applies, and when a change of that is sent to the server (pvp.animating).
PVP = {}
dofile("lib/animating.lua")
local Animating = PVP.Animating

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

local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

test("a controller lock is an animation, but the frame lock alone is not", function()
	equal(Animating.is_animating({ locked = true }), true)
	equal(Animating.is_animating({ locked = true, frame_lock = true }), false)
	equal(Animating.is_animating({ locked = false }), false)
end)

test("STOP_USE above zero is an animation, zero or none is not", function()
	equal(Animating.is_animating({ stop_use = 1 }), true)
	equal(Animating.is_animating({ stop_use = 0 }), false)
	equal(Animating.is_animating({}), false)
end)

test("a paused game or an open menu is never animating", function()
	equal(Animating.is_animating({ locked = true, paused = true }), false)
	equal(Animating.is_animating({ stop_use = 2, overlay_menu = true }), false)
end)

test("the contexts: the PvP hand clock and Pressure, never Speedlatro", function()
	equal(Animating.in_context({ pvp_boss = true, pvp_clock = true }), true)
	equal(Animating.in_context({ pvp_boss = true, pvp_clock = false }), false)
	equal(Animating.in_context({ pressure = true }), true)
	equal(Animating.in_context({}), false)
	-- Pressure ticks outside the PvP blind and before the blind is ready.
	equal(Animating.in_context({ pressure = true, pvp_boss = true }), false)
	equal(Animating.in_context({ pressure = true, ready_blind = true }), false)
	equal(Animating.in_context({ pressure = true, speedlatro = true }), false)
	equal(Animating.in_context({ pvp_boss = true, pvp_clock = true, speedlatro = true }), false)
end)

local epoch = "e1"
local function frame(state, run_id, in_context, animating, now)
	local input = { run_id = run_id, epoch = epoch, in_context = in_context, animating = animating }
	return Animating.step(state, input, now)
end

test("a held change sends once, after the hold", function()
	local state, send = Animating.new(), nil
	state, send = frame(state, "r1", true, true, 0)
	equal(send, nil)
	state, send = frame(state, "r1", true, true, Animating.HOLD - 0.01)
	equal(send, nil)
	state, send = frame(state, "r1", true, true, Animating.HOLD)
	equal(send, true)
	state, send = frame(state, "r1", true, true, 5)
	equal(send, nil)
	-- Back to not animating: held, then sent once.
	state, send = frame(state, "r1", true, false, 6)
	equal(send, nil)
	state, send = frame(state, "r1", true, false, 6 + Animating.HOLD)
	equal(send, false)
	state, send = frame(state, "r1", true, false, 9)
	equal(send, nil)
end)

test("a flicker shorter than the hold sends nothing", function()
	local state, send = Animating.new(), nil
	state, send = frame(state, "r1", true, true, 0)
	state, send = frame(state, "r1", true, false, Animating.HOLD / 2)
	equal(send, nil)
	-- The earlier start does not count toward a later change.
	state, send = frame(state, "r1", true, true, Animating.HOLD)
	equal(send, nil)
	state, send = frame(state, "r1", true, true, Animating.HOLD * 1.5)
	equal(send, nil)
	state, send = frame(state, "r1", true, true, Animating.HOLD * 2)
	equal(send, true)
end)

test("a flicker off while the true value is sent does not send false", function()
	local state, send = Animating.new(), nil
	state = frame(state, "r1", true, true, 0)
	state, send = frame(state, "r1", true, true, Animating.HOLD)
	equal(send, true)
	state, send = frame(state, "r1", true, false, 2)
	state, send = frame(state, "r1", true, true, 2 + Animating.HOLD / 2)
	equal(send, nil)
	state, send = frame(state, "r1", true, true, 4)
	equal(send, nil)
end)

test("the context ending while true is sent sends false once, at once", function()
	local state, send = Animating.new(), nil
	state = frame(state, "r1", true, true, 0)
	state = frame(state, "r1", true, true, Animating.HOLD)
	state, send = frame(state, "r1", false, true, 1)
	equal(send, false)
	state, send = frame(state, "r1", false, true, 1.1)
	equal(send, nil)
	-- Back in context and animating: a new hold, a new send.
	state, send = frame(state, "r1", true, true, 2)
	equal(send, nil)
	state, send = frame(state, "r1", true, true, 2 + Animating.HOLD)
	equal(send, true)
end)

test("no send outside the context, however long the player animates", function()
	local state, send = Animating.new(), nil
	for t = 0, 5, 0.5 do
		state, send = frame(state, "r1", false, true, t)
		equal(send, nil)
	end
end)

test("no send without a run", function()
	local state, send = Animating.new(), nil
	state, send = frame(state, nil, true, true, 0)
	state, send = frame(state, nil, true, true, 5)
	equal(send, nil)
end)

test("a new run resets the sent state without sending", function()
	local state, send = Animating.new(), nil
	state = frame(state, "r1", true, true, 0)
	state = frame(state, "r1", true, true, Animating.HOLD)
	state, send = frame(state, "r2", true, true, 3)
	equal(send, nil)
	-- r2 starts from not sent: not animating is no change, animating is sent after the hold.
	state, send = frame(state, "r2", true, false, 4)
	equal(send, nil)
	state, send = frame(state, "r2", true, false, 8)
	equal(send, nil)
	state, send = frame(state, "r2", true, true, 9)
	state, send = frame(state, "r2", true, true, 9 + Animating.HOLD)
	equal(send, true)
end)

local function resends_after(change)
	local state, send = Animating.new(), nil
	state = frame(state, "r1", true, true, 0)
	state, send = frame(state, "r1", true, true, Animating.HOLD)
	equal(send, true)
	epoch = change
	state, send = frame(state, "r1", true, true, 2)
	equal(send, nil)
	state, send = frame(state, "r1", true, true, 2 + Animating.HOLD)
	equal(send, true)
	state, send = frame(state, "r1", true, true, 5)
	equal(send, nil)
	epoch = "e1"
end

test("server cleared at round close, client still animating -> resends true", function()
	resends_after("e2")
end)

test("server cleared by a reconnect, client still animating -> resends true", function()
	resends_after("e1:reconnected")
end)

test("a new epoch while sent true and not animating sends nothing", function()
	local state, send = Animating.new(), nil
	state = frame(state, "r1", true, true, 0)
	state = frame(state, "r1", true, true, Animating.HOLD)
	epoch = "e3"
	state, send = frame(state, "r1", true, false, 2)
	equal(send, nil)
	state, send = frame(state, "r1", true, false, 4)
	equal(send, nil)
	epoch = "e1"
end)

test("step never changes the state it was given", function()
	local state = Animating.new()
	local next_state = frame(state, "r1", true, true, 0)
	assert(next_state ~= state)
	equal(state.run_id, nil)
	equal(state.pending, nil)
end)

if failures > 0 then
	print(failures .. " test(s) failed")
	os.exit(1)
end
print("all passed")
