-- Plain Lua test for G.FUNCS.load_nemesis_deck (networking/action_handlers.lua).
-- Run from the repo root: luajit tests/unit/nemesis_deck_test.lua
G = { FUNCS = {}, P_CARDS = { S_A = { name = "S_A" }, H_K = { name = "H_K" } }, P_CENTERS = {}, P_SEALS = {} }
PVP = { UTILS = {}, LOBBY = { code = "ABCDE" } }
function sendDebugMessage() end

-- Same order as vanilla: the card joins G.playing_cards before area:emplace runs.
function create_playing_card(init, area)
	local card = { front = init.front }
	table.insert(G.playing_cards, card)
	area:emplace(card)
	return card
end

-- PvP's double-emplace guard walks self.cards first, so a removed area (cards = nil) errors.
local function make_area(cards)
	return {
		cards = cards,
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

local DECK = ";S-A-none-none-none;H-K-none-none-none"

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
	PVP.nemesis_deck = make_area({})
	PVP.nemesis_cards = {}
	PVP.nemesis_deck_string = DECK
	G.FUNCS.load_nemesis_deck()
	check("live area: both nemesis cards are loaded", #PVP.nemesis_cards, 2)
	check("live area: both cards are in the area", #PVP.nemesis_deck.cards, 2)
	check("live area: own deck keeps 52 cards", #G.playing_cards, 52)
	check("live area: own last card is untouched", G.playing_cards[52].own, 52)
end

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
