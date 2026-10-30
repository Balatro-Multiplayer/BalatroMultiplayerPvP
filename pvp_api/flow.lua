-- Lobby create/join/start flow + lobby-access enum shared by private lobbies and
-- matchmaking (see queue.lua). All heavy lifting is in the API + PVP's run flow.

PVP.LobbyAccess = {
	PRIVATE = "private",
	PRACTICE = "practice",
	RANKED = "ranked",
	CASUAL = "casual",
	-- A Party lobby's metadata kind (pvp_api/party_lobby.lua). Its client kind stays PRIVATE.
	PARTY = MPAPI.Party.KIND,
	RANKED_PREFIX = "ranked:",
}

-- Stamps PVP.LOBBY.config.ruleset/gamemode to this gamemode key's defaults.
-- Every entry point that adopts a NEW gamemode key (a fresh private lobby, a
-- fresh matchmaking queue join, a fresh practice run) must call this before its
-- first pvp_lobby_metadata() -- that function prefers whatever's ALREADY in
-- PVP.LOBBY.config (so a private lobby's later Lobby Options ruleset override
-- survives re-broadcasts instead of reverting to this gamemode's default every
-- time), so the slate has to be genuinely reset here first, not left holding
-- module-load's own hardcoded default or a leftover from an unrelated lobby
-- browsed earlier this session.
function PVP.reset_ruleset_to_gamemode_default(gamemode_key)
	local def = PVP.PVP_GAMEMODES[gamemode_key] or PVP.PVP_GAMEMODES.pvp_nemesis
	PVP.LOBBY.config.ruleset = def.ruleset
	PVP.LOBBY.config.gamemode = def.gamemode
end

-- Host-authored shared lobby metadata. `gamemode`/`ruleset` are MPAPI's own content
-- keys (e.g. "gamemode_mp_attrition" / "ruleset_mp_balanced") so MPAPI.ApplyBans/
-- MPAPI.get_active_gamemode() resolve directly to the banned_*-bearing object, no
-- translation needed. `queue_mode` carries the separate API/queue/bridge key (e.g.
-- "pvp_nemesis") that the matchmaking taxonomy, ban_pick draft, and per-lobby
-- MPAPI.GameModes[...] instance (forfeit handling) still need.
--
-- ruleset/gamemode prefer the ALREADY-current PVP.LOBBY.config value over the
-- gamemode key's own default -- see PVP.reset_ruleset_to_gamemode_default above.
function PVP.pvp_lobby_metadata(gamemode_key, kind)
	local def = PVP.PVP_GAMEMODES[gamemode_key] or PVP.PVP_GAMEMODES.pvp_nemesis
	return {
		gamemode = PVP.LOBBY.config.gamemode or def.gamemode,
		ruleset = PVP.LOBBY.config.ruleset or def.ruleset,
		queue_mode = gamemode_key,
		kind = kind or PVP.LobbyAccess.PRIVATE,
		deck = PVP.LOBBY.config.back or "Red Deck",
		stake = tostring(PVP.LOBBY.config.stake or 1),
		starting_lives = PVP.LOBBY.config.starting_lives or 4,
		pvp_start_round = PVP.LOBBY.config.pvp_start_round or 2,
		manhunt_hunter_lives = PVP.LOBBY.config.manhunt_hunter_lives or 7,
		trap_cards = PVP.LOBBY.config.trap_cards == true,
	}
end

-- A Ranked or private lobby plays its ruleset's forced lobby options (MLBa:
-- 180 s timer, no The Order, no preview; Vanilla: no The Order). The lobby
-- options do not cross the wire, so every client applies them from the shared
-- ruleset. These lobbies have no Setup vote, so this is where they apply; the
-- Casual votes apply them in PVP.SETUP.apply_results. The host of a private
-- lobby can change the ruleset, so The Order goes back on before the ruleset
-- forces its options.
local FORCES_LOBBY_OPTIONS = { [PVP.LobbyAccess.RANKED] = true, [PVP.LobbyAccess.PRIVATE] = true }

function PVP.force_lobby_options(kind, ruleset_key)
	if not FORCES_LOBBY_OPTIONS[kind] then
		return
	end
	local def = ruleset_key and MPAPI.Rulesets[ruleset_key]
	if def and def.force_lobby_options then
		PVP.LOBBY.config.the_order = true
		def:force_lobby_options(kind)
	end
end

function PVP.pvp_create_private_lobby(gamemode_key)
	gamemode_key = gamemode_key or PVP.GamemodeKey.PVP_NEMESIS
	-- Reject an unregistered gamemode key up front instead of silently
	-- degrading: PVP.reset_ruleset_to_gamemode_default/pvp_lobby_metadata
	-- both quietly fall back to the nemesis ruleset's config for an
	-- unknown key, but PVP._pvp_gamemode itself keeps the bogus literal
	-- string -- so round.lua's reset_blinds (PVP.Gamemodes[gamemode_key])
	-- never finds a match and the nemesis/PvP boss blind mechanism never
	-- engages for the whole match, with no error shown to either player.
	-- Confirmed live with "pvp_standard" (not a real key -- valid ones are
	-- pvp_nemesis/smallworld/royale/manhunt/teams/experimental): the match
	-- proceeded normally through a full ante with
	-- zero PvP scoring/lives, indistinguishable from a working match until
	-- someone noticed nothing PvP-shaped ever happened.
	if not PVP.PVP_GAMEMODES[gamemode_key] then
		sendWarnMessage("pvp_create_private_lobby: unknown gamemode key '" .. tostring(gamemode_key) .. "'", "MULTIPLAYER")
		return
	end
	-- Block creating a lobby while in matchmaking. The replay re-enters THIS
	-- function (not MPAPI.create_lobby) so "Leave Queue & Continue" runs the full
	-- setup -- setup_lobby_mirror + the CONNECTED UI transition below. Replaying
	-- the API primitive would allocate the lobby server-side but leave the client
	-- stranded on the menu.
	if MPAPI.matchmaking.guard_queued(function() return PVP.pvp_create_private_lobby(gamemode_key) end) then
		return
	end
	local gm = MPAPI.GameModes[gamemode_key]
	local max_p = (gm and gm.get_max_players and gm:get_max_players(MPAPI.LobbyType and MPAPI.LobbyType.PRIVATE or "private")) or 2
	local lobby = MPAPI.create_lobby(PVP.id, { max_players = max_p })
	if not lobby then
		sendWarnMessage("pvp_create_private_lobby: failed to create lobby", "MULTIPLAYER")
		return
	end
	PVP._pvp_kind = PVP.LobbyAccess.PRIVATE
	PVP._pvp_gamemode = gamemode_key
	PVP.reset_ruleset_to_gamemode_default(gamemode_key)
	PVP.setup_lobby_mirror(lobby)
	lobby:on(MPAPI.LobbyEvent.CONNECTED, function()
		if lobby.is_host then
			lobby:set_metadata(PVP.pvp_lobby_metadata(gamemode_key, PVP.LobbyAccess.PRIVATE))
		end
		if love and love.system and love.system.setClipboardText then
			pcall(love.system.setClipboardText, lobby.code)
		end
		MPAPI.refresh_current_view()
	end)
end

-- (Ready system + lobby button handlers live in ui/pvp_lobby.lua.)

function PVP.pvp_join_lobby(code)
	if not code or code == "" then
		return
	end
	code = tostring(code):gsub("%s", "")
	-- Block joining while in matchmaking. The replay re-enters THIS function (not
	-- MPAPI.join_lobby) so "Leave Queue & Continue" runs the full setup --
	-- setup_lobby_mirror + its CONNECTED UI transition. Replaying the API
	-- primitive would join server-side (the host sees you) but leave your client
	-- stranded on the PvP menu.
	if MPAPI.matchmaking.guard_queued(function() return PVP.pvp_join_lobby(code) end) then
		return
	end
	local lobby = MPAPI.join_lobby(PVP.id, code)
	if not lobby then
		sendWarnMessage("pvp_join_lobby: failed to join " .. tostring(code), "MULTIPLAYER")
		return
	end
	PVP._pvp_kind = PVP.LobbyAccess.PRIVATE
	PVP.setup_lobby_mirror(lobby)
end

-- Host-only: attach a per-run gamemode instance (for forfeit handling + the API's
-- inert blind hooks) then trigger PVP's run-start, which broadcasts pvp_start_game.
function PVP.pvp_start_match()
	local lobby = MPAPI.get_current_lobby()
	if not lobby or not lobby.is_host then
		return
	end
	if #lobby:get_players() < 2 then
		PVP.UI.UTILS.overlay_message("Waiting for an opponent...")
		return
	end
	local queue_mode = (lobby:get_metadata() or {}).queue_mode or PVP._pvp_gamemode or PVP.GamemodeKey.PVP_NEMESIS
	local gm_def = MPAPI.GameModes[queue_mode]
	if gm_def and gm_def.new_instance then
		lobby:set_gamemode_instance(gm_def:new_instance())
	end
	if MPAPI.has_server_referee(lobby) then
		-- The server checks who's ready and picks the seed; everyone starts off
		-- GAME_STARTED (pvp_api/lobby_bridge.lua), where referee_reset runs host-side.
		lobby:start_game({
			stake = tonumber(PVP.LOBBY.deck.stake or PVP.LOBBY.config.stake or 1),
			options = { queue_mode = queue_mode },
		}, function(err)
			if err then
				PVP.UI.UTILS.overlay_message("Start refused: " .. tostring(err))
			end
		end)
		return
	end
	-- referee_reset runs host-side inside the pvp_start_game handler (loopback).
	PVP.ACTIONS.start_game()
end

-- The single leave-lobby path (the legacy G.FUNCS.lobby_leave was folded in here).
-- Leaves the API lobby, ends the PvP session (lib/session.lua; also reached through
-- the lobby's own teardown, which for a server lobby lands only once the leave
-- round-trip returns) and returns to the menu. Callers: the lobby view, the
-- shortcuts menu, the end screen, and the join-failure bailout.
function PVP.pvp_leave_lobby()
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		-- Mid-match leave: send the roster before the leave completes, so the
		-- others still see this player's jokers on their end screen. The leave
		-- waits for the roster to be relayed: it would otherwise reach the
		-- server first and the roster would be dropped.
		if G.STAGE == G.STAGES.RUN and PVP._match_players and PVP.GAME and PVP.GAME.lives then
			PVP.report_roster_result(function()
				lobby:leave()
			end)
		else
			lobby:leave()
		end
	end
	PVP.end_session()
	PVP._version_mismatch_shown = false
	if G.STATE ~= G.STATES.MENU then
		G.STATE = G.STATES.MENU
	end
	if PVP.UI and PVP.UI.update_connection_status then
		PVP.UI.update_connection_status()
	end
end

-- Create-lobby click (main menu) opens the gamemode picker; its buttons call
-- PVP.pvp_create_private_lobby(...) directly. Handler defined in
-- ui/pvp_main_menu.lua, colocated with its overlay (join/ready/start/leave
-- handlers live in the menu + lobby UI files the same way).
