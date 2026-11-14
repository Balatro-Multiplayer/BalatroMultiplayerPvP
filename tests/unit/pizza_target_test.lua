-- Plain Lua test: Pizza's discard reaches the eaten pizza's Nemesis only. In a match of 3 players the other
-- opponent (a bystander) gains nothing. Run from the repo root: luajit tests/unit/pizza_target_test.lua
--
-- The same checks run on the code before the effect moved to the server (the sync bus relayed the discard to
-- every opponent, and Pizza's `receive` applied it with no target filter) and after it (the server records the
-- effect against the sender's frozen targets only, and pvp_api/effects_net.lua applies what it lists for me).
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

local has_server_path = io.open("pvp_api/effects_net.lua", "rb") ~= nil

local def, state, sent, eased, rlog

local function setup()
	state, sent, eased, rlog = {}, {}, { discards = 0 }, {}
	SMODS = { Atlas = function() end }
	MPAPI = {
		OPCODE = { NET_PIZZA = 77 },
		Joker = function(definition)
			def = definition
		end,
		get_current_lobby = function()
			return { mod_id = "pvp", player_id = "me", _nakama = true, _game = { started = { run_id = "run1" } } }
		end,
		get_state = function(key)
			return state[key]
		end,
		on_state = function() end,
	}
	PVP = {
		id = "pvp",
		GAME = { pizza_discards = 0 },
		UTILS = { add_nemesis_info = function() end },
		RLOG = {
			record = function(opcode, discards)
				rlog[#rlog + 1] = { opcode, discards }
			end,
		},
		match_log = function() end,
		is_phantom = function()
			return false
		end,
		OpponentNet = {
			on_connected = function() end,
			can_apply = function()
				return true
			end,
			send_request = function(kind, fields)
				sent[#sent + 1] = { kind = kind, kind_of_effect = fields.kind }
			end,
		},
	}
	G = { GAME = { round_resets = { discards = 3 } }, C = { RED = "red" } }
	localize = function(key)
		return key
	end
	ease_discard = function(amount)
		eased.discards = eased.discards + amount
	end
	dofile("lib/_state_value.lua")
	dofile("pvp_api/_net_basics.lua")
	if has_server_path then
		dofile("lib/applied_opponent_effects.lua")
		dofile("pvp_api/effects_net.lua")
	end
	dofile("objects/jokers/pizza.lua")
end

-- What reaches me when `sender` eats a pizza. The sender's Nemesis is somebody else (`am_target` false), or me.
local function sender_eats_pizza(am_target)
	if def.receive then
		-- Before: the relay hands the discard to every opponent of the sender.
		def.receive(def, { from = "sender", data = 1 })
	else
		-- After: the server lists the effect for the sender's frozen targets only.
		local incoming = {}
		if am_target then incoming[1] = { from = "sender", n = 1, kind = "pizza", amount = 1 } end
		state["pvp.effects"] = { runId = "run1", me = { seq = 0, incoming = incoming, replies = {} } }
		PVP.EffectsNet.update()
	end
end

test("a bystander gains no discards from another pair's pizza", function()
	setup()
	sender_eats_pizza(false)
	equal(G.GAME.round_resets.discards, 3, "round discards")
	equal(eased.discards, 0, "discards eased")
	equal(PVP.GAME.pizza_discards, 0, "pizza discards")
end)

test("the Nemesis of the pizza's owner gains the discard", function()
	setup()
	sender_eats_pizza(true)
	equal(G.GAME.round_resets.discards, 4, "round discards")
	equal(eased.discards, 1, "discards eased")
	equal(PVP.GAME.pizza_discards, 1, "pizza discards")
end)

if has_server_path then
	test("the same projection read again gives the discard once", function()
		setup()
		sender_eats_pizza(true)
		PVP.EffectsNet.update()
		sender_eats_pizza(true)
		equal(eased.discards, 1, "discards eased")
	end)

	test("eating the pizza is one effect sent to the server, with no amount", function()
		setup()
		local card = { ability = { extra = def.config.extra }, remove_from_deck = function() end, start_dissolve = function() end }
		ease_discard = function() end
		def.calculate(def, card, { mp_end_of_pvp = true })
		equal(#sent, 1, "requests")
		equal(sent[1].kind, "pvp.effect", "request")
		equal(sent[1].kind_of_effect, "pizza", "kind")
	end)

	test("a blueprint copy sends nothing (Pizza is not copyable)", function()
		setup()
		local card = { ability = { extra = def.config.extra } }
		def.calculate(def, card, { mp_end_of_pvp = true, blueprint = true })
		equal(#sent, 0, "requests")
	end)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
