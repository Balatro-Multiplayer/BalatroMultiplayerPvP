-- Crash-relaunch reconnect: called once the lobby object itself has already
-- been recreated (MPAPI._internal.create_reconnected_lobby, driven by
-- BalatroMultiplayerAPI's ui/reconnect_prompt.lua) and there's no active
-- RLOG match run to hand off to instead (that's the OTHER branch of that
-- file's Reconnect handler -- this one only ever runs pre-match: waiting
-- room or mid-ban-pick-draft).
MPAPI.register_lobby_reconnect(PVP.id, function(lobby)
	-- Mirrors pvp_api/flow.lua / queue.lua's own PVP._pvp_kind assignment --
	-- every other entry path sets this from the button the player actually
	-- clicked (Create Private / Find Match / Ranked Queue); a reconnect has
	-- no such click to read, so it's derived from the lobby's own
	-- server-reported type instead. MPAPI.LobbyType has no CASUAL value of
	-- its own (only PUBLIC/PRIVATE/RANKED) -- PVP's own "casual" matchmaking
	-- queue is what a plain PUBLIC lobby type means here.
	if lobby.type == MPAPI.LobbyType.RANKED then
		PVP._pvp_kind = PVP.LobbyAccess.RANKED
	elseif lobby.type == MPAPI.LobbyType.PUBLIC then
		PVP._pvp_kind = PVP.LobbyAccess.CASUAL
	else
		PVP._pvp_kind = PVP.LobbyAccess.PRIVATE
	end

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
