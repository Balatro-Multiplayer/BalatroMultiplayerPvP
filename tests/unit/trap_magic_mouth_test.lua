-- Run from the repo root: luajit tests/unit/trap_magic_mouth_test.lua
-- lib/trap_utils_magic_mouth.lua: a Magic Mouth takes the seal reward card from its holder only when
-- its fire can be sent; a card the server would refuse stays with its player and the trap stays live.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local warnings = {}
function sendWarnMessage(text) warnings[#warnings + 1] = text end
MPAPI = {
	serialize_card = function(card) return card.text end,
	playback = { is_driving = function() return false end },
}

local queue = {}
local fired = {}
G = {
	GAME = { consumeable_buffer = 0 },
	E_MANAGER = { add_event = function(_, event) queue[#queue + 1] = event end },
	consumeables = {
		cards = {},
		remove_card = function(self, card)
			for place, held in ipairs(self.cards) do
				if held == card then table.remove(self.cards, place) return end
			end
		end,
	},
}
Event = function(fields) return fields end
Game = { update = function() end }
-- The seal methods: a fired seal raises the buffer and makes its reward card in a queued event.
local reward_text
local function seal_method(self)
	G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
	G.E_MANAGER:add_event(Event({
		func = function()
			G.consumeables.cards[#G.consumeables.cards + 1] = { text = reward_text, removed = false, remove = function(card) card.removed = true end }
			return true
		end,
	}))
	return {}, nil
end
Card = {
	get_end_of_round_effect = seal_method,
	calculate_seal = seal_method,
	can_sell_card = function() return true end,
	start_dissolve = function() end,
}
PVP = { NET = {}, READ = {}, LOBBY = { in_session = function() return true end }, UI = {} }

dofile("lib/run_totals.lua")
dofile("pvp_api/read/_view.lua")
dofile("pvp_api/read/_trap_record.lua")
dofile("pvp_api/read/trap.lua")
dofile("pvp_api/ui/trap.lua")
dofile("lib/trap_utils.lua")
PVP.TRAP.fire = function(trap, data) fired[#fired + 1] = { trap = trap, data = data } end
dofile("lib/trap_utils_magic_mouth.lua")

local function run_queue()
	local events = queue
	queue = {}
	for _, event in ipairs(events) do event.func() end
end

local function trap_card()
	return {
		ability = { mp_trap_hidden = true, mp_trap_id = 5, mp_trap_owner_id = "b" },
		config = { center = { key = PVP.TRAP.KEY.MAGIC_MOUTH } },
	}
end

local function open_seal(trap, text)
	G.consumeables.cards = { trap }
	G.GAME.consumeable_buffer = 0
	reward_text, fired, warnings = text, {}, {}
	local seal_holder = { seal = "Blue" }
	Card.get_end_of_round_effect(seal_holder, {})
	run_queue()
	return seal_holder
end

-- A card that fits is taken from its holder and sent to the Trapper.
local trap = trap_card()
open_seal(trap, string.rep("x", 540))
eq(#fired, 1, "a card that fits makes the trap fire")
eq(fired[1].data.card, string.rep("x", 540), "with the card")
eq(#G.consumeables.cards, 1, "and the card left its holder")
eq(#warnings, 0, "nothing is logged")

-- A card over the server's size is not taken: it stays, the trap stays hidden and has not fired.
trap = trap_card()
open_seal(trap, string.rep("x", 1100))
eq(#fired, 0, "a card over the cap does not make the trap fire")
eq(#G.consumeables.cards, 2, "the reward card stays with its player")
eq(G.consumeables.cards[2].removed, false, "and is not removed")
eq(trap.ability.mp_trap_fired, nil, "the trap has not gone off")
eq(trap.ability.mp_trap_hidden, true, "and stays hidden")
eq(#warnings, 1, "it is logged")
eq(warnings[1]:find("1024", 1, true) ~= nil, true, "with the cap")

-- Nothing of this is sent or counted by the check: no total of the trap's going off was used.
eq(G.GAME.pvp_net, nil, "the check wrote nothing to the run")

-- The other seal method behaves the same.
trap = trap_card()
G.consumeables.cards = { trap }
G.GAME.consumeable_buffer, reward_text, fired = 0, string.rep("x", 2000), {}
Card.calculate_seal({ seal = "Purple" }, {})
run_queue()
eq(#fired, 0, "a Purple Seal's oversized reward is left too")

T.done("trap_magic_mouth_test")
