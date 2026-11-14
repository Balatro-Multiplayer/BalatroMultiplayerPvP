-- Plain Lua test: every client takes its own ready from the server's PLAYER_READY_CHANGED,
-- so a guest the server un-readied (after a reconnect) sees READY again; the host's tally
-- for other players still updates.
-- Run from the repo root: luajit tests/unit/lobby_ready_sync_test.lua
local updates = 0
local tracker = { states = {} }
function tracker:set(id, ready)
	self.states[id] = ready
end
MPAPI = {
	ReadyTracker = function()
		return tracker
	end,
}
PVP = { LobbyAccess = { RANKED = "ranked", CASUAL = "casual" }, _pvp_kind = "private" }
G = { C = { GREEN = "green", ORANGE = "orange" }, FUNCS = {} }
function localize(key)
	return key
end

dofile("ui/lobby/_ready.lua")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local function button_state()
	PVP.lobby.buttons = {
		ready_args = { label = { "b_unready_cap" }, colour = G.C.ORANGE },
		ready = { update = function() updates = updates + 1 end },
	}
	PVP.lobby.local_ready = true
end

-- Guest: the server cleared them.
PVP.lobby.ref = { player_id = "me", is_host = false }
button_state()
PVP.set_player_ready("me", false)
check("a guest takes its own un-ready from the server", PVP.lobby.local_ready, false)
check("the button label goes back to READY", PVP.lobby.buttons.ready_args.label[1], "b_ready_cap")
check("the button colour goes back to green", PVP.lobby.buttons.ready_args.colour, G.C.GREEN)
check("the button is refreshed", updates, 1)

-- Guest: someone else's ready is not theirs to track.
button_state()
PVP.set_player_ready("other", false)
check("another player's change leaves the guest's own ready", PVP.lobby.local_ready, true)
check("a guest keeps no tally", tracker.states.other, nil)

-- Host: own ready follows the server too, others still feed the tally.
PVP.lobby.ref = { player_id = "me", is_host = true }
button_state()
PVP.set_player_ready("other", true)
check("the host tally records another player", tracker.states.other, true)
check("another player's change leaves the host's own ready", PVP.lobby.local_ready, true)
PVP.set_player_ready("me", false)
check("the host takes its own un-ready from the server", PVP.lobby.local_ready, false)

if failures > 0 then os.exit(1) end
