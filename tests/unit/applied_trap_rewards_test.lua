-- Plain Lua test for lib/applied_trap_rewards.lua (pure) and the reward payment of pvp_api/traps_net.lua.
-- Run from the repo root: luajit tests/unit/applied_trap_rewards_test.lua
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

PVP = {}
dofile("lib/_state_value.lua")
dofile("lib/applied_trap_rewards.lua")
local A = PVP.AppliedTrapRewards

local CTX = { my_id = "me", run_id = "r1", can_apply = true }

local function trap(id, owner, state)
	return { id = id, key = "c_mp_trap_alarm", owner = owner, holder = "they", state = state }
end

local function value(traps, run_id)
	return { runId = run_id or "r1", trapSeq = #traps, traps = traps }
end

local function ids(rewards)
	local out = {}
	for _, r in ipairs(rewards) do
		out[#out + 1] = tostring(r.id)
	end
	return table.concat(out, ",")
end

test("step: a fired trap of mine is paid once with the server's data", function()
	local v = value({ trap(1, "me", { fired = { rerolls = 2 } }) })
	local rewards, applied = A.step(v, nil, CTX)
	equal(ids(rewards), "1")
	equal(rewards[1].data.rerolls, 2)
	equal(rewards[1].key, "c_mp_trap_alarm")
	equal(applied.ids["1"], true)
	local again, kept = A.step(v, applied, CTX)
	equal(#again, 0)
	equal(kept, applied)
end)

test("step: live, lost and other players' traps pay nothing", function()
	local v = value({ trap(1, "me", "live"), trap(2, "me", "lost"), trap(3, "they", { fired = {} }) })
	local rewards = A.step(v, nil, CTX)
	equal(#rewards, 0)
end)

test("step: traps fired out of order are each paid once, never by count", function()
	local applied
	local rewards
	rewards, applied = A.step(value({ trap(1, "me", "live"), trap(2, "me", { fired = {} }) }), nil, CTX)
	equal(ids(rewards), "2")
	rewards, applied = A.step(value({ trap(1, "me", { fired = {} }), trap(2, "me", { fired = {} }) }), applied, CTX)
	equal(ids(rewards), "1")
	rewards = A.step(value({ trap(1, "me", { fired = {} }), trap(2, "me", { fired = {} }) }), applied, CTX)
	equal(#rewards, 0)
end)

test("step: an older state after a newer one pays nothing and an id never leaves the set", function()
	local _, applied = A.step(value({ trap(1, "me", { fired = {} }) }), nil, CTX)
	local rewards, kept = A.step(value({ trap(1, "me", "live") }), applied, CTX)
	equal(#rewards, 0)
	equal(kept.ids["1"], true)
	rewards = A.step(value({ trap(1, "me", { fired = {} }) }), kept, CTX)
	equal(#rewards, 0)
end)

test("step: a different runId starts again with an empty set", function()
	local old = { runId = "r0", ids = { ["1"] = true } }
	local rewards, applied = A.step(value({ trap(1, "me", { fired = {} }) }), old, CTX)
	equal(ids(rewards), "1")
	equal(applied.runId, "r1")
end)

test("step: a state of another run than the lobby's changes nothing", function()
	local old = { runId = "r1", ids = {} }
	local rewards, applied = A.step(value({ trap(1, "me", { fired = {} }) }, "r0"), old, CTX)
	equal(#rewards, 0)
	equal(applied, old)
end)

test("step: while can_apply is false nothing is handed out or recorded", function()
	local rewards, applied = A.step(value({ trap(1, "me", { fired = {} }) }), nil, { my_id = "me", run_id = "r1", can_apply = false })
	equal(#rewards, 0)
	equal(applied, nil)
end)

test("step: the record the caller holds is never changed in place", function()
	local old = { runId = "r1", ids = { ["1"] = true } }
	local _, applied = A.step(value({ trap(1, "me", { fired = {} }), trap(2, "me", { fired = {} }) }), old, CTX)
	equal(old.ids["2"], nil)
	equal(applied.ids["2"], true)
end)

test("step: no state, or one with no traps, does nothing", function()
	equal(#A.step(nil, nil, CTX), 0)
	equal(#A.step({ runId = "r1" }, nil, CTX), 0)
end)

test("step: a fired trap of mine with no numeric id is counted, not paid", function()
	local rewards, _, malformed = A.step(value({ { key = "k", owner = "me", state = { fired = {} } } }), nil, CTX)
	equal(#rewards, 0)
	equal(malformed, 1)
end)

-- The shell: pays through the registry and keeps the index in PVP.GAME.
local state, logs, paid, can_apply

local function setup(game)
	state, logs, paid, can_apply = {}, {}, {}, true
	MPAPI = {
		get_current_lobby = function()
			return { player_id = "me", mod_id = "pvp", _nakama = true, _game = { started = { run_id = "r1" } } }
		end,
		get_state = function(key)
			return state[key]
		end,
	}
	PVP = {
		id = "pvp",
		SP = { practice = false },
		match_log = function(_, text)
			logs[#logs + 1] = text
		end,
		GAME = game or {},
		current_run_id = function()
			return "r1"
		end,
		NetBasics = {
			pvp_lobby = function()
				return MPAPI.get_current_lobby()
			end,
		},
		OpponentNet = {
			can_apply = function()
				return can_apply
			end,
			on_connected = function() end,
		},
		TRAP = {
			REWARDS = {
				c_mp_trap_alarm = function(data)
					paid[#paid + 1] = data
					if data.bad then return false, "bad data" end
				end,
			},
		},
	}
	dofile("lib/_state_value.lua")
	dofile("lib/applied_trap_rewards.lua")
	dofile("pvp_api/traps_net.lua")
end

test("pay_rewards: pays once, and again after a rejoin with the carried record pays nothing", function()
	setup()
	state["pvp.traps"] = value({ trap(1, "me", { fired = { rerolls = 2 } }) })
	PVP.TrapsNet.pay_rewards()
	PVP.TrapsNet.pay_rewards()
	equal(#paid, 1)
	local carried = PVP.GAME.trap_rewards_applied
	setup({ trap_rewards_applied = carried })
	state["pvp.traps"] = value({ trap(1, "me", { fired = { rerolls = 2 } }) })
	PVP.TrapsNet.pay_rewards()
	equal(#paid, 0)
end)

test("pay_rewards: a failed owner check pays nothing more but the index advances", function()
	setup()
	state["pvp.traps"] = value({ trap(1, "me", { fired = { bad = true } }) })
	PVP.TrapsNet.pay_rewards()
	PVP.TrapsNet.pay_rewards()
	equal(#paid, 1)
	equal(PVP.GAME.trap_rewards_applied.ids["1"], true)
	local refused = false
	for _, text in ipairs(logs) do
		if text:find("reward refused", 1, true) then refused = true end
	end
	assert(refused, "the refusal is logged")
end)

test("pay_rewards: nothing is paid or recorded while the game cannot apply", function()
	setup()
	can_apply = false
	state["pvp.traps"] = value({ trap(1, "me", { fired = {} }) })
	PVP.TrapsNet.pay_rewards()
	equal(#paid, 0)
	equal(PVP.GAME.trap_rewards_applied, nil)
	can_apply = true
	PVP.TrapsNet.pay_rewards()
	equal(#paid, 1)
end)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
