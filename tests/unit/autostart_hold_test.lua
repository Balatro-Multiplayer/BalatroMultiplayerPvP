-- Run from the repo root: lua5.4 tests/unit/autostart_hold_test.lua
-- The matchmaking host holds its auto-start for the match reveal's countdown.
local function noop() end
local events, starts = {}, 0
G = {
	C = {},
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
MPAPI = {
	ReadyTracker = function()
		local ready = {}
		return {
			set = function(_, id, v)
				ready[id] = v
			end,
			all_ready = function()
				return ready.me and ready.opp
			end,
			reset = function()
				ready = {}
			end,
		}
	end,
	VoteTracker = function()
		return {}
	end,
}
PVP = {
	LobbyAccess = { RANKED = "ranked", CASUAL = "casual" },
	QUEUE_REVEAL = { HOLD_SECONDS = 4 },
	pvp_start_match = function()
		starts = starts + 1
	end,
}
localize = function(k)
	return k
end
dofile("ui/lobby/_ready.lua")

local function eq(got, want, what)
	if got ~= want then error(what .. ": got " .. tostring(got) .. ", want " .. tostring(want), 2) end
end
local function run_events()
	local pending = events
	events = {}
	for _, e in ipairs(pending) do
		e.func()
	end
end

local players = { { id = "me" }, { id = "opp" } }
local lobby = {
	is_host = true,
	get_players = function()
		return players
	end,
}
PVP._pvp_kind = "ranked"
PVP.lobby.ref = lobby
PVP.set_player_ready("me", true)
eq(#events, 0, "no hold until every player is ready")
PVP.set_player_ready("opp", true)
PVP.set_player_ready("opp", true)
eq(#events, 1, "one hold per start, however often ready repeats")
eq(events[1].delay, 4, "the hold is the reveal's countdown")
eq(starts, 0, "nothing starts during the hold")
run_events()
eq(starts, 1, "the match starts after the hold")
PVP.set_player_ready("opp", true)
run_events()
eq(starts, 1, "and only once")

PVP.reset_ready_state()
PVP.set_player_ready("me", true)
PVP.set_player_ready("opp", true)
players[2] = nil
run_events()
eq(starts, 1, "an opponent who left during the hold stops the start")
players[2] = { id = "opp" }
PVP.set_player_ready("opp", true)
run_events()
eq(starts, 2, "a later ready check holds and starts again")

PVP.reset_ready_state()
PVP.set_player_ready("me", true)
PVP.set_player_ready("opp", true)
PVP.reset_ready_state()
run_events()
eq(starts, 2, "a reset cancels the pending hold")
print("autostart_hold_test: ok")
