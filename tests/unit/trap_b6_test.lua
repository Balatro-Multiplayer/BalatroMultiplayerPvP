-- B6: a trap planted while the victim was reconnecting must not be lost. The victim missed the plant's message
-- (it was never delivered to them), but the server's "pvp.traps" holds the trap with them as holder, so after the
-- reconnect their consumables must hold exactly one card for it.
-- Stubs both the old API (MPAPI.ActionType, rebuild_card) and the new (SMODS.add_card), so it loads and runs on
-- either code. Run from the repo root: luajit tests/unit/trap_b6_test.lua
local function equal(got, want, what)
	assert(got == want, ("%s: got %s, wanted %s"):format(what or "value", tostring(got), tostring(want)))
end

local lobby = { player_id = "me", mod_id = "pvp", _nakama = true, _game = { started = { run_id = "run1" } } }
local state = {
	["pvp.traps"] = {
		runId = "run1",
		trapSeq = 1,
		traps = { { id = 7, key = "c_mp_trap_alarm", owner = "they", holder = "me", state = "live" } },
	},
}

local function new_card(key)
	local card = { ability = {}, config = { center = { key = key } } }
	table.insert(G.consumeables.cards, card)
	return card
end

MPAPI = {
	get_current_lobby = function()
		return lobby
	end,
	get_state = function(key)
		return state[key]
	end,
	ActionType = function(def)
		return def
	end,
	rebuild_card = function()
		return nil
	end,
	request = function() end,
}
Card = {
	start_dissolve = function() end,
	can_sell_card = function()
		return true
	end,
}
PVP = {
	id = "pvp",
	in_session = function()
		return true
	end,
	match_log = function() end,
	UI = {},
	GAME = {},
	current_run_id = function()
		return "run1"
	end,
	ante_nemesis_ids = function()
		return { "they" }
	end,
	StateValue = {
		same_run = function(value, run_id)
			return type(value) == "table" and value.runId ~= nil and tostring(value.runId) == tostring(run_id)
		end,
	},
	TrapsNet = { report = function() end },
}
G = { consumeables = { cards = {} }, E_MANAGER = { add_event = function() end } }
SMODS = {
	add_card = function(args)
		return new_card(args.key)
	end,
}

dofile("lib/trap_utils.lua")
PVP.TRAP.disguise = function(card)
	card.ability.mp_trap_hidden = true
end

-- The victim never ran the plant's on_receive. The reconnect path: the reconcile of the record, where it exists.
if PVP.TRAP.reconcile then PVP.TRAP.reconcile() end

local built = 0
for _, card in ipairs(G.consumeables.cards) do
	if card.ability.mp_trap_id == 7 then built = built + 1 end
end
equal(built, 1, "built")
print("ok   B6: the plant made while the victim was away is built from the record, once")
