-- Plain Lua test for pvp_api/actions/opponent_context.lua (the shell around the recorder).
-- Run from the repo root: luajit tests/unit/opponent_context_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local original_calls = 0
local at = {
	on_receive = function()
		original_calls = original_calls + 1
	end,
}
local lobby = { mod_id = "pvp" }
MPAPI = {
	ActionTypes = { mpapi_opponent_context = at },
	sendWarnMessage = function() end,
	get_current_lobby = function()
		return lobby
	end,
}
PVP = {
	id = "pvp",
	GAME = { enemy = { sells = 0, sells_per_ante = {}, spent_in_shop = {} } },
	self_player_id = function()
		return "me"
	end,
	current_target_id = function()
		return "target"
	end,
	is_byed = function()
		return false
	end,
}
G = { GAME = { round_resets = { ante = 2 } } }

dofile("lib/opponent_record.lua")
dofile("pvp_api/actions/opponent_context.lua")

local enemy = PVP.GAME.enemy

at.on_receive(at, "target", { opponent_selling_card = true })
check("sell from target: total", enemy.sells, 1)
check("sell from target: this ante", enemy.sells_per_ante[2], 1)
check("original handler ran once", original_calls, 1)

at.on_receive(at, "target", { opponent_spent_in_shop = 9 })
check("spend recorded", enemy.spent_in_shop[1], 9)
check("one spend only", #enemy.spent_in_shop, 1)
check("original handler ran twice in total", original_calls, 2)

at.on_receive(at, "me", { opponent_selling_card = true, opponent_spent_in_shop = 5 })
check("own event: sells unchanged", enemy.sells, 1)
check("own event: spends unchanged", #enemy.spent_in_shop, 1)
check("own event still reaches the original handler", original_calls, 3)

at.on_receive(at, "other", { opponent_selling_card = true })
check("non-target event is ignored", enemy.sells, 1)

-- Another mod's lobby shares the action type but must not write into PvP's record.
lobby.mod_id = "other"
at.on_receive(at, "target", { opponent_selling_card = true })
check("other mod's lobby is not recorded", enemy.sells, 1)
check("other mod's lobby still reaches the original handler", original_calls, 5)
lobby.mod_id = "pvp"

-- A throwing recording must not stop the original handler.
local real_target = PVP.current_target_id
PVP.current_target_id = function()
	error("boom")
end
at.on_receive(at, "target", { opponent_selling_card = true })
check("throwing recorder: original handler still ran", original_calls, 6)
PVP.current_target_id = real_target

-- Loading the wrapper again must not stack a second recorder.
dofile("pvp_api/actions/opponent_context.lua")
at.on_receive(at, "target", { opponent_selling_card = true })
check("double load: still +1 per event", enemy.sells, 2)
check("double load: original handler once per call", original_calls, 7)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
