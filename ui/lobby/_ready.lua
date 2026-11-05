-- Lobby view, copied from the Speedrunning mod's ui/lobby (buttons/view/controls/
-- code/ready) and rewired to PvP. Private lobbies: host gets START + LOBBY OPTIONS,
-- guests get a READY toggle; both get deck/code panels + LEAVE. Matchmaking lobbies:
-- a status panel; the run auto-starts once all clients are ready.

PVP.lobby = PVP.lobby or { buttons = {} }
PVP.lobby.ready = PVP.lobby.ready or MPAPI.ReadyTracker()
-- Unanimous seed-change vote tracker (pause menu -> pvp_seed_vote); see pvp_api/run_actions.lua.
PVP.lobby.seed_votes = PVP.lobby.seed_votes or MPAPI.VoteTracker()
-- Unanimous draw vote tracker (pause menu -> pvp_draw_vote); see pvp_api/run_actions.lua.
PVP.lobby.draw_votes = PVP.lobby.draw_votes or MPAPI.VoteTracker()

function PVP.get_lobby_kind()
	return PVP._pvp_kind
end

function PVP.is_matchmaking()
	return PVP._pvp_kind == PVP.LobbyAccess.RANKED or PVP._pvp_kind == PVP.LobbyAccess.CASUAL
end

-- A server-refereed lobby keeps ready on the server; its PLAYER_READY_CHANGED feeds
-- the same tally (pvp_api/lobby_bridge.lua).
function PVP.signal_ready(ready)
	local lobby = PVP.lobby.ref
	if not lobby then
		return
	end
	if MPAPI.has_server_referee(lobby) then
		lobby:set_ready(ready, function(err)
			if err then
				sendWarnMessage("Ready failed: " .. tostring(err), "MULTIPLAYER")
			end
		end)
		return
	end
	lobby:action(MPAPI.ActionTypes["pvp_player_ready"]):broadcast({ ready = ready and true or false })
end

function PVP.start_ready_resync()
	if not PVP.is_matchmaking() then
		return
	end
	PVP._ready_resync_stop = MPAPI.ready_resync({
		send = function()
			PVP.signal_ready(true)
		end,
		should_continue = function()
			return PVP.lobby.ref ~= nil and PVP.is_matchmaking()
		end,
	})
end

function PVP.stop_ready_resync()
	if PVP._ready_resync_stop then
		PVP._ready_resync_stop()
		PVP._ready_resync_stop = nil
	end
end

function PVP.reset_ready_state()
	local b = PVP.lobby.buttons
	PVP.lobby.ready:reset()
	PVP.lobby.local_ready = false
	PVP.lobby.start_broadcasted = false
	PVP.lobby.start_hold = nil
	if b.ready_args then
		b.ready_args.label = { localize("b_ready_cap") }
		b.ready_args.colour = G.C.GREEN
	end
	if b.ready then
		b.ready:update()
	end
	if b.start_game then
		b.start_game:update()
	end
	if b.party_find_game then
		b.party_find_game:update()
	end
end

-- Host-only: record a player's ready state and react.
function PVP.set_player_ready(player_id, ready)
	local lobby = PVP.lobby.ref
	if not lobby or not lobby.is_host then
		return
	end
	PVP.lobby.ready:set(player_id, ready)
	if PVP.is_matchmaking() then
		PVP.maybe_autostart()
	else
		if PVP.lobby.buttons.start_game then
			PVP.lobby.buttons.start_game:update()
		end
		if PVP.lobby.buttons.party_find_game then
			PVP.lobby.buttons.party_find_game:update()
		end
	end
end

local function can_autostart(L)
	return not L.start_broadcasted
		and L.ref
		and L.ref.is_host
		and PVP.is_matchmaking()
		and #L.ref:get_players() >= 2
		and L.ready:all_ready()
end

-- Host-only matchmaking auto-start: once all clients are ready, hold for the match reveal's
-- countdown (ui/queue_reveal.lua), then start exactly once. The hold is the host's, so every
-- client's reveal ends on the same game start and the Draft's turn clock starts after it.
function PVP.maybe_autostart()
	local L = PVP.lobby
	if L.start_hold or not can_autostart(L) then
		return
	end
	local hold, lobby = {}, L.ref
	L.start_hold = hold
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = PVP.QUEUE_REVEAL.HOLD_SECONDS,
		timer = "REAL",
		blockable = false,
		blocking = false,
		no_delete = true,
		func = function()
			if L.start_hold ~= hold then
				return true
			end
			L.start_hold = nil
			if L.ref == lobby and can_autostart(L) then
				L.start_broadcasted = true
				PVP.pvp_start_match()
			end
			return true
		end,
	}))
end

G.FUNCS.mp_pvp_toggle_ready = function()
	local L = PVP.lobby
	L.local_ready = not L.local_ready
	if L.buttons.ready_args and L.buttons.ready then
		L.buttons.ready_args.label = { L.local_ready and localize("b_unready_cap") or localize("b_ready_cap") }
		L.buttons.ready_args.colour = L.local_ready and G.C.ORANGE or G.C.GREEN
		L.buttons.ready:update()
	end
	PVP.signal_ready(L.local_ready)
end
