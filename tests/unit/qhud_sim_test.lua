-- Run from the repo root: lua5.4 tests/unit/qhud_sim_test.lua
local function noop() end
local events, starts, matches, joins, forwarded = {}, 0, 0, 0, 0
local real_rating, real_counts, real_cancel = function() end, function() end, function() end
local hud = {
	start = function()
		starts = starts + 1
	end,
	stop = noop,
	dismiss_reveal = noop,
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
	LOBBY = {},
	QUEUE_HUD = hud,
	QUEUE_CARDS = { EGGS = {} },
	LobbyAccess = { RANKED = "ranked", CASUAL = "casual" },
	RulesetKey = { VANILLA = "vanilla" },
}
MPAPI = {
	matchmaking = { get_rating = real_rating, get_queue_counts = real_counts },
	get_focused_mod = function()
		return "pvp"
	end,
}
G = {
	STAGE = 1,
	STAGES = { MAIN_MENU = 1 },
	FUNCS = { mp_pvp_cancel_queue = real_cancel },
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
local checkout, loads = false, 0
NFS = {
	getInfo = function()
		return checkout and {} or nil
	end,
}
PVP.load_mp_file = function(path)
	loads = loads + 1
	return dofile(path)
end
local function boot()
	dofile("pvp_api/zz_qhud_dev.lua")
end
boot()
assert(loads == 0, "packaged build leaves hotkeys alone")
checkout = true
PVP.ENV.qhud_sim = false
boot()
assert(loads == 0, "explicit opt-out works in a checkout")
PVP.ENV.qhud_sim = nil
boot()
assert(loads == 1 and QHUD_SIM, "checkout loads simulator automatically")
assert(MPAPI.matchmaking.get_rating == real_rating, "loading does not install fake API")
QHUD_SIM.quiet = true
love.keypressed("p", nil, false)
love.keypressed("p", nil, false)
assert(starts == 2, "each Alt+P restarts preview")
local pending = events
events = {}
for _, event in ipairs(pending) do
	event.func()
end
assert(matches == 1 and joins == 1, "only latest playback reaches match and join")
love.keypressed("p", nil, false)
love.keypressed("x", nil, false)
pending = events
events = {}
for _, event in ipairs(pending) do
	event.func()
end
assert(matches == 1 and joins == 1, "Alt+X invalidates pending playback")
assert(
	MPAPI.matchmaking.get_rating == real_rating and MPAPI.matchmaking.get_queue_counts == real_counts,
	"stop restores real API"
)
assert(G.FUNCS.mp_pvp_cancel_queue == real_cancel, "stop restores cancel handler")
PVP._match_handle = {}
love.keypressed("p", nil, false)
assert(starts == 3, "simulator does not take over a live queue")
PVP._match_handle = nil
G.STAGE = 2
love.keypressed("p", nil, false)
assert(starts == 3 and forwarded == 1, "hotkeys pass through during a run")
G.STAGE = 1
boot()
QHUD_SIM.quiet = true
love.keypressed("p", nil, false)
assert(starts == 4, "reloading does not stack hotkey handlers")
G.FUNCS.mp_pvp_cancel_queue()
assert(
	not QHUD_SIM.active and MPAPI.matchmaking.get_rating == real_rating,
	"HUD cancel stops simulation and restores API"
)
print("qhud_sim_test: ok")
