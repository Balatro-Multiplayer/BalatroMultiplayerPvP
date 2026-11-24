-- A PvP session is a real lobby, a practice run or a replay playback. Its
-- state (lobby config, ruleset, PVP.GAME's run flags, practice flags, PvP's
-- MPAPI.MODIFIERS) means nothing once it ends, and left in place it leaks into
-- whatever the player does next: a vanilla run, or another mod's game.
-- PVP.LOBBY.end_session is the one place it is cleared; it runs when MPAPI tears
-- down any PvP lobby, however the player got out of it.

-- True while the current lobby is the PvP lobby PvP mirrors (from creation,
-- before its first snapshot gives it a code), or a practice or playback run is
-- under way. Outside it, PvP rules must not apply.
function PVP.LOBBY.in_session()
	local mirrored = PVP.LOBBY.current ~= nil and PVP.LOBBY.current == MPAPI.get_current_lobby()
	return (mirrored or PVP.LOBBY.in_lobby_or_practice()) and true or false
end

function PVP.LOBBY.end_session()
	PVP.LOBBY.connected = false
	PVP.LOBBY.code = nil
	PVP.LOBBY.current = nil
	PVP.LOBBY.kind = nil
	PVP.LOBBY.mode_key = nil
	PVP.PRACTICE.practice = false
	PVP.PRACTICE.ruleset = nil
	PVP.PRACTICE.playback_gamemode = nil
	PVP.LOBBY.reset_config()
	PVP.LOBBY.reset_game()
	-- Only PvP fills MPAPI.MODIFIERS (lobby_bridge's apply_default_modifiers).
	MPAPI.MODIFIERS = {}
end

-- A leave is asynchronous: by the time an old lobby is gone the player may
-- already be in a new PvP lobby, whose state must survive the old one's end.
local function superseded_by_another_pvp_lobby(gone_lobby)
	local current = MPAPI.get_current_lobby()
	return current ~= nil and current ~= gone_lobby and current.mod_id == PVP.id
end

MPAPI.on_lobby_gone(PVP.id, function(lobby)
	if superseded_by_another_pvp_lobby(lobby) then
		return
	end
	PVP.LOBBY.end_session()
end)

-- Back at the menu with no lobby and no queue, nothing can still be using a
-- ruleset stamped without a lobby (a ranked queue left before it matched).
local session_go_to_menu_ref = G.FUNCS.go_to_menu
G.FUNCS.go_to_menu = function(e)
	if not MPAPI.get_current_lobby() and not MPAPI.get_busy_mod() then
		PVP.LOBBY.end_session()
	end
	return session_go_to_menu_ref(e)
end
