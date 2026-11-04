-- texlua tests/unit/referee_checkpoint_test.lua
PVP = {}
dofile("lib/referee_checkpoint.lua")
local Checkpoint = PVP.RefereeCheckpoint
local copy = Checkpoint.copy
local passed = 0
local function equal(a, b) assert(a == b, ("got %s, wanted %s"):format(tostring(a), tostring(b))) end
local function test(name, fn) fn(); passed = passed + 1; print("ok   " .. name) end
local function setup()
	local writes, published, warnings, ids = {}, {}, 0, 0
	local gate = Checkpoint.new({
		scope = "run", writer = "a", new_id = function() ids = ids + 1; return tostring(ids) end,
		write = function(value) writes[#writes + 1] = value end,
		publish = function(value) published[#published + 1] = value end,
		on_timeout = function() warnings = warnings + 1 end,
	})
	return gate, writes, published, function() return warnings end
end

test("a socket write is not a commit and only an exact full echo releases effects", function()
	local gate, writes, published = setup()
	gate:stage({ action = "lose_life" }); gate:commit({ lives = 3, accepted = { a = 1 } })
	equal(#published, 0)
	local wrong = copy(writes[1]); wrong.lives = 4
	equal(gate:receive(wrong), false)
	wrong = copy(writes[1]); wrong._delivery.writer = "b"
	equal(gate:receive(wrong), false)
	equal(gate:receive(writes[1]), true)
	equal(#published, 1)
	equal(published[1].accepted.a, 1)
	equal(gate:receive(writes[1]), false)
end)

test("retry retains the same write identity and protects its frozen state", function()
	local gate, writes, published = setup()
	local state = { lives = 3 }
	gate:commit(state); state.lives = 0
	local original_id = writes[1]._delivery.id
	writes[1].lives = 999
	gate:update(2)
	equal(writes[2]._delivery.id, original_id)
	equal(writes[2].lives, 3)
	gate:receive(writes[2]); equal(#published, 1)
end)

test("new state coalesces behind one in-flight checkpoint without dropping effects", function()
	local gate, writes, published = setup()
	gate:stage({ event = 1 }); gate:commit({ state = 1 })
	gate:stage({ event = 2 }); gate:commit({ state = 2 })
	gate:stage({ event = 3 }); gate:commit({ state = 3 })
	equal(#writes, 1)
	gate:receive(writes[1]); equal(#writes, 2)
	equal(writes[2].state, 3)
	equal(#writes[2]._delivery.effects, 2)
	equal(#published, 1)
	gate:receive(writes[1]); equal(#published, 1)
	gate:receive(writes[2]); equal(#published, 2)
end)

test("timeout retains withheld effects and reconciliation resumes the same checkpoint", function()
	local gate, writes, published, warnings = setup()
	gate:stage({ event = 1 }); gate:commit({ state = 1 })
	gate:update(30); gate:update(100)
	equal(warnings(), 1); equal(#writes, 1); equal(#published, 0)
	gate:resume(); equal(writes[2]._delivery.id, writes[1]._delivery.id)
	gate:receive(writes[2]); equal(#published, 1)
end)

test("a late matching echo resolves a stalled checkpoint", function()
	local gate, writes, published = setup()
	gate:commit({ state = 1 }); gate:update(30)
	gate:receive(writes[1]); equal(#published, 1)
end)

test("pause stops retry deadlines and close prevents late publication", function()
	local gate, writes, published, warnings = setup()
	gate:commit({ state = 1 }); gate:pause(); gate:update(100)
	equal(#writes, 1); equal(warnings(), 0)
	gate:close(); gate:receive(writes[1]); gate:resume(); gate:update(100)
	equal(#writes, 1); equal(#published, 0)
end)

test("synchronous echo and reentrant state changes are serialized", function()
	local gate, writes, publications, serial = nil, {}, {}, 0
	gate = Checkpoint.new({ scope = "run", writer = "a", new_id = function() serial = serial + 1; return serial end,
		write = function(value) writes[#writes + 1] = value; gate:receive(value) end,
		publish = function(value)
			publications[#publications + 1] = value
			if value.state == 1 then gate:stage({ event = 2 }); gate:commit({ state = 2 }) end
		end,
		on_timeout = function() error("unexpected timeout") end,
	})
	gate:stage({ event = 1 }); gate:commit({ state = 1 })
	equal(#writes, 2); equal(#publications, 2)
end)

test("partial publication errors fault the gate instead of replaying effects", function()
	local gate, saved, calls = nil, nil, 0
	gate = Checkpoint.new({ scope = "run", writer = "a", new_id = function() return "one" end,
		write = function(value) saved = value end,
		publish = function() calls = calls + 1; error("partial publication") end,
		on_timeout = function() end,
	})
	gate:commit({ state = 1 })
	equal(pcall(function() gate:receive(saved) end), false)
	gate:receive(saved); gate:resume(); equal(calls, 1)
end)

print(("all %d referee checkpoint tests passed"):format(passed))
