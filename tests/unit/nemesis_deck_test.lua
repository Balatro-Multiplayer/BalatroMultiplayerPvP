-- Plain Lua test for G.FUNCS.load_nemesis_deck (networking/action_handlers.lua).
-- Run from the repo root: luajit tests/unit/nemesis_deck_test.lua
G = {
	FUNCS = {},
	CARD_W = 1,
	CARD_H = 1,
	P_CARDS = { S_A = { name = "S_A" }, H_K = { name = "H_K" } },
	P_CENTERS = { c_base = { name = "c_base" }, m_glass = { name = "m_glass" }, e_foil = {} },
	P_SEALS = { Red = {} },
}
PVP = { UTILS = {}, LOBBY = { code = "ABCDE" } }
function sendDebugMessage() end

function Card(x, y, w, h, front, center)
	return {
		front = front,
		center = center,
		set_edition = function(self, edition)
			self.edition = edition
		end,
		set_seal = function(self, seal)
			self.seal = seal
		end,
	}
end

-- Same order as vanilla: the card joins G.playing_cards before area:emplace runs.
function create_playing_card(init, area)
	G.playing_card = (G.playing_card or 0) + 1
	local card = Card(0, 0, 1, 1, init.front, init.center or G.P_CENTERS.c_base)
	table.insert(G.playing_cards, card)
	area:emplace(card)
	return card
end

-- PvP's double-emplace guard walks self.cards first, so a removed area (cards = nil) errors.
local function make_area(cards)
	return {
		cards = cards,
		T = { x = 0, y = 0 },
		emplace = function(self, card)
			for _, v in pairs(self.cards) do
				if v == card then
					return
				end
			end
			self.cards[#self.cards + 1] = card
		end,
	}
end

-- action_handlers.lua needs the whole game to load, so load just this one function from it.
local function load_function(path, header)
	local file = assert(io.open(path, "r"))
	local text = file:read("*a")
	file:close()
	local start = assert(text:find(header, 1, true), "function not found: " .. header)
	local _, finish = text:find("\nend\r?\n", start)
	assert(finish, "end of function not found")
	assert((loadstring or load)(text:sub(start, finish)))()
end

dofile("lib/string_utils.lua")
load_function("networking/action_handlers.lua", "function G.FUNCS.load_nemesis_deck()")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local DECK = ";S-A-m_glass-foil-Red;H-K-none-none-none"

local function own_deck(n)
	local cards = {}
	for i = 1, n do
		cards[i] = { own = i }
	end
	return cards
end

do
	-- The area from an earlier end screen was removed with that run: CardArea:remove sets cards = nil.
	G.playing_cards = own_deck(52)
	PVP.nemesis_deck = make_area(nil)
	PVP.nemesis_cards = {}
	PVP.nemesis_deck_string = DECK
	local ok = pcall(G.FUNCS.load_nemesis_deck)
	check("removed area: loading does not error", ok, true)
	check("removed area: own deck keeps 52 cards", #G.playing_cards, 52)
end

do
	G.playing_cards = own_deck(52)
	G.playing_card = 52
	PVP.nemesis_deck = make_area({})
	PVP.nemesis_cards = {}
	PVP.nemesis_deck_string = DECK
	G.FUNCS.load_nemesis_deck()
	check("live area: both nemesis cards are loaded", #PVP.nemesis_cards, 2)
	check("live area: both cards are in the area", #PVP.nemesis_deck.cards, 2)
	check("live area: own deck keeps 52 cards", #G.playing_cards, 52)
	check("live area: own last card is untouched", G.playing_cards[52].own, 52)
	check("live area: own card id counter is untouched", G.playing_card, 52)
	local first = PVP.nemesis_cards[1]
	check("live area: front kept", first.front, G.P_CARDS.S_A)
	check("live area: enhancement kept", first.center, G.P_CENTERS.m_glass)
	check("live area: edition kept", first.edition and first.edition.foil, true)
	check("live area: seal kept", first.seal, "Red")
	check("live area: no enhancement means a base card", PVP.nemesis_cards[2].center, G.P_CENTERS.c_base)
end

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
