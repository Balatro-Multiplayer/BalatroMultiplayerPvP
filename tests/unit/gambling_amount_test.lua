-- Plain Lua test: Let's Go Gambling's misfire pays the Nemesis the card's $10, whether or not the display copy of
-- the card has arrived on the board. Run from the repo root: luajit tests/unit/gambling_amount_test.lua
--
-- The same checks run on the code before the effect moved to the server (the Nemesis' `receive` read the amount
-- off the display copy and paid a made-up $5 when the copy was missing) and after it (the amount is the
-- server's record, applied by pvp_api/effects_net.lua, and the copy is only juiced up).
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

local def, state, sent, dollars, copy, logged

local function setup(opts)
	opts = opts or {}
	state, sent, dollars = {}, {}, 0
	copy, logged = nil, {}
	if opts.copy then
		copy = {
			juiced = 0,
			ability = { extra = { nemesis_dollars = 10 } },
			juice_up = function(self)
				self.juiced = self.juiced + 1
			end,
		}
	end
	SMODS = {
		Atlas = function() end,
		get_probability_vars = function()
			return 1, 4
		end,
		pseudorandom_probability = function()
			return opts.misfire ~= false
		end,
	}
	MPAPI = {
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
		GAME = {},
		UTILS = {
			add_nemesis_info = function() end,
			get_phantom_joker = function()
				return copy
			end,
		},
		match_log = function(_, line)
			logged[#logged + 1] = line
		end,
		is_phantom = function()
			return false
		end,
		is_pvp_boss = function()
			return true
		end,
		OpponentNet = {
			on_connected = function() end,
			can_apply = function()
				return true
			end,
			send_request = function(kind, fields)
				sent[#sent + 1] = { kind = kind, effect = fields.kind }
			end,
		},
	}
	G = { jokers = {}, GAME = {}, C = { RED = "red" } }
	localize = function(key)
		return key
	end
	ease_dollars = function(amount)
		dollars = dollars + amount
	end
	dofile("lib/_state_value.lua")
	dofile("pvp_api/_net_basics.lua")
	if has_server_path then
		dofile("lib/applied_opponent_effects.lua")
		dofile("pvp_api/effects_net.lua")
	end
	dofile("objects/jokers/lets_go_gambling.lua")
end

-- What reaches the Nemesis when the owner's misfire lands: `amount` is what the server table says.
local function misfire_arrives(amount)
	if def.receive then
		-- Before: the relay hands the Nemesis the event; the amount is read off the display copy.
		def.receive(def, { from = "sender", data = true })
	else
		-- After: the server lists the effect for me, with its own amount.
		state["pvp.effects"] = {
			runId = "run1",
			me = { seq = 0, incoming = { { from = "sender", n = 1, kind = "gambling", amount = amount } }, replies = {} },
		}
		PVP.EffectsNet.update()
	end
end

test("the misfire pays $10 when the display copy has not arrived", function()
	setup({ copy = false })
	misfire_arrives(10)
	equal(dollars, 10, "dollars")
end)

test("the misfire pays $10 when the display copy is there, and the copy juices up", function()
	setup({ copy = true })
	misfire_arrives(10)
	equal(dollars, 10, "dollars")
	equal(copy.juiced, 1, "juiced")
end)

if has_server_path then
	test("the amount is the server's: another amount is paid as it stands", function()
		setup({ copy = false })
		misfire_arrives(7)
		equal(dollars, 7, "dollars")
	end)

	test("a record with no amount is refused", function()
		setup({ copy = false })
		misfire_arrives(nil)
		equal(dollars, 0, "dollars")
		equal(#logged, 1, "refusal lines logged")
		assert(logged[1]:find("[pvp] error:", 1, true), "logged as an error: " .. logged[1])
	end)

	test("the same projection read again pays once", function()
		setup({ copy = false })
		misfire_arrives(10)
		PVP.EffectsNet.update()
		misfire_arrives(10)
		equal(dollars, 10, "dollars")
	end)

	test("each misfire, and each Blueprint or Brainstorm copy of it, is its own effect sent", function()
		setup({ copy = false })
		local card = { ability = { extra = def.config.extra } }
		local context = { cardarea = G.jokers, joker_main = true }
		def.calculate(def, card, context)
		def.calculate(def, card, { cardarea = G.jokers, joker_main = true, blueprint = card })
		def.calculate(def, card, { cardarea = G.jokers, joker_main = true, blueprint = card })
		equal(#sent, 3, "requests")
		for i = 1, 3 do
			equal(sent[i].kind, "pvp.effect", "request " .. i)
			equal(sent[i].effect, "gambling", "kind " .. i)
		end
	end)

	test("no misfire sends nothing", function()
		setup({ copy = false, misfire = false })
		local card = { ability = { extra = def.config.extra } }
		SMODS.pseudorandom_probability = function()
			return false
		end
		def.calculate(def, card, { cardarea = G.jokers, joker_main = true })
		equal(#sent, 0, "requests")
	end)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
