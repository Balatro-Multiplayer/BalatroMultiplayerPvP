-- Plain Lua test: the real Penny Pincher pays for the shop of my Nemesis' slot it points at, read from the
-- server's pvp.opponent / pvp.nemesis / pvp.round through the real PVP.OpponentNet. A shop the server has not
-- recorded yet is pending, never $0: it is paid once when it arrives, at an apply point.
-- Run from the repo root: luajit tests/unit/penny_pincher_payout_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local pincher, state, dollars, logs
local answers = {}
local revs = {}
local lobby = { mod_id = "pvp", player_id = "me", _nakama = true, _holding = false, _game = { started = { run_id = "r1" } } }

MPAPI = {
	get_current_lobby = function()
		return lobby
	end,
	get_state = function(key)
		return state[key], revs[key]
	end,
	on_state = function() end,
	request = function(_, _, on_result)
		answers[#answers + 1] = on_result
	end,
	Joker = function(def)
		pincher = def
	end,
}
SMODS = { Atlas = function() end }

ease_dollars = function(amount)
	dollars = dollars + amount
end
PVP = {
	id = "pvp",
	SP = { practice = false },
	UTILS = { add_nemesis_info = function() end },
	match_log = function(_, text)
		logs[#logs + 1] = text
	end,
}
G = { STATES = { SHOP = 2, HAND_PLAYED = 4 }, STATE = 2, GAME = { round_resets = { ante = 1 } } }
dofile("pvp_api/_net_basics.lua")
dofile("lib/opponent_record.lua")
dofile("pvp_api/opponent_net.lua")
dofile("objects/jokers/penny_pincher.lua")

-- `mine` is how many of my blind slots the server has recorded; the blind I clear now is slot mine+1.
local function new_game(mine, opponent_slots, closed)
	dollars, logs = 0, {}
	PVP.GAME = {}
	local my_slots = {}
	for k = 1, mine do
		my_slots[k] = { ante = 1, spent = 0 }
	end
	state = {
		["pvp.round"] = { runId = "r1", players = { me = { ante = 1 }, they = { ante = 1 } } },
		["pvp.nemesis"] = { runId = "r1", byAnte = { ["1"] = { each = { "they" }, one = "they" } } },
		["pvp.opponent"] = {
			runId = "r1",
			players = {
				me = { sells = {}, slots = my_slots, closed = false },
				they = { sells = {}, slots = opponent_slots, closed = closed or false },
			},
		},
	}
end

local function hold()
	return { config = { center = pincher }, ability = { extra = { dollars = 1, nemesis_dollars = 3 } } }
end

local function bonus(card)
	return pincher.calc_dollar_bonus(pincher, card or hold())
end

-- Clearing blind 4 (3 slots reported): pays from the opponent's slot 1. Clearing blinds 1 to 3 pays nothing.
new_game(3, { { ante = 1, spent = 9 } })
check("slot k-3 of the opponent: $9 / 3 = $3", bonus(), 3)
new_game(2, { { ante = 1, spent = 9 } })
check("blind 3 has no slot k-3: nothing", bonus(), nil)
new_game(0, {})
check("blind 1: nothing", bonus(), nil)
check("blind 1: nothing is pending either", PVP.GAME.pincher_pending, nil)

-- B4: the opponent's slots are spend 9, skip, spend 6. Clearing blind 5 reads slot 2, the skip.
new_game(4, { { ante = 1, spent = 9 }, { ante = 1, skipped = true }, { ante = 2, spent = 6 } })
check("B4: the opponent's skipped slot pays nothing", bonus(), nil)
new_game(5, { { ante = 1, spent = 9 }, { ante = 1, skipped = true }, { ante = 2, spent = 6 } })
check("B4: the next blind reads the $6 shop: $2", bonus(), 2)

new_game(3, { { ante = 1, refused = "implausible" } })
check("a refused slot pays nothing", bonus(), nil)

-- Pending, never $0
new_game(3, {})
check("the shop is not recorded yet: nothing now", bonus(), nil)
check("a pending credit is kept", #PVP.GAME.pincher_pending.items, 1)
check("the pending credit is for slot 1", PVP.GAME.pincher_pending.items[1].s, 1)

PVP.OpponentNet.pay_pending()
check("nothing is paid while the shop is unknown", dollars, 0)
check("the credit stays", #PVP.GAME.pincher_pending.items, 1)
state["pvp.opponent"].players.they.slots = { { ante = 1, spent = 9 } }
G.STATE = G.STATES.HAND_PLAYED
PVP.OpponentNet.pay_pending()
check("not paid while a hand is being scored", dollars, 0)
G.STATE = G.STATES.SHOP
PVP.OpponentNet.pay_pending()
check("paid once the shop is recorded: $3", dollars, 3)
check("the credit is gone", #PVP.GAME.pincher_pending.items, 0)
PVP.OpponentNet.pay_pending()
check("paid once only", dollars, 3)

new_game(3, {}, true)
check("an opponent who left: nothing", bonus(), nil)
check("an opponent who left: nothing pending", PVP.GAME.pincher_pending, nil)

new_game(3, {})
state["pvp.nemesis"].byAnte["1"] = { each = {} }
check("a bye (one === null): nothing", bonus(), nil)
check("a bye: nothing pending", PVP.GAME.pincher_pending, nil)

new_game(3, {})
state["pvp.nemesis"].byAnte = {}
check("the Nemesis of that ante not frozen yet: nothing now", bonus(), nil)
check("the Nemesis not frozen yet: pending", #PVP.GAME.pincher_pending.items, 1)

-- Two Pinchers: each pays for the same shop, once each.
new_game(3, { { ante = 1, spent = 9 } })
local a, b = hold(), hold()
check("two Pinchers: the first pays $3", bonus(a), 3)
check("two Pinchers: the second pays $3", bonus(b), 3)

-- A pending credit of another run is dropped and logged, not paid.
new_game(3, {})
bonus()
PVP.GAME.pincher_pending.runId = "old"
PVP.OpponentNet.pay_pending()
check("another run's credit is dropped", #PVP.GAME.pincher_pending.items, 0)
check("another run's credit is logged", #logs > 0, true)

-- The Nemesis and the slot are read by the ante my slot was recorded in, not the ante I am at now.
local function antes_game(my_antes, rows, opponents, current_ante)
	new_game(#my_antes, {})
	local my_slots = {}
	for k, ante in ipairs(my_antes) do
		my_slots[k] = { ante = ante, spent = 0 }
	end
	local by_ante, players = {}, { me = { sells = {}, slots = my_slots, closed = false } }
	for ante, id in pairs(rows) do
		by_ante[tostring(ante)] = { each = { id }, one = id }
	end
	for id, slots in pairs(opponents) do
		players[id] = { sells = {}, slots = slots, closed = false }
	end
	state["pvp.nemesis"].byAnte = by_ante
	state["pvp.opponent"].players = players
	state["pvp.round"].players.me.ante = current_ante
end

-- Post-Boss: I cleared the Boss and moved to ante 2; the slot being paid was recorded in ante 1.
antes_game({ 1, 1, 1 }, { [1] = "they", [2] = "next" }, { they = { { ante = 1, spent = 9 } }, next = { { ante = 2, spent = 30 } } }, 2)
check("post-Boss: slot 1 of ante 1 reads the ante 1 Nemesis, $9 / 3 = $3", bonus(), 3)

-- Slot ante differs from the current ante and the rows name different Nemeses.
antes_game({ 1, 1, 1 }, { [1] = "a", [2] = "b" }, { a = { { ante = 1, spent = 6 } }, b = { { ante = 2, spent = 30 } } }, 2)
check("slot ante 1 with the current ante 2: pays a's $6 / 3 = $2, not b's", bonus(), 2)

-- Ante down on my side: my slot 1 was recorded in ante 2, now I am back at ante 1.
antes_game({ 2, 2, 1 }, { [1] = "a", [2] = "b" }, { a = { { ante = 1, spent = 30 } }, b = { { ante = 2, spent = 12 } } }, 1)
check("ante down on my side: slot 1 of ante 2 reads b, $12 / 3 = $4", bonus(), 4)

-- Ante down on the target's side: their slot 1 was recorded in an ante that is not mine; the slot number rules.
antes_game({ 1, 1, 1 }, { [1] = "a" }, { a = { { ante = 3, spent = 9 } } }, 1)
check("ante down on the target's side: their slot 1 pays $3", bonus(), 3)

-- My slot is recorded in an ante whose Nemesis the server has not frozen: pending, not $0.
antes_game({ 1, 1, 1 }, {}, {}, 1)
check("no Nemesis row for the slot's ante: nothing now", bonus(), nil)
check("no Nemesis row for the slot's ante: pending", #PVP.GAME.pincher_pending.items, 1)

-- My slot was refused no_progress (the server had no ante for me): recorded with no ante, final. No
-- Nemesis can be looked up for it, so it pays $0 by rule and never waits.
antes_game({ 1, 1, 1 }, { [1] = "a" }, { a = { { ante = 1, spent = 9 } } }, 1)
state["pvp.opponent"].players.me.slots[1] = { refused = "no_progress" }
check("my slot refused with no ante: nothing", bonus(), nil)
check("my slot refused with no ante: nothing pending", PVP.GAME.pincher_pending, nil)

local function record_my_slots(count)
	local slots = {}
	for k = 1, count do
		slots[k] = { ante = 1, spent = 0 }
	end
	state["pvp.opponent"].players.me.slots = slots
end

-- The shop just left is a pvp.shop request still in flight: the record may not include it, so the credit is
-- pending, with no slot guessed, until the answer is in and the record holds it.
new_game(2, { { ante = 1, spent = 9 } })
PVP.OpponentNet.report_shop(5)
check("in flight: nothing now", bonus(), nil)
check("in flight: the credit is pending", #PVP.GAME.pincher_pending.items, 1)
check("in flight: no slot is guessed", PVP.GAME.pincher_pending.items[1].s, nil)
PVP.OpponentNet.pay_pending()
check("in flight: nothing is paid", dollars, 0)
record_my_slots(3)
PVP.OpponentNet.pay_pending()
check("in flight: not paid before the answer", dollars, 0)
answers[#answers](true, {})
PVP.OpponentNet.pay_pending()
check("answered and recorded: slot 3 pays from the opponent's slot 1, $9 / 3 = $3", dollars, 3)

-- The answer to my pvp.shop request can arrive before the state that shows its slot: the credit waits for a
-- record at the answer's revision.
new_game(2, { { ante = 1, spent = 9 } })
revs["pvp.opponent"] = 9
PVP.OpponentNet.report_shop(5)
answers[#answers](true, { rev = 10 })
check("answer before state: nothing now", bonus(), nil)
check("answer before state: pending, no slot guessed", PVP.GAME.pincher_pending.items[1].s, nil)
PVP.OpponentNet.pay_pending()
check("answer before state: not paid on the old record", dollars, 0)
check("answer before state: still pending", #PVP.GAME.pincher_pending.items, 1)
record_my_slots(3)
revs["pvp.opponent"] = 10
PVP.OpponentNet.pay_pending()
check("state landed: slot 3 pays from the opponent's slot 1, $3", dollars, 3)
-- Later cases keep this revision: the answered revision of the module only grows.

-- The answered revision belongs to its run: run B's match starts its revisions low, and its record counts.
new_game(2, { { ante = 1, spent = 9 } })
revs["pvp.opponent"] = 50
PVP.OpponentNet.report_shop(5)
answers[#answers](true, { rev = 50 })
lobby._game.started.run_id = "r2"
for _, record in pairs(state) do
	record.runId = "r2"
end
record_my_slots(3)
revs["pvp.opponent"] = 3
check("another run, low revision: slot 3 pays from the opponent's slot 1, $3", bonus(), 3)
lobby._game.started.run_id = "r1"
for _, record in pairs(state) do
	record.runId = "r1"
end
revs["pvp.opponent"] = 60

-- My own record unknown: the credit waits with no slot, and a slot sent meanwhile is not mistaken for the one cleared.
new_game(0, {})
state["pvp.opponent"] = nil
check("my record unknown: nothing now", bonus(), nil)
check("my record unknown: pending", #PVP.GAME.pincher_pending.items, 1)
check("my record unknown: no slot guessed", PVP.GAME.pincher_pending.items[1].s, nil)
PVP.OpponentNet.report_shop(0)
answers[#answers](true, {})
new_game(0, { { ante = 1, spent = 9 } })
PVP.GAME.pincher_pending = { runId = "r1", items = { { divisor = 3, dollars = 1, later = 1 } } }
record_my_slots(4)
PVP.OpponentNet.pay_pending()
check("my record known: the credit was made at my 4th slot, paying the opponent's slot 1: $3", dollars, 3)

-- Practice and replay: no payout from a server that is not there.
new_game(3, { { ante = 1, spent = 9 } })
PVP.SP.practice = true
check("practice: nothing", bonus(), nil)
PVP.SP.practice = false

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
