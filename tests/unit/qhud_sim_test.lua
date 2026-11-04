-- Run from the repo root: lua5.4 tests/unit/qhud_sim_test.lua
local function noop() end
local events, starts, matches, joins, forwarded, dismissals = {}, 0, 0, 0, 0, 0
local real_rating, real_counts = function() end, function() end
-- Like PVP.QUEUE_HUD, a repeated start for a search already showing is ignored.
local hud
hud = {
	start = function()
		if hud.active then return end
		hud.active = true
		starts = starts + 1
	end,
	stop = function()
		hud.active = false
	end,
	dismiss_reveal = function()
		dismissals = dismissals + 1
	end,
	match_found = function()
		matches = matches + 1
	end,
	lobby_ready = function()
		joins = joins + 1
	end,
}
PVP = {
	id = "pvp",
	path = ".",
	ENV = {},
	LOBBY = { config = {} },
	GamemodeKey = { PVP_NEMESIS = "pvp_nemesis" },
	PVP_GAMEMODES = {},
	reset_ruleset_to_gamemode_default = noop,
	QUEUE_HUD = hud,
	QUEUE_CARDS = { EGGS = {} },
	LobbyAccess = { RANKED = "ranked", CASUAL = "casual", RANKED_PREFIX = "ranked:" },
	RulesetKey = { VANILLA = "vanilla", EXPANDED = "expanded" },
	QUEUE_REVEAL = { HOLD_SECONDS = 4 },
	lobby = {},
	_ban_pick_config_for = function()
		return {}
	end,
}
local drafts, draft_done, practice, pages = 0, nil, nil, {}
PVP._start_practice = function(ruleset, loadout)
	practice = { ruleset = ruleset, loadout = loadout }
end
local real_lobby = function() end
MPAPI = {
	connection_state = { preferred_joker = "j_blueprint" },
	LobbyEvent = { SETUP_CHANGED = "setup", GAME_ENDED = "ended" },
	get_current_lobby = real_lobby,
	pages = {
		show = function(key)
			pages[#pages + 1] = key
		end,
	},
	_internal = { mod_registry = { registered_mods = { pvp = { lobby_ui = "pvp_lobby", main_menu_ui = "pvp_menu" } } } },
	GameModes = { pvp_nemesis = {} },
	BanPick = {
		start = function(_, _, on_complete)
			drafts = drafts + 1
			draft_done = on_complete
		end,
	},
	matchmaking = {
		get_rating = real_rating,
		get_queue_counts = real_counts,
		ranked_spread = function(t)
			return math.min(150 + math.floor(t / 30) * 50, 600)
		end,
	},
	get_focused_mod = function()
		return "pvp"
	end,
}
localize = function(args)
	return args.key
end
G = {
	P_CENTERS = { b_red = { key = "b_red", name = "Red Deck" } },
	P_CENTER_POOLS = { Stake = { { key = "stake_white" } } },
	STAGE = 1,
	STAGES = { MAIN_MENU = 1 },
	FUNCS = {},
	E_MANAGER = {
		add_event = function(_, e)
			events[#events + 1] = e
		end,
	},
}
Event = function(e)
	return e
end
love = {
	timer = {
		getTime = function()
			return 0
		end,
	},
	keyboard = {
		isDown = function()
			return true
		end,
	},
	math = {
		random = function()
			return 1
		end,
	},
	keypressed = function()
		forwarded = forwarded + 1
	end,
}
PVP.match_log, sendWarnMessage = noop, noop
-- The simulator's search runs through the real queue handlers.
dofile("pvp_api/queue.lua")
local real_cancel = G.FUNCS.mp_pvp_cancel_queue
local loads = 0
PVP.load_mp_file = function(path)
	if path:match("qhud_sim") then loads = loads + 1 end
	return dofile(path)
end
local function boot()
	dofile("pvp_api/zz_qhud_dev.lua")
end
boot()
assert(loads == 0, "no simulator without the .env opt-in")
PVP.ENV.qhud_sim = false
boot()
assert(loads == 0, "qhud_sim=false leaves hotkeys alone")
PVP.ENV.qhud_sim = true
boot()
assert(loads == 1 and QHUD_SIM, "qhud_sim=true loads the simulator")
assert(MPAPI.matchmaking.get_rating == real_rating, "loading does not install fake API")
QHUD_SIM.quiet = true
love.keypressed("p", nil, false)
love.keypressed("p", nil, false)
assert(starts == 2, "each Alt+P restarts preview")
assert(PVP._match_handle == QHUD_SIM.handle and PVP._is_searching(), "the search is queue.lua's, on a fake handle")
local pending = events
events = {}
for _, event in ipairs(pending) do
	event.func()
end
assert(matches == 1 and joins == 1, "only latest playback reaches match and join")
assert(not PVP._is_searching(), "joining the lobby ends the search")
pending = events
events = {}
for _, event in ipairs(pending) do
	event.func()
end
assert(drafts == 1, "the countdown after the opponent's arrival opens the Draft")
assert(MPAPI.get_current_lobby() ~= nil and MPAPI.get_current_lobby() ~= real_lobby, "the Draft's lobby is current")
assert(pages[#pages] == "pvp_lobby", "the Draft shows in the lobby view")
draft_done({ { key = "b_red", stake = 1 } })
for _ = 1, 2 do
	pending = events
	events = {}
	for _, event in ipairs(pending) do
		event.func()
	end
end
assert(practice and practice.ruleset == "ruleset_mp_expanded", "the pick starts an Expanded practice run")
assert(practice.loadout.back == "Red Deck" and practice.loadout.stake == 1, "on the drafted deck and stake")
assert(MPAPI.get_current_lobby == real_lobby, "the real lobby lookup is back before the run")
assert(not QHUD_SIM.active, "the simulator stopped for the run")
love.keypressed("p", nil, false)
love.keypressed("x", nil, false)
pending = events
events = {}
for _, event in ipairs(pending) do
	event.func()
end
assert(matches == 1 and joins == 1, "Alt+X invalidates pending playback")
love.keypressed("d", nil, false)
assert(drafts == 2 and MPAPI.get_current_lobby() ~= nil, "Alt+D goes straight to the Draft")
love.keypressed("x", nil, false)
assert(MPAPI.get_current_lobby == real_lobby and pages[#pages] == "pvp_menu", "Alt+X leaves the Draft for the menu")
assert(
	MPAPI.matchmaking.get_rating == real_rating and MPAPI.matchmaking.get_queue_counts == real_counts,
	"stop restores real API"
)
assert(G.FUNCS.mp_pvp_cancel_queue == real_cancel, "stop restores cancel handler")
PVP._match_handle = {}
love.keypressed("p", nil, false)
assert(starts == 4, "simulator does not take over a live queue")
PVP._match_handle = nil
G.STAGE = 2
love.keypressed("p", nil, false)
assert(starts == 4 and forwarded == 1, "hotkeys pass through during a run")
G.STAGE = 1
boot()
QHUD_SIM.quiet = true
love.keypressed("p", nil, false)
assert(starts == 5, "reloading does not stack hotkey handlers")
G.FUNCS.mp_pvp_cancel_queue()
assert(
	not QHUD_SIM.active and MPAPI.matchmaking.get_rating == real_rating,
	"HUD cancel stops simulation and restores API"
)
assert(PVP._match_handle == nil and not PVP._is_searching(), "and leaves the queue")

-- Alt+S backdates the handle's queue time, widening its window.
love.keypressed("1", nil, false)
assert(QHUD_SIM.handle._nakama_rating == 1432 and QHUD_SIM.handle._nakama_spread == 150, "a fresh ranked ticket")
love.keypressed("s", nil, false)
assert(QHUD_SIM.handle._queued_at == -30 and QHUD_SIM.handle._nakama_spread == 200, "Alt+S widens the ticket's window")
love.keypressed("x", nil, false)

-- Alt+F: the matched lobby can't be joined. queue.lua's error handler ends the search and reveal.
local function run_events()
	local batch = events
	events = {}
	for _, event in ipairs(batch) do
		event.func()
	end
end
love.keypressed("1", nil, false)
love.keypressed("m", nil, false)
local before = dismissals
love.keypressed("f", nil, false)
assert(dismissals == before + 1, "a failed lobby join ends the reveal")
assert(not hud.active and not PVP._is_searching() and PVP._match_handle == nil, "and the search")
assert(MPAPI.matchmaking.get_rating == real_rating and not QHUD_SIM.active, "and the simulation")

-- Alt+L: the opponent leaves during the countdown, so the game never starts.
love.keypressed("1", nil, false)
love.keypressed("m", nil, false)
love.keypressed("j", nil, false)
run_events() -- the opponent arrives
love.keypressed("l", nil, false)
local drafts_before = drafts
run_events() -- the countdown ends
assert(drafts == drafts_before, "no Draft once the opponent has left")
love.keypressed("x", nil, false)
print("qhud_sim_test: ok")
