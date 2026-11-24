-- Plain Lua test for the end screen's View Deck: another player's cards come from the view's end
-- of game (PVP.finish_screen.deck_of), and View Deck has a tab per player (PVP.UI.deck_tabs,
-- ui/game/game_end.lua) that shows that player's deck (PVP.UI.player_deck), none for a player still
-- in the match.
-- Run from the repo root: luajit tests/unit/end_screen_deck_test.lua
G = {
	FUNCS = {},
	CARD_W = 1,
	CARD_H = 1,
	P_CARDS = { S_A = { name = "S_A" }, H_K = { name = "H_K" } },
	P_CENTERS = { c_base = { name = "c_base" }, m_glass = { name = "m_glass" } },
	P_SEALS = {},
}
PVP = { UI = {}, UTILS = {}, LOBBY = { code = "ABCDE" }, GAME = {}, Score = {} }
function sendDebugMessage() end

function Card(_x, _y, _w, _h, front, center)
	return { front = front, center = center, set_edition = function() end, set_seal = function() end }
end

function CardArea()
	local area = { cards = {}, T = { x = 0, y = 0 } }
	function area:emplace(card)
		self.cards[#self.cards + 1] = card
	end
	function area:remove()
		self.cards = nil
	end
	return area
end

local SELF, OUT, PLAYING = "me", "out", "playing"
local DECK = ";S-A-m_glass-none-none;H-K-none-none-none"
-- What the view's end of game holds, by player: a player still in the run has none.
local decks = { [OUT] = DECK, empty = "" }
MPAPI = { connection_state = { player_id = SELF } }
PVP.finish_screen = {
	deck_of = function(player_id)
		return decks[player_id]
	end,
}

-- game_end.lua and card_utils.lua need the whole game to load, so load just the
-- functions under test from them.
local function load_chunk(path, header)
	local file = assert(io.open(path, "r"))
	local text = file:read("*a")
	file:close()
	local start = text:find(header, 1, true)
	if not start then
		return false
	end
	local _, finish = text:find("\nend\r?\n", start)
	assert((loadstring or load)(text:sub(start, finish)))()
	return true
end

dofile("lib/string_utils.lua")
load_chunk("lib/card_utils.lua", "function PVP.UTILS.parse_deck_string(str, known)")
load_chunk("lib/card_utils.lua", "function PVP.UTILS.build_cards(specs, area)")
load_chunk("ui/game/game_end.lua", "function PVP.UI.clear_shown_deck_area()")
load_chunk("ui/game/game_end.lua", "function PVP.UI.deck_to_show(player_id, self_id, deck_of)")
load_chunk("ui/game/game_end.lua", "function PVP.UI.deck_tabs(players, self_id, selected_id)")
local has_player_deck = load_chunk("ui/game/game_end.lua", "function PVP.UI.player_deck(player_id)")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local function deck_of(player_id)
	if not has_player_deck then
		return "no player_deck"
	end
	return PVP.UI.player_deck(player_id)
end

G.playing_cards = { { str = "S-A-m_glass-none-none" }, { str = "H-K-none-none-none" } }
check("my own deck", deck_of(SELF), G.playing_cards)
local cards = deck_of(OUT)
check("a player who is out: their cards", type(cards) == "table" and #cards, 2)
check("their cards come back as sent", type(cards) == "table" and cards[1].center, G.P_CENTERS.m_glass)
check("a player still playing: no deck", deck_of(PLAYING), nil)

-- deck_to_show is pure: plain values in, plain values out.
for _, case in ipairs({
	{ "nobody selected", nil, nil },
	{ "yourself", SELF, "own" },
	{ "a player who is out", OUT, DECK },
	{ "a player still playing", PLAYING, nil },
	{ "a player the view does not list", "unknown", nil },
	{ "a player whose deck came as an empty string", "empty", nil },
}) do
	local name, selected, want = case[1], case[2], case[3]
	local show = PVP.UI.deck_to_show(selected, SELF, PVP.finish_screen.deck_of)
	local got = show and (show.own and "own" or show.cards) or nil
	check("deck_to_show, " .. name, got, want)
end

-- View Deck has a tab per player, whoever was picked; the picked player's tab opens first.
local players = { { id = SELF, displayName = "Me" }, { id = OUT, displayName = "Out" }, { id = PLAYING } }
local function tabs_summary(selected_id, list)
	local parts = {}
	for _, tab in ipairs(PVP.UI.deck_tabs(list or players, SELF, selected_id)) do
		parts[#parts + 1] = tostring(tab.id)
			.. (tab.own and "(own)" or "")
			.. (tab.chosen and "*" or "")
			.. "="
			.. tostring(tab.name)
	end
	return table.concat(parts, " ")
end
check("tabs with yourself picked", tabs_summary(SELF), "me(own)*=Me out=Out playing=playing")
check("tabs with another player picked", tabs_summary(OUT), "me(own)=Me out*=Out playing=playing")
check("tabs with nobody picked open your own", tabs_summary(nil), "me(own)*=Me out=Out playing=playing")
check("tabs with a pick not listed open your own", tabs_summary("gone"), "me(own)*=Me out=Out playing=playing")
check("tabs with no players still show your own", tabs_summary(nil, {}), "me(own)*=nil")
check("tabs without you open the first", tabs_summary(nil, { { id = OUT, displayName = "Out" } }), "out*=Out")

-- Leaving the run frees the area View Deck built last.
deck_of(OUT)
local shown = PVP.UI.shown_deck_area
PVP.UI.clear_shown_deck_area()
check("clearing the area removes its cards", shown.cards, nil)
check("clearing the area drops the reference", PVP.UI.shown_deck_area, nil)
PVP.UI.clear_shown_deck_area()
check("clearing with no area is safe", PVP.UI.shown_deck_area, nil)

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
