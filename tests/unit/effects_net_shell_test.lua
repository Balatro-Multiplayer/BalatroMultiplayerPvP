-- Plain Lua test: the shell of pvp_api/effects_net.lua (when it looks at the server's `pvp.effects` again), with
-- the pure step real and the game stubbed. Run from the repo root: luajit tests/unit/effects_net_shell_test.lua
local passed, failed = 0, 0
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

local function equal(got, want, what)
	assert(got == want, ("%s: got %s, wanted %s"):format(what or "value", tostring(got), tostring(want)))
end

local state, dollars, can_apply, has_lobby, on_state_cb, on_connected_cb

local function record(n)
	return { from = "a", n = n, kind = "gambling", amount = 10 }
end

local function projection(...)
	return { runId = "run1", me = { seq = 0, incoming = { ... }, replies = {} } }
end

local function setup()
	state, dollars, can_apply, has_lobby = {}, 0, true, true
	on_state_cb, on_connected_cb = nil, nil
	MPAPI = {
		get_current_lobby = function()
			if not has_lobby then return nil end
			return { mod_id = "pvp", player_id = "me", _nakama = true, _game = { started = { run_id = "run1" } } }
		end,
		get_state = function(key)
			return state[key]
		end,
		on_state = function(_, fn)
			on_state_cb = fn
		end,
		OPCODE = {},
	}
	PVP = {
		id = "pvp",
		GAME = {},
		UTILS = {
			get_phantom_joker = function()
				return nil
			end,
		},
		match_log = function() end,
		OpponentNet = {
			can_apply = function()
				return can_apply
			end,
			send_request = function() end,
			on_connected = function(fn)
				on_connected_cb = fn
			end,
		},
	}
	G = { jokers = {}, GAME = {} }
	ease_dollars = function(amount)
		dollars = dollars + amount
	end
	dofile("lib/_state_value.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("lib/applied_opponent_effects.lua")
	dofile("pvp_api/effects_net.lua")
end

test("an effect that waits for an apply point is paid once when it comes, from the same table", function()
	setup()
	state["pvp.effects"] = projection(record(1))
	can_apply = false
	PVP.EffectsNet.update()
	equal(dollars, 0, "paid while blocked")
	can_apply = true
	PVP.EffectsNet.update()
	equal(dollars, 10, "paid when it can apply")
	PVP.EffectsNet.update()
	equal(dollars, 10, "paid again")
end)

test("an effect that arrived with no lobby is paid once the lobby is back, from the same table", function()
	setup()
	state["pvp.effects"] = projection(record(1))
	has_lobby = false
	PVP.EffectsNet.update()
	equal(dollars, 0, "paid with no lobby")
	has_lobby = true
	PVP.EffectsNet.update()
	equal(dollars, 10, "paid when the lobby is back")
	PVP.EffectsNet.update()
	equal(dollars, 10, "paid again")
end)

test("a record added to the table in place, with the state callback, is applied", function()
	setup()
	local value = projection(record(1))
	state["pvp.effects"] = value
	PVP.EffectsNet.update()
	equal(dollars, 10, "first")
	value.me.incoming[2] = record(2)
	PVP.EffectsNet.update()
	equal(dollars, 10, "second before the callback")
	assert(on_state_cb, "no state callback registered")
	on_state_cb()
	PVP.EffectsNet.update()
	equal(dollars, 20, "second after the callback")
end)

test("a reconnect looks at the table again", function()
	setup()
	state["pvp.effects"] = projection(record(1))
	can_apply = false
	PVP.EffectsNet.update()
	assert(on_connected_cb, "no reconnect callback registered")
	can_apply = true
	on_connected_cb()
	PVP.EffectsNet.update()
	equal(dollars, 10, "paid after the reconnect")
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
