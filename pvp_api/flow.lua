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

-- The host's deck and stake. The host sends these alone when they change:
-- set_metadata merges, so the rest of the metadata stays as it is.
function PVP.lobby_loadout_metadata()
	return {
		deck = PVP.LOBBY.config.back or "Red Deck",
		stake = tostring(PVP.LOBBY.config.stake or 1),
	}
end

-----------------------------
-- The host's changes to the ruleset: metadata.custom
--   options = { manhunt_hunter_lives = 9 }  options the ruleset leaves open
--   layers  = { "traps" }                   layers from the ruleset's optional_layers
-- Every client reads it (PVP.setting, PVP.apply_lobby_layers); only the host
-- writes it, always whole.
-----------------------------

local EMPTY_CUSTOM = { options = {}, layers = {} }

-- `lobby` defaults to the current one.
function PVP.lobby_custom(lobby)
	local meta = lobby and lobby:get_metadata() or PVP.lobby_metadata()
	local c = meta and meta.custom
	if type(c) ~= "table" then return EMPTY_CUSTOM end
	return { options = type(c.options) == "table" and c.options or {}, layers = type(c.layers) == "table" and c.layers or {} }
end

-- Whether `ruleset_key` lets the host turn layer `name` on.
function PVP.is_optional_layer(ruleset_key, name)
	local def = ruleset_key and MPAPI.Rulesets[ruleset_key]
	for _, n in ipairs(def and def.optional_layers or {}) do
		if n == name then return true end
	end
	return false
end

-- The entries of `custom` that `ruleset_key` still allows: options its
-- lobby_options leave open, layers in its optional_layers. Pure.
function PVP.filter_custom(custom, ruleset_key)
	local def = ruleset_key and MPAPI.Rulesets[ruleset_key] or {}
	local fixed = def.lobby_options or {}
	local out = { options = {}, layers = {} }
	for k, v in pairs(custom and custom.options or {}) do
		if fixed[k] == nil then out.options[k] = v end
	end
	for _, n in ipairs(custom and custom.layers or {}) do
		if PVP.is_optional_layer(ruleset_key, n) then out.layers[#out.layers + 1] = n end
	end
	return out
end

function PVP.lobby_has_layer(name)
	for _, n in ipairs(PVP.lobby_custom().layers) do
		if n == name then return true end
	end
	return false
end

-- The modifier layers for `ruleset_key` plus the host's: the ruleset's
-- default_modifiers, then each allowed custom layer. Rebuilt whole on every
-- metadata change, so nothing outlives the ruleset or the host's switch.
function PVP.apply_lobby_layers(ruleset_key, layers)
	MPAPI.apply_default_modifiers(ruleset_key)
	for _, n in ipairs(layers or {}) do
		if PVP.is_optional_layer(ruleset_key, n) then MPAPI.add_modifier(n) end
	end
	PVP.LOBBY.config.modifier_layers = MPAPI.modifiers_serialize()
end

-- Called from every metadata mirror (the Casual vote), so a no-op change must
-- not write again.
local function same_custom(a, b)
	for k, v in pairs(a.options) do
		if b.options[k] ~= v then return false end
	end
	for k in pairs(b.options) do
		if a.options[k] == nil then return false end
	end
	if #a.layers ~= #b.layers then return false end
	local seen = {}
	for _, n in ipairs(a.layers) do seen[n] = true end
	for _, n in ipairs(b.layers) do
		if not seen[n] then return false end
	end
	return true
end

local function host_of(lobby)
	return lobby and lobby.is_host and lobby or nil
end

-- Sets several options in one metadata write, for options that only make sense
-- together.
function PVP.set_lobby_options(lobby, changes)
	if not host_of(lobby) then return end
	local custom = PVP.lobby_custom(lobby)
	local options = {}
	for k, v in pairs(custom.options) do options[k] = v end
	for k, v in pairs(changes) do options[k] = v end
	lobby:set_metadata({ custom = PVP.filter_custom({ options = options, layers = custom.layers }, (lobby:get_metadata() or {}).ruleset) })
end

function PVP.set_lobby_option(lobby, key, value)
	PVP.set_lobby_options(lobby, { [key] = value })
end

function PVP.set_lobby_layer(lobby, name, on)
	if not host_of(lobby) then return end
	local custom = PVP.lobby_custom(lobby)
	local layers = {}
	for _, n in ipairs(custom.layers) do
		if n ~= name then layers[#layers + 1] = n end
	end
	if on then layers[#layers + 1] = name end
	lobby:set_metadata({ custom = PVP.filter_custom({ options = custom.options, layers = layers }, (lobby:get_metadata() or {}).ruleset) })
end

-- A new lobby's full metadata, written once by its host. `gamemode`/`ruleset` are
-- MPAPI's own content keys (e.g. "gamemode_mp_attrition" / "ruleset_mp_balanced")
-- so MPAPI.ApplyBans/MPAPI.get_active_gamemode() resolve directly to the
-- banned_*-bearing object. `queue_mode` carries the separate API/queue/bridge key
-- (e.g. "pvp_nemesis") that the matchmaking taxonomy, ban_pick draft, and per-lobby
-- MPAPI.GameModes[...] instance (forfeit handling) still need.
--
-- The ruleset is `ruleset_key` when the entry point picked one (Ranked, Practice,
-- a replay), else the gamemode's default for this kind. Nothing is read back from
-- an earlier lobby. Later changes go through PVP.set_lobby_ruleset.
function PVP.pvp_lobby_metadata(gamemode_key, kind, ruleset_key, gamemode)
	local def = PVP.PVP_GAMEMODES[gamemode_key] or PVP.PVP_GAMEMODES.pvp_nemesis
	local meta = PVP.lobby_loadout_metadata()
	meta.cocktail_recipe = PVP.MatchmakingPolicy.cocktail_recipe(kind)
	meta.gamemode = gamemode or def.gamemode
	meta.ruleset = ruleset_key or PVP.default_ruleset(gamemode_key, kind)
	meta.queue_mode = gamemode_key
	meta.kind = kind or PVP.LobbyAccess.PRIVATE
	meta.custom = { options = {}, layers = {} }
	return meta
end

-- The one way a lobby changes ruleset after it opens: the host rewrites the
-- metadata, and every client's mirror follows. The host's changes carry over
-- where the new ruleset still allows them; the rest are dropped, not kept for
-- a later switch back. `custom` replaces them instead (the Casual vote's Trap
-- cards).
function PVP.set_lobby_ruleset(lobby, ruleset_key, custom)
	if not (host_of(lobby) and ruleset_key) then
		return
	end
	local next_custom = PVP.filter_custom(custom or PVP.lobby_custom(lobby), ruleset_key)
	local meta = lobby:get_metadata() or {}
	if meta.ruleset == ruleset_key and same_custom(PVP.lobby_custom(lobby), next_custom) then
		return
	end
	lobby:set_metadata({ ruleset = ruleset_key, custom = next_custom })
end

function PVP.pvp_create_private_lobby(gamemode_key)
	gamemode_key = gamemode_key or PVP.GamemodeKey.PVP_NEMESIS
	-- Reject an unregistered gamemode key up front instead of silently
	-- degrading: PVP.default_ruleset/pvp_lobby_metadata
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
