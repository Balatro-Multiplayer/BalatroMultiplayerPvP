-- Plain Lua test for the trap reconcile in lib/trap_utils.lua: the pure plan (PVP.TRAP.reconcile_plan) and
-- the shell that applies it to a fake consumables area. Run from the repo root: luajit tests/unit/trap_reconcile_test.lua
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

local state, built, consumed, logs, lost_reports, reports

local function setup(opts)
	opts = opts or {}
	state, built, consumed, logs, lost_reports, reports = {}, {}, {}, {}, {}, {}
	MPAPI = {
		get_current_lobby = function()
			return { player_id = "me", mod_id = "pvp", _nakama = true, _game = { started = { run_id = "run1" } } }
		end,
		get_state = function(key)
			return state[key]
		end,
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
		match_log = function(_, text)
			logs[#logs + 1] = text
		end,
		UI = {},
		GAME = opts.game or {},
		current_run_id = function()
			return "run1"
		end,
		StateValue = {
			same_run = function(value, run_id)
				return type(value) == "table" and value.runId ~= nil and tostring(value.runId) == tostring(run_id)
			end,
		},
		TrapsNet = {
			report = function(id)
				local entry = PVP.GAME.traps_sent.ids[tostring(id)]
				reports[#reports + 1] = { id = id, kind = entry.kind, data = entry.data }
				if entry.kind == "pvp.trap_lost" then lost_reports[#lost_reports + 1] = id end
			end,
		},
	}
	G = { consumeables = { cards = {} }, E_MANAGER = { add_event = function() end } }
	SMODS = {
		add_card = function(args)
			local card = { ability = {}, config = { center = { key = args.key } } }
			built[#built + 1] = card
			table.insert(G.consumeables.cards, card)
			return card
		end,
	}
	dofile("lib/trap_utils.lua")
	-- The reveal needs the whole game; the shell test only wants to know which cards were consumed.
	PVP.TRAP.reveal_and_consume = function(card)
		consumed[#consumed + 1] = card.ability.mp_trap_id
	end
	PVP.TRAP.disguise = function(card)
		card.ability.mp_trap_hidden = true
	end
end

local function value(traps)
	return { runId = "run1", trapSeq = #traps, traps = traps }
end

local function trap(id, state_, holder)
	return { id = id, key = "c_mp_trap_alarm", owner = "they", holder = holder or "me", state = state_ }
end

local function card_of(id, fired)
	return { id = id, fired = fired or false }
end

local function ids(list)
	local out = {}
	for _, v in ipairs(list) do
		out[#out + 1] = type(v) == "table" and tostring(v.id) or tostring(v)
	end
	return table.concat(out, ",")
end

test("plan: a live trap I hold with no card is built", function()
	setup()
	local plan = PVP.TRAP.reconcile_plan(value({ trap(1, "live") }), "me", {}, {}, {})
	equal(ids(plan.build), "1")
	equal(#plan.consume, 0)
end)

test("plan: a card I already have is not built again", function()
	setup()
	local plan = PVP.TRAP.reconcile_plan(value({ trap(1, "live") }), "me", { card_of(1) }, {}, {})
	equal(#plan.build, 0)
	equal(#plan.consume, 0)
end)

test("plan: a trap held by someone else is not built", function()
	setup()
	local plan = PVP.TRAP.reconcile_plan(value({ trap(1, "live", "they") }), "me", {}, {}, {})
	equal(#plan.build, 0)
end)

test("plan: a fired or lost trap is never built", function()
	setup()
	local plan = PVP.TRAP.reconcile_plan(value({ trap(1, { fired = {} }), trap(2, "lost") }), "me", {}, {}, {})
	equal(#plan.build, 0)
end)

test("plan: an id I fired and sent is not built before the record settles", function()
	setup()
	local plan = PVP.TRAP.reconcile_plan(value({ trap(1, "live") }), "me", {}, { ["1"] = true }, {})
	equal(#plan.build, 0)
end)

test("plan: a card whose card was already consumed is not built again", function()
	setup()
	local plan = PVP.TRAP.reconcile_plan(value({ trap(1, "live") }), "me", {}, {}, { ["1"] = true })
	equal(#plan.build, 0)
end)

test("plan: a card whose trap the record says fired is consumed once", function()
	setup()
	local v = value({ trap(1, { fired = {} }), trap(2, "lost") })
	local plan = PVP.TRAP.reconcile_plan(v, "me", { card_of(1), card_of(2) }, {}, {})
	equal(ids(plan.consume), "1,2")
	plan = PVP.TRAP.reconcile_plan(v, "me", { card_of(1), card_of(2) }, {}, { ["1"] = true, ["2"] = true })
	equal(#plan.consume, 0)
end)

test("plan: a card already revealing is not consumed again", function()
	setup()
	local plan = PVP.TRAP.reconcile_plan(value({ trap(1, { fired = {} }) }), "me", { card_of(1, true) }, {}, {})
	equal(#plan.consume, 0)
end)

test("plan: a spent id in sent is settled", function()
	setup()
	local plan = PVP.TRAP.reconcile_plan(value({ trap(1, { fired = {} }), trap(2, "live") }), "me", {}, { ["1"] = true, ["2"] = true }, {})
	equal(ids(plan.settled), "1")
end)

test("plan: no record does nothing", function()
	setup()
	local plan = PVP.TRAP.reconcile_plan(nil, "me", { card_of(1) }, {}, {})
	equal(#plan.build + #plan.consume + #plan.settled, 0)
end)

test("plan: an unknown state is neither built nor consumed", function()
	setup()
	local plan = PVP.TRAP.reconcile_plan(value({ trap(1, "weird") }), "me", { card_of(1) }, {}, {})
	equal(#plan.build + #plan.consume, 0)
end)

test("reconcile: a plant made while I was away is built from the record, with the server id", function()
	setup()
	state["pvp.traps"] = value({ trap(7, "live") })
	PVP.TRAP.reconcile()
	equal(#built, 1)
	equal(built[1].ability.mp_trap_id, 7)
	equal(built[1].ability.mp_trap_hidden, true)
	equal(built[1].config.center.key, "c_mp_trap_alarm")
end)

test("reconcile: run twice, the trap is built once", function()
	setup()
	state["pvp.traps"] = value({ trap(7, "live") })
	PVP.TRAP.reconcile()
	PVP.TRAP.reconcile()
	equal(#built, 1)
end)

test("reconcile: a fired trap is not rebuilt, and an old record of another run is ignored", function()
	setup()
	state["pvp.traps"] = value({ trap(7, { fired = {} }) })
	PVP.TRAP.reconcile()
	equal(#built, 0)
	state["pvp.traps"] = { runId = "old", traps = { trap(8, "live") } }
	PVP.TRAP.reconcile()
	equal(#built, 0)
end)

test("reconcile: an id I fired and sent is not rebuilt", function()
	setup({ game = { traps_sent = { runId = "run1", ids = { ["7"] = true } } } })
	state["pvp.traps"] = value({ trap(7, "live") })
	PVP.TRAP.reconcile()
	equal(#built, 0)
end)

test("reconcile: an orphan card of a spent trap is consumed once", function()
	setup()
	local card = { ability = { mp_trap_hidden = true, mp_trap_id = 3 }, config = { center = { key = "c_mp_trap_alarm" } } }
	G.consumeables.cards[1] = card
	state["pvp.traps"] = value({ trap(3, "lost") })
	PVP.TRAP.reconcile()
	PVP.TRAP.reconcile()
	equal(#consumed, 1)
	equal(consumed[1], 3)
	equal(card.ability.mp_trap_fired, true)
end)

test("reconcile: settled ids leave the sent set", function()
	setup({ game = { traps_sent = { runId = "run1", ids = { ["7"] = true, ["8"] = true } } } })
	state["pvp.traps"] = value({ trap(7, { fired = {} }), trap(8, "live") })
	PVP.TRAP.reconcile()
	equal(PVP.GAME.traps_sent.ids["7"], nil)
	equal(PVP.GAME.traps_sent.ids["8"], true)
end)

test("pending: a live trap with a kept report is listed, in the record's order", function()
	setup()
	local sent = { ["2"] = { kind = "pvp.trap_fire", data = { key = "k" } }, ["1"] = { kind = "pvp.trap_lost" } }
	local list = PVP.TRAP.pending_reports(value({ trap(1, "live"), trap(2, "live") }), sent)
	equal(#list, 2)
	equal(list[1].id, 1)
	equal(list[1].kind, "pvp.trap_lost")
	equal(list[2].data.key, "k")
end)

test("pending: a settled trap, a trap with no report and a bare true are not listed", function()
	setup()
	local sent = { ["1"] = { kind = "pvp.trap_fire" }, ["2"] = { kind = "pvp.trap_fire" }, ["3"] = true }
	local list = PVP.TRAP.pending_reports(value({ trap(1, { fired = {} }), trap(2, "lost"), trap(3, "live"), trap(4, "live") }), sent)
	equal(#list, 0)
	equal(#PVP.TRAP.pending_reports(nil, sent), 0)
end)

test("pending: a report the server refused for good is not listed", function()
	setup()
	local sent = { ["1"] = { kind = "pvp.trap_fire", given_up = true }, ["2"] = { kind = "pvp.trap_lost" } }
	local list = PVP.TRAP.pending_reports(value({ trap(1, "live"), trap(2, "live") }), sent)
	equal(#list, 1)
	equal(list[1].id, 2)
end)

test("fire: the report is kept in the carried record with its data, and sent through the net", function()
	setup()
	local card = { ability = { mp_trap_id = 5 }, config = { center = { key = "c_mp_trap_web" } } }
	PVP.TRAP.fire(card, { key = "c_x", set = "Tarot" })
	local kept = PVP.GAME.traps_sent.ids["5"]
	equal(kept.kind, "pvp.trap_fire")
	equal(kept.data.key, "c_x")
	equal(#reports, 1)
	PVP.TRAP.fire({ ability = { mp_trap_id = 6 }, config = { center = { key = "c_mp_trap_alarm" } } })
	equal(PVP.GAME.traps_sent.ids["6"].data, nil, "a trap with no data keeps none")
end)

test("fire: a fire during the catch-up is kept and not rebuilt, and a settled record forgets it", function()
	setup()
	state["pvp.traps"] = value({ trap(7, "live") })
	PVP.TRAP.fire({ ability = { mp_trap_id = 7 }, config = { center = { key = "c_mp_trap_alarm" } } })
	PVP.TRAP.reconcile()
	equal(#built, 0, "not rebuilt while its report is unsettled")
	equal(PVP.GAME.traps_sent.ids["7"].kind, "pvp.trap_fire")
	state["pvp.traps"] = value({ trap(7, { fired = {} }) })
	PVP.TRAP.reconcile()
	equal(PVP.GAME.traps_sent.ids["7"], nil)
end)

test("reconcile: a reload never reports a lost trap", function()
	setup()
	state["pvp.traps"] = value({ trap(7, "live") })
	PVP.TRAP.reconcile()
	-- The game removing every card on a reload does not go through start_dissolve.
	G.consumeables.cards = {}
	PVP.TRAP.reconcile()
	equal(#lost_reports, 0)
	equal(#built, 2)
end)

test("lost: a hidden unfired trap destroyed by the game is reported once and not rebuilt", function()
	setup()
	state["pvp.traps"] = value({ trap(7, "live") })
	PVP.TRAP.reconcile()
	local card = built[1]
	card.area = G.consumeables
	Card.start_dissolve(card)
	equal(#lost_reports, 1)
	equal(lost_reports[1], 7)
	G.consumeables.cards = {}
	PVP.TRAP.reconcile()
	equal(#built, 1, "not rebuilt while the loss is unsettled")
end)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
