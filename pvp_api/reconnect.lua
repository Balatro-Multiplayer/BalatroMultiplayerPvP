-- PvP's lobby kind for a lobby this client rejoined. Every other entry path sets
-- PVP._pvp_kind from the button the player clicked (Create Private / Find Match / Ranked
-- Queue); a rejoin has no such click to read, so it comes from the lobby's own server-reported
-- type. MPAPI.LobbyType has no CASUAL value of its own (only PUBLIC/PRIVATE/RANKED): PvP's
-- "casual" matchmaking queue is what a plain PUBLIC lobby type means here.
function PVP.rejoined_lobby_kind(lobby)
	if lobby.type == MPAPI.LobbyType.RANKED then
		return PVP.LobbyAccess.RANKED
	elseif lobby.type == MPAPI.LobbyType.PUBLIC then
		return PVP.LobbyAccess.CASUAL
	end
	return PVP.LobbyAccess.PRIVATE
end

-- Crash-relaunch reconnect: called once the lobby object itself has already
-- been recreated (MPAPI._internal.create_reconnected_lobby, driven by
-- BalatroMultiplayerAPI's ui/reconnect_prompt.lua) and there's no active
-- RLOG match run to hand off to instead (that's the OTHER branch of that
-- file's Reconnect handler -- this one only ever runs pre-match: waiting
-- room or mid-ban-pick-draft).
MPAPI.register_lobby_reconnect(PVP.id, function(lobby)
	PVP._pvp_kind = PVP.rejoined_lobby_kind(lobby)

	PVP.setup_lobby_mirror(lobby)

	-- Rejoin a game still in Setup (a vote or the Draft): the server's
	-- snapshot already restored the Setup state (lobby._game.setup), so the
	-- game start runs again and picks up where Setup is. Finished results are
	-- not run again.
	local started = lobby._game and lobby._game.started
	local setup = lobby._game and lobby._game.setup
	local in_setup = setup and (setup.open or next(setup.results or {}))
	if MPAPI.has_server_referee(lobby) and started and not started.restarted and in_setup then
		PVP.on_game_start({ seed = started.seed, stake = tostring(started.stake or 1) })
	end
end)
