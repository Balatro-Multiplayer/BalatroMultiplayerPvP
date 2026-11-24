-- Plain Lua test for who the PvP end screen opens on (ui/game/game_end.lua): in a 1v1
-- it opens on the opponent's jokers and deck, a rebuild (closing View Deck) keeps the
-- player picked, and jokers the view carries late redraw the opponent's jokers.
-- Run from the repo root: luajit tests/unit/end_screen_selection_test.lua
G = { FUNCS = {}, UIDEF = {}, CARD_W = 1, CARD_H = 1, GAME = { starting_params = { joker_slots = 5 } } }
PVP = { READ = { target = {}, pvp_blind = {} }, UI = { end_screen = {} }, UTILS = {}, LOBBY = { code = "ABCDE" }, GAME = {}, SCORE = {} }
function PVP.SCORE.or_zero(v)
	return v or 0
end
function sendDebugMessage() end
function localize(args)
	if type(args) == "string" then
		return args
	end
	return args.key .. ":" .. tostring(args.vars and args.vars[1])
end
function CardArea()
	return { cards = {} }
end
Game = { delete_run = function() end }

local SELF, OPP, THIRD = "me", "them", "third"
local lobby_players
MPAPI = {
	connection_state = { player_id = SELF },
	get_current_lobby = function()
		return {
			player_id = SELF,
			get_players = function()
				return lobby_players
			end,
		}
	end,
	rebuild_jokers_area = function(area, jokers)
		area.cards = jokers or {}
	end,
	end_screen_player_panel = function(config)
		return config
	end,
	end_screen_view_deck_button = function() end,
}
-- The shared helper as BalatroMultiplayerAPI ships it: every player, on yourself.
function MPAPI.end_screen_default_selection(lobby, players)
	local options, current_option = {}, 1
	for i, p in ipairs(players) do
		options[i] = p.displayName or p.id
		if p.id == lobby.player_id then
			current_option = i
		end
	end
	return players, options, current_option
end
-- What the view's end of game holds, by player (pvp_api/ui/finish.lua).
local view_jokers = {}
PVP.UI.finish = {
	jokers_of = function(player_id)
		return view_jokers[player_id]
	end,
}
-- The view brings a player's jokers in; finish_screen then redraws the open end screen.
local function on_view(player_id, jokers)
	view_jokers[player_id] = jokers
	PVP.UI.refresh_end_game_jokers()
end

dofile("lib/match_players.lua")

local function read(path)
	local file = assert(io.open(path, "r"))
	local text = file:read("*a")
	file:close()
	return text
end

-- game_end.lua needs the whole game to load. Load the span from the first header to
-- the end of the function the second header opens (its locals stay in one chunk).
local function load_span(text, from, to)
	local start = text:find(from, 1, true)
	local last = text:find(to, start, true)
	if not start or not last then
		return false
	end
	local _, finish = text:find("\nend\r?\n", last)
	assert((loadstring or load)(text:sub(start, finish)))()
	return true
end

local game_end = read("ui/game/game_end.lua")
load_span(game_end, "local END_GAME_JOKERS_TEXT_KEY", "function PVP.UI.build_end_game_extras()")
load_span(game_end, "function PVP.UI.end_screen_start_index(", "function PVP.UI.end_screen_start_index(")
load_span(game_end, "function PVP.UI.clear_shown_deck_area()", "function PVP.UI.clear_shown_deck_area()")
load_span(game_end, "local delete_run_ref = Game.delete_run", "function Game:delete_run()")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local function fresh_match(players)
	lobby_players = players
	PVP.LOBBY.match_players = players
	view_jokers = {}
	PVP.UI.end_screen.selected_id = nil
	PVP.UI.end_screen.selected_name = nil
end

local ONE_V_ONE = { { id = SELF, displayName = "Me" }, { id = OPP, displayName = "Them" } }
local OPP_JOKERS = { { key = "j_joker" } }

-- 1v1, both out: the screen opens on the opponent's jokers.
fresh_match(ONE_V_ONE)
view_jokers[OPP] = OPP_JOKERS
local panel = PVP.UI.build_end_game_extras()
check("1v1 opens on the opponent", PVP.UI.end_screen.selected_id, OPP)
check("1v1 selector shows the opponent", panel.current_option, 2)
check("1v1 jokers are the opponent's", PVP.UI.end_screen.jokers.cards, OPP_JOKERS)
check("1v1 caption names the opponent", PVP.UI.end_screen.jokers_text, "k_end_player_jokers:Them")

-- Closing View Deck rebuilds the end screen: the player picked stays picked.
G.FUNCS.pvp_end_screen_select_player({ to_key = 1 })
panel = PVP.UI.build_end_game_extras()
check("a rebuild keeps the player picked", PVP.UI.end_screen.selected_id, SELF)
check("a rebuild keeps the selector on them", panel.current_option, 1)

-- A new run forgets the pick, so the next match opens on its opponent again.
Game.delete_run(Game)
check("a new run clears the pick", PVP.UI.end_screen.selected_id, nil)

-- 1v1, the opponent's result lands after the screen is built (the usual case for the
-- player who lost): their jokers appear without touching the selector.
fresh_match(ONE_V_ONE)
PVP.UI.build_end_game_extras()
check("before their result: still playing", PVP.UI.end_screen.jokers_text, "k_end_player_playing:Them")
on_view(OPP, OPP_JOKERS)
check("their late result shows their jokers", PVP.UI.end_screen.jokers.cards, OPP_JOKERS)
check("their late result updates the caption", PVP.UI.end_screen.jokers_text, "k_end_player_jokers:Them")

-- A late result from someone else leaves the shown player alone.
on_view(SELF, { { key = "j_mine" } })
check("another player's result does not redraw", PVP.UI.end_screen.jokers.cards, OPP_JOKERS)

-- An end screen that is gone is not redrawn.
PVP.UI.end_screen.jokers.REMOVED = true
local removed_cards = PVP.UI.end_screen.jokers.cards
on_view(OPP, { { key = "j_other" } })
check("a removed end screen is not redrawn", PVP.UI.end_screen.jokers.cards, removed_cards)

-- Pure: which player the end screen opens on.
local start = PVP.UI.end_screen_start_index
if not start then
	check("PVP.UI.end_screen_start_index exists", nil, "function")
else
	local three = { { id = SELF }, { id = OPP }, { id = THIRD } }
	for _, case in ipairs({
		{ "1v1, you listed first", ONE_V_ONE, nil, nil, 2 },
		{ "1v1, you listed second", { ONE_V_ONE[2], ONE_V_ONE[1] }, nil, nil, 1 },
		{ "a kept pick wins", ONE_V_ONE, SELF, OPP, 1 },
		{ "a kept pick no longer listed is ignored", ONE_V_ONE, "gone", nil, 2 },
		{ "more players: your nemesis", three, nil, THIRD, 3 },
		{ "more players, no nemesis: yourself", three, nil, nil, 1 },
		{ "a nemesis not listed: yourself", three, nil, "gone", 1 },
		{ "two players, neither you: the fallback", { { id = OPP }, { id = THIRD } }, nil, nil, 1 },
	}) do
		check("start index, " .. case[1], start(case[2], SELF, case[3], case[4], 1), case[5])
	end
end

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
