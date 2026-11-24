-- Lobby view, copied from the Speedrunning mod's ui/lobby (buttons/view/controls/
-- code/ready) and rewired to PvP. Private lobbies: host gets START + LOBBY OPTIONS,
-- guests get a READY toggle; both get deck/code panels + LEAVE. Matchmaking lobbies:
-- a status panel; the run auto-starts once all clients are ready.
-- Ready and Start are numbered inputs (pvp_api/ui/lobby.lua); the tally here follows the server's view.

PVP.UI.lobby = PVP.UI.lobby or { buttons = {} }
PVP.UI.lobby.ready = PVP.UI.lobby.ready or MPAPI.ReadyTracker()

function PVP.LOBBY.is_matchmaking()
	return PVP.LOBBY.kind == PVP.LOBBY.Access.RANKED or PVP.LOBBY.kind == PVP.LOBBY.Access.CASUAL
end

function PVP.UI.lobby.reset_ready()
	local b = PVP.UI.lobby.buttons
	PVP.UI.lobby.ready:reset()
	PVP.UI.lobby.start_broadcasted = false
	PVP.UI.lobby.start_hold = nil
	if PVP.UI.lobby.refresh_buttons then
		PVP.UI.lobby.refresh_buttons()
		return
	end
	for _, name in ipairs({ "ready", "start_game", "party_find_game" }) do
		if b[name] then
			b[name]:update()
		end
	end
end

-- The tally is the view's: every seated player's Ready as the server shows it. The host's buttons and
-- the matchmaking auto-start read it.
function PVP.UI.lobby.apply_ready(by_player, present)
	local lobby = PVP.UI.lobby.ref
	if not lobby then
		return
	end
	PVP.UI.lobby.present = present
	PVP.UI.lobby.ready:reset()
	for player_id, ready in pairs(by_player) do
		PVP.UI.lobby.ready:set(player_id, ready)
	end
	if PVP.LOBBY.is_matchmaking() then
		PVP.UI.lobby.maybe_autostart()
	end
end

local function can_autostart(L)
	return not L.start_broadcasted
		and L.ref
		and L.ref.is_host
		and PVP.LOBBY.is_matchmaking()
		and (L.present or 0) >= 2
		and L.ready:all_ready()
end

-- Host-only matchmaking auto-start: once all clients are ready, hold for the match reveal's
-- countdown (ui/queue/reveal.lua), then start exactly once. The hold is the host's, so every
-- client's reveal ends on the same game start and the Draft's turn clock starts after it.
function PVP.UI.lobby.maybe_autostart()
	local L = PVP.UI.lobby
	if L.start_hold or not can_autostart(L) then
		return
	end
	local hold, lobby = {}, L.ref
	L.start_hold = hold
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = PVP.UI.queue.reveal.HOLD_SECONDS,
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
				PVP.LOBBY.start_match()
			end
			return true
		end,
	}))
end

G.FUNCS.mp_pvp_toggle_ready = function()
	PVP.UI.lobby.press_ready()
end
