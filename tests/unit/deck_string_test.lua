-- Plain Lua test for PVP.UTILS.parse_deck_string (pure) and PVP.UTILS.build_cards
-- (lib/card_utils.lua). Run from the repo root: luajit tests/unit/deck_string_test.lua
G = { CARD_W = 1, CARD_H = 1 }
PVP = { UTILS = {} }

-- card_utils.lua needs the game's centers to load, so load just the functions under test.
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
load_function("lib/card_utils.lua", "function PVP.UTILS.parse_deck_string(str, known)")
load_function("lib/card_utils.lua", "function PVP.UTILS.build_cards(specs, area)")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

-- Specs are plain tables, so compare them field by field.
local function spec_str(spec)
	if not spec then return "nil" end
	return ("%s/%s/%s/%s"):format(
		spec.front and spec.front.name or "-",
		spec.center and spec.center.name or "-",
		tostring(spec.edition),
		tostring(spec.seal)
	)
end
local function specs_str(specs)
	local parts = {}
	for i, spec in ipairs(specs) do
		parts[i] = spec_str(spec)
	end
	return table.concat(parts, " ")
end

local KNOWN = {
	cards = { S_A = { name = "S_A" }, H_K = { name = "H_K" } },
	centers = { c_base = { name = "c_base" }, m_glass = { name = "m_glass" }, e_foil = { name = "e_foil" } },
	seals = { Red = {} },
}

-- parse_deck_string: a table of named cases, each with its exact expected specs.
for _, case in ipairs({
	{ "two cards", ";S-A-m_glass-foil-Red;H-K-none-none-none", "S_A/m_glass/foil/Red H_K/c_base/nil/nil" },
	{ "empty string", "", "" },
	{ "no string", nil, "" },
	{ "unknown suit or rank is skipped", ";X-Z-none-none-none;H-K-none-none-none", "H_K/c_base/nil/nil" },
	{ "unknown enhancement is a base card", ";S-A-m_bogus-none-none", "S_A/c_base/nil/nil" },
	{ "unknown edition is none", ";S-A-none-bogus-none", "S_A/c_base/nil/nil" },
	{ "unknown seal is none", ";S-A-none-none-Bogus", "S_A/c_base/nil/nil" },
	{ "missing fields are none", ";S-A", "S_A/c_base/nil/nil" },
	{ "no leading separator", "S-A-none-none-none", "S_A/c_base/nil/nil" },
}) do
	check("parse: " .. case[1], specs_str(PVP.UTILS.parse_deck_string(case[2], KNOWN)), case[3])
end

do
	local deck = ";S-A-m_glass-foil-Red;H-K-none-none-none"
	local first = PVP.UTILS.parse_deck_string(deck, KNOWN)
	check("parse: same input, same output", specs_str(PVP.UTILS.parse_deck_string(deck, KNOWN)), specs_str(first))
	check("parse: input lookup tables untouched", KNOWN.cards.S_A.name, "S_A")
end

-- build_cards: the thin shell that turns specs into game Cards.
function Card(_x, _y, _w, _h, front, center)
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

local function own_deck(n)
	local cards = {}
	for i = 1, n do
		cards[i] = { own = i }
	end
	return cards
end

local SPECS = PVP.UTILS.parse_deck_string(";S-A-m_glass-foil-Red;H-K-none-none-none", KNOWN)

do
	-- The area from an earlier end screen was removed with that run: CardArea:remove sets cards = nil.
	G.playing_cards = own_deck(52)
	local ok, cards = pcall(PVP.UTILS.build_cards, SPECS, make_area(nil))
	check("build, removed area: does not error", ok, true)
	check("build, removed area: no cards", ok and #cards, 0)
	check("build, removed area: own deck keeps 52 cards", #G.playing_cards, 52)
	check("build, no area: no cards", #PVP.UTILS.build_cards(SPECS, nil), 0)
end

do
	G.playing_cards = own_deck(52)
	G.playing_card = 52
	local area = make_area({})
	local cards = PVP.UTILS.build_cards(SPECS, area)
	check("build: both cards are returned", #cards, 2)
	check("build: both cards are in the area", #area.cards, 2)
	check("build: own deck keeps 52 cards", #G.playing_cards, 52)
	check("build: own last card is untouched", G.playing_cards[52].own, 52)
	check("build: own card id counter is untouched", G.playing_card, 52)
	check("build: front kept", cards[1].front, KNOWN.cards.S_A)
	check("build: enhancement kept", cards[1].center, KNOWN.centers.m_glass)
	check("build: edition kept", cards[1].edition and cards[1].edition.foil, true)
	check("build: seal kept", cards[1].seal, "Red")
	check("build: base card has no edition", cards[2].edition, nil)
	check("build: base card has no seal", cards[2].seal, nil)
end

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
