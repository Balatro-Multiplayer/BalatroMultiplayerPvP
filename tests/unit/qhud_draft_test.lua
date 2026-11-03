-- Run from the repo root: lua5.4 tests/unit/qhud_draft_test.lua
-- The simulator's Draft referee: turn order, the bot's turns, the turn clock, the result.
local events, clock = {}, 0
local first_slot = 1
love = {
	timer = {
		getTime = function()
			return clock
		end,
	},
	math = {
		random = function(n)
			if n == 2 then return first_slot end
			return 1
		end,
	},
}
Event = function(e)
	return e
end
G = {
	STAGE = 1,
	STAGES = { MAIN_MENU = 1 },
	FUNCS = {},
	E_MANAGER = {
		add_event = function(_, e)
			e.at = clock + e.delay
			events[#events + 1] = e
		end,
	},
}
local real_lobby = function() end
local banpick_lobby
MPAPI = {
	LobbyEvent = { SETUP_CHANGED = "setup", GAME_ENDED = "ended" },
	ErrorKind = { ACTION_REJECTED = "rejected" },
	make_error = function(kind, message)
		return { kind = kind, message = message }
	end,
	get_current_lobby = real_lobby,
	pages = { show = function() end },
	_internal = { mod_registry = { registered_mods = { pvp = { lobby_ui = "lobby", main_menu_ui = "menu" } } } },
	GameModes = { pvp_nemesis = {} },
	BanPick = {
		start = function(lobby)
			banpick_lobby = lobby
		end,
	},
}
PVP = {
	id = "pvp",
	lobby = {},
	LobbyAccess = { RANKED = "ranked" },
	_ban_pick_config_for = function()
		return {}
	end,
}
local DRAFT = dofile("tests/scenarios/lib/qhud_draft.lua")

local function eq(got, want, what)
	if got ~= want then error(what .. ": got " .. tostring(got) .. ", want " .. tostring(want), 2) end
end
-- Runs the events due by `t` seconds from now.
local function advance(t)
	clock = clock + t
	local i = 1
	while i <= #events do
		local e = events[i]
		if e.at <= clock then
			table.remove(events, i)
			e.func()
		else
			i = i + 1
		end
	end
end

local SCHEDULE = {
	{ actor = 1, action = "ban", count = 1 },
	{ actor = 2, action = "ban", count = 3 },
	{ actor = 1, action = "ban", count = 3 },
	{ actor = 2, action = "pick", count = 1 },
}
local candidates = {}
for i = 1, 12 do
	candidates[i] = { key = "d" .. i, art = "b_red", stake = 1 }
end

local function send(lobby, key, params)
	local err
	lobby
		:action({ key = key })
		:callback(function(_, _, e)
			err = e
		end)
		:send(nil, params)
	return err
end

local function open_draft()
	DRAFT.start({ { id = "me" }, { id = "opp" } }, function() end)
	local lobby = banpick_lobby
	local changes = 0
	lobby:on("setup", function()
		changes = changes + 1
	end)
	send(lobby, "mpapi_setup_draft", { id = "draft", candidates = candidates, poolSize = 9, schedule = SCHEDULE })
	return lobby, function()
		return changes
	end
end

-- The bot goes first: it bans 1, then the player bans 3, the bot 3, the player picks.
first_slot = 2
local lobby, changes = open_draft()
eq(MPAPI.get_current_lobby(), lobby, "the Draft's lobby is current")
local open = lobby._game.setup.open
eq(#open.pool, 9, "the pool is cut to its size")
eq(open.actor, "opp", "the bot acts first when the roll says so")
eq(send(lobby, "mpapi_setup_choose", { key = open.pool[1].key }).message, "not_your_turn", "no move on the bot's turn")
advance(DRAFT.BOT_THINK)
open = lobby._game.setup.open
eq(#open.banned, 1, "the bot banned once")
eq(open.actor, "me", "then it is the player's turn")
eq(open.remaining, 3, "for three bans")
eq(send(lobby, "mpapi_setup_choose", { key = open.banned[1] }).message, "unknown_key", "a banned tile can't be banned again")
for i = 2, 4 do
	eq(send(lobby, "mpapi_setup_choose", { key = open.pool[i].key }), nil, "the player's ban " .. i .. " is accepted")
end
eq(lobby._game.setup.open.actor, "opp", "three bans end the player's turn")
advance(DRAFT.BOT_THINK)
advance(DRAFT.BOT_BETWEEN)
advance(DRAFT.BOT_BETWEEN)
open = lobby._game.setup.open
eq(#open.banned, 7, "the bot banned three")
eq(open.schedule[open.turn + 1].action, "pick", "the last turn is a pick")
local left
for _, item in ipairs(open.pool) do
	local banned = false
	for _, key in ipairs(open.banned) do
		banned = banned or key == item.key
	end
	if not banned then left = item end
end
send(lobby, "mpapi_setup_choose", { key = left.key })
eq(lobby._game.setup.open, nil, "the pick closes the Draft")
eq(lobby._game.setup.results.draft.survivors[1], left, "the pick is the survivor")
assert(changes() >= 9, "every move announces a Setup change")

-- The player goes first and lets the clock run out: the referee bans for them.
first_slot = 1
lobby = open_draft()
eq(lobby._game.setup.open.actor, "me", "the player acts first when the roll says so")
eq(math.floor(lobby._game.setup.open.msLeft), 30000, "the clock starts full")
advance(DRAFT.TURN_SECONDS)
open = lobby._game.setup.open
eq(#open.banned, 1, "the clock banned for the player")
eq(open.actor, "opp", "and passed the turn")

DRAFT.stop()
eq(MPAPI.get_current_lobby, real_lobby, "stop restores the real lobby lookup")
local before = #lobby._game.setup.open.banned
advance(60)
eq(#lobby._game.setup.open.banned, before, "a stopped Draft's bot and clock do nothing")
print("qhud_draft_test: ok")
