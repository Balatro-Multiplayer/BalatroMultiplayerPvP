-- Run from the repo root: luajit tests/unit/inbox_handlers_test.lua
-- pvp_api/net/inbox.lua: every inbox item effect makes the right game calls, waits for its safe
-- point, and is applied once, through the real match_net runner.
local T = dofile("tests/support/check.lua")
local eq, same = T.eq, T.same

local net, inbox, queue, warnings, calls
local receiver_ante = 1

local function fake_game()
	local game = PVP.NET.inbox
	-- Every call an effect can make is a function of the game module: stub each one.
	for name, member in pairs(game) do
		if type(member) == "function" then
			game[name] = function(...) calls[#calls + 1] = { name, ... } end
		end
	end
	game.warn = function(message) warnings[#warnings + 1] = message end
	game.ante = function() return receiver_ante end
	return game
end

-- Runs the item's effect the way match_net does; false when the item is refused or has no effect.
local function apply(item)
	local effect = inbox.effects[item.effect]
	return effect ~= nil and pcall(effect, item)
end

local function apply_with_fakes(item)
	fake_game()
	return apply(item)
end

local function setup()
	queue, warnings, calls = {}, {}, {}
	PVP = { NET = {}, READ = {}, UI = {}, id = "MultiplayerPVP", UTILS = { is_pvp_blind = function() return false end } }
	love = { timer = { getTime = function() return 0 end } }
	sendWarnMessage = function(text) warnings[#warnings + 1] = text end
	G = {
		STAGE = "run",
		STAGES = { RUN = "run" },
		STATES = { BLIND_SELECT = 1, SHOP = 2, SELECTING_HAND = 3, BOOSTER = 9 },
		STATE = 2,
		STATE_COMPLETE = true,
		GAME = {},
		E_MANAGER = { add_event = function(_, event) queue[#queue + 1] = event end },
	}
	Event = function(fields) return fields end
	MPAPI = {
		playback = { is_driving = function() return false end },
		get_current_lobby = function() return { mod_id = "MultiplayerPVP" } end,
		send_match_input = function() return true end,
		run_save = { save_now = function() end },
	}
	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/net/_rules.lua")
	dofile("pvp_api/net/server_link.lua")
	dofile("pvp_api/read/_trap_record.lua")
	dofile("pvp_api/net/inbox.lua")
	net, inbox = PVP.NET, PVP.NET.inbox
end

local function run_queue()
	local rest = {}
	for _, event in ipairs(queue) do
		if not event.func() then rest[#rest + 1] = event end
	end
	queue = rest
end

setup()

-- One row per effect: the item as the server sends it, and the game calls it makes.
local function item(effect, amount, trap) return { itemNumber = 1, effect = effect, amount = amount, from = "b", trap = trap } end
local function trap(key, data)
	local record = { owner = "a" }
	for name, value in pairs(data or {}) do record[name] = value end
	return { id = 1, key = key, data = record }
end
local function fired(key) return { "show_trap_fired", key } end

local rows = {
	{ "pizza", item("pizza", 1), { { "add_discards", 1 } } },
	{ "pizza amount", item("pizza", 3), { { "add_discards", 3 } } },
	{ "gambling", item("gambling", 10), { { "gambling_payout", "j_mp_lets_go_gambling", 10 } } },
	{ "asteroid", item("asteroid", 1), { { "lower_best_hand", 1 } } },
	{ "comebackBonus", item("comebackBonus", 1), { { "add_comeback_bonus", 1 } } },
	{ "voucherLife", item("voucherLife", 1), { { "show_life_gained", 1 } } },
	{ "glyph", item("trapReward", 1, trap("c_mp_trap_glyph_of_warding")), { { "add_tag", "tag_mp_ward", nil, false }, fired("c_mp_trap_glyph_of_warding") } },
	{ "snare", item("trapReward", 1, trap("c_mp_trap_snare", { tag_key = "tag_double", orbital_hand = "Pair" })), { { "add_tag", "tag_double", "Pair", true }, fired("c_mp_trap_snare") } },
	{ "snare no orbital", item("trapReward", 1, trap("c_mp_trap_snare", { tag_key = "tag_double" })), { { "add_tag", "tag_double", nil, true }, fired("c_mp_trap_snare") } },
	{ "snare no tag", item("trapReward", 1, trap("c_mp_trap_snare")), { fired("c_mp_trap_snare") } },
	{ "alarm", item("trapReward", 1, trap("c_mp_trap_alarm", { rerolls = 2 })), { { "add_free_rerolls", 2 }, fired("c_mp_trap_alarm") } },
	{ "sepia", item("trapReward", 1, trap("c_mp_trap_sepia_snake_sigil", { key = "j_blueprint" })), { { "add_joker", "j_blueprint" }, fired("c_mp_trap_sepia_snake_sigil") } },
	{ "magic mouth", item("trapReward", 1, trap("c_mp_trap_magic_mouth", { card = "H4sIAAAA" })), { { "add_stolen_card", "H4sIAAAA" }, fired("c_mp_trap_magic_mouth") } },
	{ "web", item("trapReward", 1, trap("c_mp_trap_web", { key = "c_pluto", set = "Planet" })), { { "add_consumable", "c_pluto", true, "Planet" }, fired("c_mp_trap_web") } },
	{ "mental prison", item("trapReward", 1, trap("c_mp_trap_mental_prison")), { { "add_wheels", 2 }, fired("c_mp_trap_mental_prison") } },
	{ "faithful hound", item("trapReward", 1, trap("c_mp_trap_faithful_hound", { hand_type = "Flush" })), { { "level_up_hand", "Flush", 3 }, fired("c_mp_trap_faithful_hound") } },
	{ "phase door", item("trapReward", 1, trap("c_mp_trap_phase_door", { dollars = 12 })), { { "add_money", 12, true }, fired("c_mp_trap_phase_door") } },
}
for _, name in ipairs({ "symbol", "guards_and_wards", "programmed_illusion", "explosive_runes", "fire_trap", "arcane_lock", "forbiddance" }) do
	local key = "c_mp_trap_" .. name
	rows[#rows + 1] = { "show only " .. name, item("trapReward", 1, trap(key)), { fired(key) } }
end

for _, row in ipairs(rows) do
	calls = {}
	eq(apply_with_fakes(row[2]), true, row[1] .. " applied")
	same(calls, row[3], row[1] .. " calls")
end

-- What the server sends for an Arcane Lock bounce: the lock's own item, with empty data and no owner.
-- It reaches Lua as an empty table whether it was {} or [].
for _, key in ipairs({ "c_mp_trap_arcane_lock", "c_mp_trap_symbol", "c_mp_trap_mental_prison" }) do
	calls = {}
	local bounced = item("trapReward", 1, { id = 4, key = key, data = {} })
	eq(apply_with_fakes(bounced), true, key .. " with empty data applied")
	eq(calls[#calls][1], "show_trap_fired", key .. " is shown going off")
	eq(calls[#calls][2], key, key .. " by its key")
end
calls, warnings = {}, {}
eq(apply_with_fakes(item("trapReward", 1, { id = 4, key = "c_mp_trap_alarm", data = {} })), false, "empty data still refuses a trap that needs a field")

-- A Pizza carries the ante it was eaten for; its discards come off at the end of that ante's PvP blind,
-- so a receiver already in a later ante gets nothing.
local function pizza_for(ante)
	local it = item("pizza", 2)
	it.ante = ante
	return it
end
for _, row in ipairs({
	{ "same ante", 3, 3, { { "add_discards", 2 } } },
	{ "receiver behind", 2, 3, { { "add_discards", 2 } } },
	{ "no ante stamped", 5, nil, { { "add_discards", 2 } } },
	{ "receiver an ante ahead", 4, 3, {} },
}) do
	calls, warnings, receiver_ante = {}, {}, row[2]
	eq(apply_with_fakes(pizza_for(row[3])), true, "pizza " .. row[1] .. " is done")
	same(calls, row[4], "pizza " .. row[1] .. " calls")
	eq(#warnings, #row[4] == 0 and 1 or 0, "pizza " .. row[1] .. " logged when dropped")
end
receiver_ante = 1

-- A bad item is refused whole: no game call, a logged reason.
local refused = {
	{ "pizza without amount", item("pizza", nil) },
	{ "pizza zero", item("pizza", 0) },
	{ "pizza fraction", item("pizza", 1.5) },
	{ "pizza ante zero", pizza_for(0) },
	{ "pizza ante text", pizza_for("3") },
	{ "gambling text amount", item("gambling", "10") },
	{ "trap missing", item("trapReward", 1, nil) },
	{ "trap unknown key", item("trapReward", 1, trap("c_mp_trap_nothing")) },
	{ "trap no data", item("trapReward", 1, { id = 1, key = "c_mp_trap_alarm" }) },
	{ "alarm no rerolls", item("trapReward", 1, trap("c_mp_trap_alarm")) },
	{ "data not a table", item("trapReward", 1, { id = 1, key = "c_mp_trap_symbol", data = "x" }) },
	{ "alarm with an owner and no rerolls", item("trapReward", 1, { id = 1, key = "c_mp_trap_alarm", data = { owner = "a" } }) },
	{ "snare bad orbital", item("trapReward", 1, trap("c_mp_trap_snare", { tag_key = "t", orbital_hand = 2 })) },
	{ "sepia no card", item("trapReward", 1, trap("c_mp_trap_sepia_snake_sigil")) },
	{ "sepia old name", item("trapReward", 1, trap("c_mp_trap_sepia_snake_sigil", { cardKey = "j_blueprint" })) },
	{ "magic mouth no card", item("trapReward", 1, trap("c_mp_trap_magic_mouth")) },
	{ "web empty key", item("trapReward", 1, trap("c_mp_trap_web", { key = "", set = "Planet" })) },
	{ "web no set", item("trapReward", 1, trap("c_mp_trap_web", { key = "c_pluto" })) },
	{ "hound no hand", item("trapReward", 1, trap("c_mp_trap_faithful_hound")) },
	{ "hound old name", item("trapReward", 1, trap("c_mp_trap_faithful_hound", { hand = "Flush" })) },
	{ "phase door zero", item("trapReward", 1, trap("c_mp_trap_phase_door", { dollars = 0 })) },
	{ "phase door old name", item("trapReward", 1, trap("c_mp_trap_phase_door", { golds = 3 })) },
	{ "unknown effect", item("pennyPincher", 1) },
}
for _, row in ipairs(refused) do
	calls, warnings = {}, {}

	local ok = apply_with_fakes(row[2])
	eq(ok, false, row[1] .. " refused")
	eq(#calls, 0, row[1] .. " made no call")
end

-- Through the real runner.
local function in_run(inbox_items, inbox_done)
	G.GAME.pvp_net = { runId = "run1", inboxDone = inbox_done or 0, totals = {} }
	return {
		serverTime = 1000, lastMessageReceived = 0, me = "a", match = { run = { id = "run1" } }, players = {},
		onlyMine = { inbox = inbox_items, inboxNewest = #inbox_items },
	}
end
local function numbered(number, effect, amount) return { itemNumber = number, effect = effect, amount = amount, from = "b" } end

local function start(view_value)
	fake_game()
	net.handlers = inbox.effects
	net.receive_view("lobby", view_value)
	run_queue()
end

-- At a safe point the item is applied and inboxDone moves.
setup()
start(in_run({ numbered(1, "pizza", 2), numbered(2, "gambling", 10) }))
eq(G.GAME.pvp_net.inboxDone, 1, "one item per safe point")
local order = {}
for _, call in ipairs(calls) do order[#order + 1] = call[1] end
same(order, { "add_discards" }, "first item applied")

-- Blind select, shop and picking a hand are the safe states (match_net's rule).
for _, name in ipairs({ "BLIND_SELECT", "SHOP", "SELECTING_HAND" }) do
	setup()
	G.STATE = G.STATES[name]
	start(in_run({ numbered(1, "pizza", 2) }))
	eq(G.GAME.pvp_net.inboxDone, 1, name .. " is a safe state")
end

-- Once only: the save holds inboxDone with the effect; a load and the same view apply nothing.
setup()
local one_view = in_run({ numbered(1, "pizza", 2) })
start(one_view)
eq(#calls, 1, "applied once")
eq(G.GAME.pvp_net.inboxDone, 1, "saved number moved")
local saved = G.GAME.pvp_net
setup()
G.GAME.pvp_net = { runId = saved.runId, inboxDone = saved.inboxDone, totals = {} }
start({ serverTime = 1000, lastMessageReceived = 0, me = "a", match = { run = { id = "run1" } }, players = {}, onlyMine = one_view.onlyMine })
eq(#calls, 0, "not applied again after a load")
eq(G.GAME.pvp_net.inboxDone, 1, "number kept after a load")

-- A save from before the item still applies it, once.
setup()
G.GAME.pvp_net = { runId = "run1", inboxDone = 0, totals = {} }
start({ serverTime = 1000, lastMessageReceived = 0, me = "a", match = { run = { id = "run1" } }, players = {}, onlyMine = one_view.onlyMine })
eq(#calls, 1, "an older save applies it again once")

-- A refused item still moves the number, so the items behind it are not blocked.
setup()
start(in_run({ numbered(1, "pizza", 0) }))
eq(G.GAME.pvp_net.inboxDone, 1, "a refused item moves the number")
eq(#calls, 0, "a refused item changes nothing")
eq(#warnings, 1, "a refused item is logged by match_net")

-- An effect with no handler is logged by match_net and moves the number.
setup()
start(in_run({ numbered(1, "pennyPincher", 1) }))
eq(G.GAME.pvp_net.inboxDone, 1, "an unknown effect moves the number")
eq(#calls, 0, "an unknown effect changes nothing")
eq(#warnings, 1, "an unknown effect is logged")

T.done("inbox_handlers_test")
