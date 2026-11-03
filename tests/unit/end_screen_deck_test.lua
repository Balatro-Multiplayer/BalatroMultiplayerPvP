-- Plain Lua test for the end screen's View Deck: a player's cards travel in the result
-- they send when they are out (pvp_api/actions/player_result.lua), and View Deck shows
-- the deck of the player picked in the switcher (PVP.UI.selected_player_deck,
-- ui/game/game_end.lua), none for a player still in the match.
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
function PVP.Score.or_zero(v)
	return v or 0
end
function sendDebugMessage() end

-- A card as card_to_string sees it; the real one needs the game's centers.
function PVP.UTILS.card_to_string(card)
	return card.str
end

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
local sent
local on_receive
MPAPI = {
	connection_state = { player_id = SELF },
	ActionTypes = { pvp_player_result = "pvp_player_result" },
	ActionType = function(def)
		on_receive = def.on_receive
	end,
	get_current_lobby = function()
		return {
			player_id = SELF,
			action = function()
				return {
					broadcast = function(_, params)
						sent = params
					end,
				}
			end,
		}
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
load_chunk("lib/card_utils.lua", "function PVP.UTILS.deck_to_string(cards)")
dofile("pvp_api/actions/player_result.lua")
load_chunk("lib/card_utils.lua", "function PVP.UTILS.parse_deck_string(str, known)")
load_chunk("lib/card_utils.lua", "function PVP.UTILS.build_cards(specs, area)")
load_chunk("ui/game/game_end.lua", "function PVP.UI.deck_to_show(selected_id, self_id, results)")
local has_selected = load_chunk("ui/game/game_end.lua", "function PVP.UI.selected_player_deck()")

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
	PVP._end_screen_selected_player_id = player_id
	if not has_selected then
		return "no selected_player_deck"
	end
	return PVP.UI.selected_player_deck()
end

local DECK = ";S-A-m_glass-none-none;H-K-none-none-none"

-- This player is out: the result they send carries their cards.
G.playing_cards = { { str = "S-A-m_glass-none-none" }, { str = "H-K-none-none-none" } }
PVP.report_roster_result()
check("the result sent when out carries the cards", sent and sent.cards, DECK)

-- Another player is out; a late mid-match roster from them must not drop their cards.
on_receive(nil, OUT, { jokers = {}, cards = DECK })
on_receive(nil, OUT, { jokers = {}, interim = true })
-- A player still in the match has only sent a mid-match roster.
on_receive(nil, PLAYING, { jokers = {}, interim = true })

check("switcher on me: my own deck", deck_of(SELF), G.playing_cards)
local cards = deck_of(OUT)
check("switcher on a player who is out: their cards", type(cards) == "table" and #cards, 2)
check("their cards come back as sent", type(cards) == "table" and cards[1].center, G.P_CENTERS.m_glass)
check("switcher on a player still playing: no deck", deck_of(PLAYING), nil)

-- deck_to_show is pure: plain values in, plain values out.
local results = { out = { cards = DECK }, playing = { jokers = {}, interim = true } }
for _, case in ipairs({
	{ "nobody selected", nil, nil },
	{ "yourself", SELF, "own" },
	{ "yourself, even with a result of your own", SELF, "own", { me = { cards = DECK } } },
	{ "a player who is out", OUT, DECK },
	{ "a player still playing", PLAYING, nil },
	{ "a player with no result at all", "unknown", nil },
}) do
	local name, selected, want, case_results = case[1], case[2], case[3], case[4]
	local show = PVP.UI.deck_to_show(selected, SELF, case_results or results)
	local got = show and (show.own and "own" or show.cards) or nil
	check("deck_to_show, " .. name, got, want)
end
check("deck_to_show with no results table", PVP.UI.deck_to_show(OUT, SELF, nil), nil)

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
