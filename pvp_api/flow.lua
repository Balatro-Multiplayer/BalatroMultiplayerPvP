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

-- Private lobbies open on `private_ruleset` if the entry has one; everything
-- else plays `ruleset`. Only place that decides a default ruleset.
function PVP.default_ruleset(gamemode_key, kind)
	local def = PVP.PVP_GAMEMODES[gamemode_key] or PVP.PVP_GAMEMODES.pvp_nemesis
	if kind == PVP.LobbyAccess.PRIVATE and def.private_ruleset then
		return def.private_ruleset
	end
	return def.ruleset
end

-- Call when adopting a new gamemode key, before the first pvp_lobby_metadata().
-- That function keeps whatever's already in config (so a Lobby Options pick
-- survives re-broadcasts), which means a stale ruleset from the last lobby
-- sticks unless it's reset here.
function PVP.reset_ruleset_to_gamemode_default(gamemode_key, kind)
	local def = PVP.PVP_GAMEMODES[gamemode_key] or PVP.PVP_GAMEMODES.pvp_nemesis
	PVP.LOBBY.config.ruleset = PVP.default_ruleset(gamemode_key, kind)
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
	kind = kind or PVP.LobbyAccess.PRIVATE
	local meta = {
		cocktail_recipe = PVP.MatchmakingPolicy.cocktail_recipe(kind),
		gamemode = PVP.LOBBY.config.gamemode or def.gamemode,
		ruleset = PVP.LOBBY.config.ruleset or PVP.default_ruleset(gamemode_key, kind),
		queue_mode = gamemode_key,
		kind = kind,
		deck = PVP.LOBBY.config.back or "Red Deck",
		stake = tostring(PVP.LOBBY.config.stake or 1),
		starting_lives = PVP.LOBBY.config.starting_lives or 4,
		pvp_start_round = PVP.LOBBY.config.pvp_start_round or 2,
		manhunt_hunter_lives = PVP.LOBBY.config.manhunt_hunter_lives or 7,
		trap_cards = PVP.LOBBY.config.trap_cards == true,
	}
	if kind == PVP.LobbyAccess.PRIVATE then
		-- Keep intent as well as effective values: a promoted guest must be able to
		-- release a lock without guessing what the previous host had picked.
		meta.setting_choices = {}
		for key, value in pairs(PVP.LOBBY.setting_choices or {}) do meta.setting_choices[key] = value end
		for _, key in ipairs(PVP.PRIVATE_OPTION_KEYS) do
			if meta[key] == nil then
				meta[key] = PVP.LOBBY.config[key]
			end
		end
		meta.deck_mode = PVP.LOBBY.config.deck_mode or PVP.DeckMode.SELECT
		meta.verified_lobby = PVP.compute_verified_lobby()
	end
	return meta
end

-- How a private lobby picks its deck: the host chooses one, or the players run the Draft.
PVP.DeckMode = { SELECT = "select", DRAFT = "draft" }

-- Lobby config fields a private lobby's host can set, carried in the lobby metadata:
-- every key the lobby settings schema writes (lib/lobby_settings.lua).
PVP.PRIVATE_OPTION_KEYS = PVP.lobby_settings_config_keys()

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
	PVP.reset_ruleset_to_gamemode_default(gamemode_key, PVP.LobbyAccess.PRIVATE)
	PVP.setup_lobby_mirror(lobby)
	PVP.set_lobby_exit_page(lobby, "pvp_main_menu")
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
	PVP.set_lobby_exit_page(lobby, "pvp_main_menu")
end

-- Where the player lands when `lobby` closes, also after a run it closed during
-- (MPAPI.set_lobby_exit_page): instead of the PvP main menu, or Balatro's own
-- menu after a run. With an MPAPI that has no exit pages, nothing changes.
function PVP.set_lobby_exit_page(lobby, page, params)
	if lobby and MPAPI.set_lobby_exit_page then
		MPAPI.set_lobby_exit_page(lobby, page, params)
	end
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
	local mismatches = PVP.UTILS.version_mismatches()
	if #mismatches > 0 then
		PVP.UI.UTILS.overlay_message(PVP.VersionGate.message(mismatches[1]))
		return
	end
	local queue_mode = (lobby:get_metadata() or {}).queue_mode or PVP._pvp_gamemode or PVP.GamemodeKey.PVP_NEMESIS
	local gm_def = MPAPI.GameModes[queue_mode]
	if gm_def and gm_def.new_instance then
		lobby:set_gamemode_instance(gm_def:new_instance())
	end
	-- A private lobby plays the host's Cocktail, rolled fresh each game. It goes out
	-- before the start so every player has it when the deck applies; false clears
	-- the last game's recipe when the host's settings pick no decks.
	if PVP._pvp_kind == PVP.LobbyAccess.PRIVATE then
		lobby:set_metadata({ cocktail_recipe = PVP.roll_cocktail_recipe() or false })
	end
	if MPAPI.has_server_referee(lobby) then
		-- The server checks who's ready and picks the seed; everyone starts off
		-- GAME_STARTED (pvp_api/lobby_bridge.lua), where referee_reset runs host-side.
		lobby:start_game({
			stake = tonumber(PVP.LOBBY.deck.stake or PVP.LOBBY.config.stake or 1),
			options = { queue_mode = queue_mode },
		}, function(err)
			if err and PVP.VersionGate.is_server_refusal(err) then
				PVP.UI.UTILS.overlay_message(PVP.VersionGate.refused_message())
			elseif err then
				PVP.UI.UTILS.overlay_message(localize({ type = "variable", key = "k_start_refused", vars = { tostring(err) } }))
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
