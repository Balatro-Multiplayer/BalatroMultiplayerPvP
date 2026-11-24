-- Run from the repo root: luajit tests/unit/trap_screen_test.lua
-- pvp_api/trap_screen.lua: each trap input is sent once (and never again after a load), nothing is sent
-- without a view, and my trap cards and the Nemesis row follow the view.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local function show(value)
	if type(value) ~= "table" then return tostring(value) end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. show(value[key]) end
	return "{" .. table.concat(parts, ",") .. "}"
end
local function same(actual, expected, message) eq(show(actual), show(expected), message) end

local sent = {}
local net
net = {
	view = nil,
	refuse = false,
	send = function(kind, body)
		if not net.view or net.refuse then return nil end
		sent[#sent + 1] = { kind = kind, body = body }
		return #sent
	end,
}
function net.send_live(kind, body)
	if not body or MPAPI.playback.is_driving("pvp") then return nil end
	return net.send(kind, body)
end

local refreshes, revealed, disguised = 0, {}, {}
local in_session = true
PVP = {
	match_net = net,
	in_session = function() return in_session end,
	TRAP = {
		disguise = function(card)
			card.ability.mp_trap_hidden = true
			disguised[#disguised + 1] = card.ability.mp_trap_id
		end,
		reveal_and_consume = function(card) revealed[#revealed + 1] = card.ability.mp_trap_id end,
	},
	TRAP_ROW = { refresh = function() refreshes = refreshes + 1 end },
}
local dissolved = 0
Card = setmetatable({ start_dissolve = function() dissolved = dissolved + 1 end }, {
	__call = function(_, _, _, _, _, _, center)
		return { ability = {}, config = { center = center }, add_to_deck = function() end }
	end,
})
local update_ref_calls = 0
Game = { update = function() update_ref_calls = update_ref_calls + 1 end }
local consumeables = {
	T = { x = 0, y = 0, w = 1 },
	cards = {},
	emplace = function(self, card) self.cards[#self.cards + 1] = card end,
}
G = {
	CARD_W = 1,
	CARD_H = 1,
	P_CENTERS = { c_mp_trap_alarm = { key = "c_mp_trap_alarm" }, c_mp_trap_symbol = { key = "c_mp_trap_symbol" } },
	GAME = { pvp_net = { totals = {}, runId = "run1" } },
	consumeables = consumeables,
}
local warnings = {}
function sendWarnMessage(text) warnings[#warnings + 1] = text end
local driving = nil
MPAPI = { playback = { is_driving = function(namespace) return driving == namespace end } }

dofile("lib/run_totals.lua")
dofile("pvp_api/_view.lua")
dofile("pvp_api/_trap_data.lua")
dofile("pvp_api/trap_reader.lua")
dofile("pvp_api/trap_screen.lua")
local screen = PVP.trap_screen

local function take()
	local out = sent
	sent = {}
	return out
end

local function trap_card(key, id, owner)
	return { ability = { mp_trap_id = id, mp_trap_owner_id = owner, mp_trap_hidden = true }, config = { center = { key = key } } }
end

-- Nothing is sent, and no total counted, without a view. A trap that went off with nowhere to report
-- it is gone here all the same, and the warning says it was not told.
screen.planted("c_mp_trap_alarm")
screen.fired(trap_card("c_mp_trap_symbol", 1, "b"), { owner = "b" })
screen.lost(trap_card("c_mp_trap_symbol", 2, "b"))
eq(#take(), 0, "no view: nothing sent")
same(G.GAME.pvp_net.traps_gone, { ["1"] = true }, "no view: only the trap that went off is counted, as gone")
eq(warnings[#warnings]:find("gone here and the server was not told", 1, true) ~= nil, true, "and it is logged")
G.GAME.pvp_net.totals = {}
warnings = {}

net.view ={ me = "a", match = { run = { id = "run1" } }, onlyMine = { traps = {} } }

-- Plant: one input per trap card taken, counted per key.
screen.planted("c_mp_trap_alarm")
screen.planted("c_mp_trap_alarm")
screen.planted("c_mp_trap_symbol")
same(take(), {
	{ kind = "trapPlant", body = { key = "c_mp_trap_alarm", total = 1 } },
	{ kind = "trapPlant", body = { key = "c_mp_trap_alarm", total = 2 } },
	{ kind = "trapPlant", body = { key = "c_mp_trap_symbol", total = 1 } },
}, "plant")

-- A plant the net refuses is not counted: the next one carries the next total, with no gap.
net.refuse = true
screen.planted("c_mp_trap_alarm")
net.refuse = false
eq(#take(), 0, "a refused plant sends nothing")
eq(G.GAME.pvp_net.totals["trap:c_mp_trap_alarm"], 2, "and uses no total")
screen.planted("c_mp_trap_alarm")
same(take(), { { kind = "trapPlant", body = { key = "c_mp_trap_alarm", total = 3 } } }, "the next plant follows with no gap")
screen.planted("not_a_trap")
eq(#take(), 0, "a plant that cannot be built is not sent")
eq(G.GAME.pvp_net.totals["trap:not_a_trap"], nil, "and is not counted")

-- Fire: the server's body, once.
local alarm = trap_card("c_mp_trap_alarm", 5, "b")
screen.fired(alarm, { owner = "b", rerolls = 2 })
same(take(), { { kind = "trapFire", body = { trapId = 5, data = { owner = "b", rerolls = 2 } } } }, "fire")
screen.fired(alarm, { owner = "b", rerolls = 2 })
eq(#take(), 0, "fire is sent once")
-- ... and not again after a load: the gone set is kept with the run.
local saved_totals, saved_gone = G.GAME.pvp_net.totals, G.GAME.pvp_net.traps_gone
G.GAME.pvp_net = { totals = saved_totals, traps_gone = saved_gone, runId = "run1" }
screen.fired(trap_card("c_mp_trap_alarm", 5, "b"), { owner = "b", rerolls = 2 })
eq(#take(), 0, "fire is not sent again after a load")

-- A fire that cannot be built is not sent. The trap went off all the same: it is gone, the server is
-- told it was lost, and it is never fired or lost again.
local bad = trap_card("c_mp_trap_alarm", 6, "b")
screen.fired(bad, { owner = "b" })
same(take(), { { kind = "trapLost", body = { trapId = 6 } } }, "a bad fire sends the trap as lost")
eq(G.GAME.pvp_net.traps_gone["6"], true, "and counts it as gone")
screen.fired(bad, { owner = "b", rerolls = 2 })
screen.lost(bad)
eq(#take(), 0, "it is not sent again")
-- A fire the net refuses: gone here; the lost refused too is logged.
net.refuse = true
warnings = {}
screen.fired(trap_card("c_mp_trap_alarm", 12, "b"), { owner = "b", rerolls = 2 })
net.refuse = false
eq(#take(), 0, "a refused fire and a refused lost send nothing")
eq(G.GAME.pvp_net.traps_gone["12"], true, "the trap is gone here")
eq(#warnings, 1, "one warning")
eq(warnings[1]:find("gone here and the server was not told", 1, true) ~= nil, true, "that says so")
G.consumeables.cards = {}
net.view = { me = "a", match = { run = { id = "run1" } }, onlyMine = { traps = { { id = 12, key = "c_mp_trap_alarm", owner = "b", holder = "a", state = "live" } } } }
screen.update()
eq(#consumeables.cards, 0, "a trap that went off is not dealt again from the view's live copy")
refreshes = 0
net.view = { me = "a", match = { run = { id = "run1" } }, onlyMine = { traps = {} } }
-- The server's trap number is needed to say anything: with none nothing is sent or counted.
local before_totals = show(G.GAME.pvp_net.totals)
screen.fired(trap_card("c_mp_trap_alarm", nil, "b"), { owner = "b", rerolls = 2 })
eq(#take(), 0, "a card with no number from the server sends nothing")
eq(show(G.GAME.pvp_net.totals), before_totals, "and counts nothing")

-- A fire over the server's size is built into nothing: the trap is lost, never sent half.
screen.fired(trap_card("c_mp_trap_magic_mouth", 13, "b"), { owner = "b", card = string.rep("x", 1100) })
same(take(), { { kind = "trapLost", body = { trapId = 13 } } }, "a card over the cap loses the trap")
-- What a trap asks before it takes something.
eq(screen.fire_problem(trap_card("c_mp_trap_magic_mouth", 14, "b"), { owner = "b", card = "x" }), nil, "a card that fits has no problem")
eq(screen.fire_problem(trap_card("c_mp_trap_magic_mouth", 14, "b"), { owner = "b", card = string.rep("x", 1100) }):find("1024", 1, true) ~= nil, true, "a card over the cap says so")
eq(#take(), 0, "asking sends nothing")
eq((G.GAME.pvp_net.traps_gone or {})["14"], nil, "and counts nothing")

-- A replay, a fast-forward or a rejoin load sends nothing and counts nothing.
driving = "pvp"
screen.planted("c_mp_trap_alarm")
screen.fired(trap_card("c_mp_trap_alarm", 15, "b"), { owner = "b", rerolls = 1 })
screen.fired(trap_card("c_mp_trap_alarm", 16, "b"), { owner = "b" })
screen.lost(trap_card("c_mp_trap_symbol", 17, "b"))
eq(#take(), 0, "playback: nothing is sent")
eq(G.GAME.pvp_net.totals["trap:c_mp_trap_alarm"], 3, "and no plant total is used")
for _, number in ipairs({ 15, 16, 17 }) do eq((G.GAME.pvp_net.traps_gone or {})[tostring(number)], nil, "playback: trap " .. number .. " is not gone") end
driving = "other"
screen.planted("c_mp_trap_alarm")
driving = nil
same(take(), { { kind = "trapPlant", body = { key = "c_mp_trap_alarm", total = 4 } } }, "another mod's playback does not silence the plant")

-- Lost: once, and not for a trap that went off.
local lost = trap_card("c_mp_trap_symbol", 7, "b")
screen.lost(lost)
same(take(), { { kind = "trapLost", body = { trapId = 7 } } }, "lost")
screen.lost(lost)
eq(#take(), 0, "lost is sent once")
screen.fired(lost, { owner = "b" })
eq(#take(), 0, "a lost trap does not fire")
screen.fired(trap_card("c_mp_trap_symbol", 8, "b"), { owner = "b" })
take()
screen.lost(trap_card("c_mp_trap_symbol", 8, "b"))
eq(#take(), 0, "a trap that went off is not lost")

-- Dissolving a hidden trap that has not gone off sends lost; a revealed one, a plain card and a game
-- outside a match send nothing.
local hooked = Card.start_dissolve
local hidden = trap_card("c_mp_trap_symbol", 9, "b")
hooked(hidden)
same(take(), { { kind = "trapLost", body = { trapId = 9 } } }, "dissolving a hidden trap loses it")
eq(dissolved, 1, "the dissolve still happens")
local went_off = trap_card("c_mp_trap_symbol", 10, "b")
went_off.ability.mp_trap_fired = true
hooked(went_off)
hooked({ ability = {} })
in_session = false
hooked(trap_card("c_mp_trap_symbol", 11, "b"))
in_session = true
eq(#take(), 0, "no lost for a trap that went off, a plain card, or outside a match")

-- The view: a trap I hold gets its card once; a trap the server says has gone off is revealed once.
local function view_with(list) return { me = "a", match = { run = { id = "run1" } }, onlyMine = { traps = list } } end
local function entry(id, owner, holder, state) return { id = id, key = "c_mp_trap_alarm", owner = owner, holder = holder, state = state } end
G.GAME.pvp_net = { totals = {}, runId = "run1" }
net.view = view_with({ entry(20, "b", "a", "live"), entry(21, "a", "b", "live") })
screen.update()
eq(#consumeables.cards, 1, "a held trap gets a card")
eq(consumeables.cards[1].ability.mp_trap_id, 20, "the card has the server's number")
eq(consumeables.cards[1].ability.mp_trap_owner_id, "b", "the card knows its Trapper")
same(disguised, { 20 }, "the card is disguised")
screen.update()
screen.update()
eq(#consumeables.cards, 1, "not dealt again")
eq(refreshes, 1, "the row is refreshed once per change")
net.view = view_with({ entry(20, "b", "a", "fired"), entry(21, "a", "b", "live") })
screen.update()
same(revealed, { 20 }, "a trap the server fired is revealed")
eq(consumeables.cards[1].ability.mp_trap_fired, true, "marked as gone off")
screen.update()
same(revealed, { 20 }, "revealed once")
eq(refreshes, 2, "the row is refreshed for the new state")
eq(#take(), 0, "following the view sends nothing")
-- The revealed card leaves after its delay; the trap is gone here, so it is not dealt again.
eq(G.GAME.pvp_net.traps_gone["20"], true, "a trap revealed through the view is counted as gone")
consumeables.cards = {}
screen.update()
eq(#consumeables.cards, 0, "the revealed trap's card is not added back on the next update")
net.view = view_with({ entry(20, "b", "a", "live"), entry(21, "a", "b", "live") })
screen.update()
eq(#consumeables.cards, 0, "nor from a live copy of it")
net.view = view_with({ entry(20, "b", "a", "fired"), entry(21, "a", "b", "live") })

-- Not my run's view: nothing is dealt.
G.GAME.pvp_net = { totals = {}, runId = "run2" }
consumeables.cards = {}
net.view = view_with({ entry(30, "b", "a", "live") })
screen.update()
eq(#consumeables.cards, 0, "a view of another run deals nothing")

-- The update hook runs the game's update first and survives an error.
Game.update(Game, 0)
eq(update_ref_calls, 1, "the game's update still runs")

print("trap_screen_test: ok (" .. checks .. " checks)")
