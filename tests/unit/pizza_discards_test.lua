-- Pizza's discard for the other players counts for the ante after the PvP blind, whether it
-- arrives before or after the receiver's own ante-up. Loads the real lib/pizza.lua,
-- objects/jokers/pizza.lua and the ease_ante override in ui/game/round.lua.
-- Run from the repo root: luajit tests/unit/pizza_discards_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local BASE = 3
local queued, pizza
local function setup(ante)
	queued = {}
	G = {
		GAME = { round_resets = { ante = ante, discards = BASE } },
		C = { RED = {} },
		FUNCS = {},
		E_MANAGER = { add_event = function(_, event) queued[#queued + 1] = event end },
	}
	PVP = {
		LOBBY = { config = {} },
		GAME = { pizza_discards = 0, pizza_pending = {}, antes_keyed = {}, ante_key = "a" },
		is_mp_or_practice = function() return true end,
		is_phantom = function() return false end,
		is_pvp_boss = function() return G.GAME.pvp_boss end,
		is_practice_mode = function() return false end,
		ACTIONS = { set_ante = function() end },
		UTILS = { log_mem_debug_messages = function() end },
		RLOG = { record = function() end },
	}
	MPAPI = { OPCODE = {}, Joker = function(def) pizza = def end }
	SMODS = { Atlas = function() end }
	Event = function(def) return def end
	for _, name in ipairs({ "ease_discard", "check_and_set_high_score", "ease_ante", "ease_round", "reset_blinds" }) do
		_G[name] = function() end
	end
	localize = function(key) return key end
	Blind, EventManager = {}, {}
	dofile("lib/pizza.lua")
	dofile("objects/jokers/pizza.lua")
	dofile("ui/game/round.lua")
end

-- ease_ante, then (unless told not to) the event that raises the ante.
local function ante_up(settle)
	PVP.GAME.ante_key = PVP.GAME.ante_key .. "+"
	ease_ante(1)
	if settle == false then return end
	for _, event in ipairs(queued) do event.func() end
	queued = {}
end

local function discards() return G.GAME.round_resets.discards end
local function receive(data) pizza:receive({ data = data }) end

setup(1)
check("rule: hold", PVP.PIZZA.rule(3, 2), "hold")
check("rule: apply", PVP.PIZZA.rule(3, 3), "apply")
check("rule: drop", PVP.PIZZA.rule(3, 4), "drop")

-- The bug: still in the PvP blind (ante 2) when the discard for ante 3 arrives.
setup(2)
receive({ amount = 1, ante = 3 })
check("behind: nothing yet", discards(), BASE)
ante_up()
check("behind: +1 after their own ante-up", discards(), BASE + 1)
ante_up()
check("behind: gone at the next ante-up", discards(), BASE)

setup(3)
receive({ amount = 1, ante = 3 })
check("caught up: +1 at once", discards(), BASE + 1)

-- Arrives between ease_ante and the event that raises the ante.
setup(2)
ante_up(false)
receive({ amount = 1, ante = 3 })
check("mid ante-up: +1 at once", discards(), BASE + 1)

setup(4)
receive({ amount = 1, ante = 3 })
check("past: dropped", discards(), BASE)
check("past: nothing waiting", next(PVP.GAME.pizza_pending), nil)

-- The eater keeps the PvP blind's ante and sends the ante after it.
setup(2)
local card = { ability = { extra = { discards = 2, discards_nemesis = 1 } } }
card.remove_from_deck, card.start_dissolve = function() end, function() end
G.GAME.pvp_boss = true
pizza:calculate(card, { setting_blind = true })
ante_up()
local ret = pizza:calculate(card, { mp_end_of_pvp = true })
check("eater: +2 for themselves", discards(), BASE + 2)
check("eater: sends 1", ret.send.amount, 1)
check("eater: for ante 3", ret.send.ante, 3)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
