-- Lobby create/join/start flow + lobby-access enum shared by private lobbies and
-- matchmaking (see queue.lua). All heavy lifting is in the API + PVP's run flow.

PVP.LOBBY.Access = {
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
function PVP.RULES.default_ruleset(gamemode_key, kind)
	local def = PVP.RULES.MODES[gamemode_key] or PVP.RULES.MODES.pvp_nemesis
	if kind == PVP.LOBBY.Access.PRIVATE and def.private_ruleset then
		return def.private_ruleset
	end
	return def.ruleset
end

-- Call when adopting a new gamemode key, before the first LOBBY.metadata().
-- That function keeps whatever's already in config (so a Lobby Options pick
-- survives re-broadcasts), which means a stale ruleset from the last lobby
-- sticks unless it's reset here.
function PVP.RULES.reset_to_gamemode_default(gamemode_key, kind)
	local def = PVP.RULES.MODES[gamemode_key] or PVP.RULES.MODES.pvp_nemesis
	PVP.LOBBY.config.ruleset = PVP.RULES.default_ruleset(gamemode_key, kind)
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
-- gamemode key's own default -- see PVP.RULES.reset_to_gamemode_default above.
function PVP.LOBBY.metadata(gamemode_key, kind)
	local def = PVP.RULES.MODES[gamemode_key] or PVP.RULES.MODES.pvp_nemesis
	local meta = {
		cocktail_recipe = PVP.QUEUE.policy.cocktail_recipe(kind),
		gamemode = PVP.LOBBY.config.gamemode or def.gamemode,
		ruleset = PVP.LOBBY.config.ruleset or PVP.RULES.default_ruleset(gamemode_key, kind),
		queue_mode = gamemode_key,
		kind = kind or PVP.LOBBY.Access.PRIVATE,
		deck = PVP.LOBBY.config.back or "Red Deck",
		stake = tostring(PVP.LOBBY.config.stake or 1),
		starting_lives = PVP.LOBBY.config.starting_lives or 4,
		pvp_start_ante = PVP.LOBBY.config.pvp_start_ante or 2,
		manhunt_hunter_lives = PVP.LOBBY.config.manhunt_hunter_lives or 7,
		trap_cards = PVP.LOBBY.config.trap_cards == true,
		-- The server refuses a start without these three, so a missing option stays
		-- missing here rather than getting a guessed value.
		timer_base_seconds = PVP.LOBBY.config.timer_base_seconds,
		timer_forgiveness = PVP.LOBBY.config.timer_forgiveness,
		timer_increment_seconds = PVP.LOBBY.config.timer_increment_seconds,
	}
	-- A private lobby's host sets these in Lobby Options (ui/lobby/lobby_options.lua).
	-- Matchmade and practice lobbies keep the config's own defaults and the rulesets' forced options.
	if (kind or PVP.LOBBY.Access.PRIVATE) == PVP.LOBBY.Access.PRIVATE then
		for _, key in ipairs(PVP.LOBBY.PRIVATE_OPTION_KEYS) do
			meta[key] = PVP.LOBBY.config[key]
		end
		meta.deck_mode = PVP.LOBBY.config.deck_mode or PVP.LOBBY.DeckMode.SELECT
		meta.verified_lobby = PVP.VERIFIED.compute()
	end
	return meta
end

-- How a private lobby picks its deck: the host chooses one, or the players run the Draft.
PVP.LOBBY.DeckMode = { SELECT = "select", DRAFT = "draft" }

-- Lobby config fields a private lobby's host can set, carried in the lobby metadata.
PVP.LOBBY.PRIVATE_OPTION_KEYS = {
	"gold_on_life_loss",
	"no_gold_on_pvp_loss",
	"death_on_normal_blind_loss",
	"normal_bosses",
	"timer",
	"timer_base_seconds",
	"timer_increment_seconds",
	"pvp_countdown_seconds",
	"preview_disabled",
	"the_order",
	"smallerworld",
	"different_seeds",
	"different_decks",
	"random_loadout",
	"custom_seed",
}

-- A Ranked or private lobby plays its ruleset's forced lobby options (MLBa:
-- 180 s timer, no The Order, no preview; Vanilla: no The Order). The lobby
-- options do not cross the wire, so every client applies them from the shared
-- ruleset. These lobbies have no Setup vote, so this is where they apply; the
-- Casual votes apply them in PVP.SETUP.apply_results. The host of a private
-- lobby can change the ruleset, so The Order goes back on before the ruleset
-- forces its options.
local FORCES_LOBBY_OPTIONS = { [PVP.LOBBY.Access.RANKED] = true, [PVP.LOBBY.Access.PRIVATE] = true }

function PVP.RULES.force_lobby_options(kind, ruleset_key)
	if not FORCES_LOBBY_OPTIONS[kind] then
		return
	end
	local def = ruleset_key and MPAPI.Rulesets[ruleset_key]
	if def and def.force_lobby_options then
		PVP.LOBBY.config.the_order = true
		def:force_lobby_options(kind)
	end
end

function PVP.LOBBY.create_private(gamemode_key)
	gamemode_key = gamemode_key or PVP.RULES.GamemodeKey.PVP_NEMESIS
	-- Reject an unregistered gamemode key up front instead of silently
	-- degrading: PVP.RULES.reset_to_gamemode_default/LOBBY.metadata
	-- both quietly fall back to the nemesis ruleset's config for an
	-- unknown key, but PVP.LOBBY.mode_key itself keeps the bogus literal
	-- string -- so round.lua's reset_blinds (PVP.RULES.gamemodes[gamemode_key])
	-- never finds a match and the nemesis/PvP boss blind mechanism never
	-- engages for the whole match, with no error shown to either player.
	-- Confirmed live with "pvp_standard" (not a real key -- valid ones are
	-- pvp_nemesis/smallworld/royale/manhunt/teams/experimental): the match
	-- proceeded normally through a full ante with
	-- zero PvP scoring/lives, indistinguishable from a working match until
	-- someone noticed nothing PvP-shaped ever happened.
	if not PVP.RULES.MODES[gamemode_key] then
		sendWarnMessage("pvp_create_private_lobby: unknown gamemode key '" .. tostring(gamemode_key) .. "'", "MULTIPLAYER")
		return
	end
	-- Block creating a lobby while in matchmaking. The replay re-enters THIS
	-- function (not MPAPI.create_lobby) so "Leave Queue & Continue" runs the full
	-- setup -- LOBBY.mirror + the CONNECTED UI transition below. Replaying
	-- the API primitive would allocate the lobby server-side but leave the client
	-- stranded on the menu.
	if MPAPI.matchmaking.guard_queued(function() return PVP.LOBBY.create_private(gamemode_key) end) then
		return
	end
	local gm = MPAPI.GameModes[gamemode_key]
	local max_p = (gm and gm.get_max_players and gm:get_max_players(MPAPI.LobbyType and MPAPI.LobbyType.PRIVATE or "private")) or 2
	local lobby = MPAPI.create_lobby(PVP.id, { max_players = max_p })
	if not lobby then
		sendWarnMessage("pvp_create_private_lobby: failed to create lobby", "MULTIPLAYER")
		return
	end
	PVP.LOBBY.kind = PVP.LOBBY.Access.PRIVATE
	PVP.LOBBY.mode_key = gamemode_key
	PVP.RULES.reset_to_gamemode_default(gamemode_key, PVP.LOBBY.Access.PRIVATE)
	PVP.LOBBY.mirror(lobby)
	PVP.LOBBY.set_exit_page(lobby, "pvp_main_menu")
	lobby:on(MPAPI.LobbyEvent.CONNECTED, function()
		if lobby.is_host then
			PVP.UI.lobby.send_settings(lobby, PVP.LOBBY.metadata(gamemode_key, PVP.LOBBY.Access.PRIVATE))
		end
		if love and love.system and love.system.setClipboardText then
			pcall(love.system.setClipboardText, lobby.code)
		end
		MPAPI.refresh_current_view()
	end)
end

-- (Ready system + lobby button handlers live in ui/pvp_lobby.lua.)

function PVP.LOBBY.join(code)
	if not code or code == "" then
		return
	end
	code = tostring(code):gsub("%s", "")
	-- Block joining while in matchmaking. The replay re-enters THIS function (not
	-- MPAPI.join_lobby) so "Leave Queue & Continue" runs the full setup --
	-- LOBBY.mirror + its CONNECTED UI transition. Replaying the API
	-- primitive would join server-side (the host sees you) but leave your client
	-- stranded on the PvP menu.
	if MPAPI.matchmaking.guard_queued(function() return PVP.LOBBY.join(code) end) then
		return
	end
	local lobby = MPAPI.join_lobby(PVP.id, code)
	if not lobby then
		sendWarnMessage("pvp_join_lobby: failed to join " .. tostring(code), "MULTIPLAYER")
		return
	end
	PVP.LOBBY.kind = PVP.LOBBY.Access.PRIVATE
	PVP.LOBBY.mirror(lobby)
	PVP.LOBBY.set_exit_page(lobby, "pvp_main_menu")
end

-- Where the player lands when `lobby` closes, also after a run it closed during
-- (MPAPI.set_lobby_exit_page): instead of the PvP main menu, or Balatro's own
-- menu after a run. With an MPAPI that has no exit pages, nothing changes.
function PVP.LOBBY.set_exit_page(lobby, page, params)
	if lobby and MPAPI.set_lobby_exit_page then
		MPAPI.set_lobby_exit_page(lobby, page, params)
	end
end

-- Host-only: attach a per-run gamemode instance (the API's inert blind hooks) then ask the server to
-- start the game.
function PVP.LOBBY.start_match()
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
		PVP.UI.UTILS.overlay_message(PVP.NET.version_gate.message(mismatches[1]))
		return
	end
	local stake = tonumber(PVP.LOBBY.deck.stake or PVP.LOBBY.config.stake)
	if not stake then return PVP.UI.refusal.show_no_stake() end
	local queue_mode = (lobby:get_metadata() or {}).queue_mode or PVP.LOBBY.mode_key or PVP.RULES.GamemodeKey.PVP_NEMESIS
	local gm_def = MPAPI.GameModes[queue_mode]
	if gm_def and gm_def.new_instance then
		lobby:set_gamemode_instance(gm_def:new_instance())
	end
	-- A private lobby plays the host's Cocktail, rolled fresh each game. It goes out
	-- before the start so every player has it when the deck applies; false clears
	-- the last game's recipe when the host's settings pick no decks.
	if PVP.LOBBY.kind == PVP.LOBBY.Access.PRIVATE then
		PVP.UI.lobby.send_settings(lobby, { cocktail_recipe = PVP.COCKTAIL.roll_recipe() or false })
	end
	-- Start is a numbered input: the server checks who's ready and picks the seed, a refusal comes back
	-- in the lobby view (pvp_api/ui/lobby.lua), and everyone starts off GAME_STARTED (pvp_api/lobby_bridge.lua).
	PVP.UI.lobby.send_start({
		stake = stake,
		options = { queue_mode = queue_mode },
	})
end

-- The single leave-lobby path (the legacy G.FUNCS.lobby_leave was folded in here).
-- Leaves the API lobby, ends the PvP session (lib/session.lua; also reached through
-- the lobby's own teardown, which for a server lobby lands only once the leave
-- round-trip returns) and returns to the menu. Callers: the lobby view, the
-- shortcuts menu, the end screen, and the join-failure bailout.
function PVP.LOBBY.leave()
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		lobby:leave()
	end
	PVP.LOBBY.end_session()
	PVP.LOBBY.version_warning_shown = false
	if G.STATE ~= G.STATES.MENU then
		G.STATE = G.STATES.MENU
	end
	if PVP.UI and PVP.UI.update_connection_status then
		PVP.UI.update_connection_status()
	end
end

-- Create-lobby click (main menu) opens the gamemode picker; its buttons call
-- PVP.LOBBY.create_private(...) directly. Handler defined in
-- ui/pvp_main_menu.lua, colocated with its overlay (join/ready/start/leave
-- handlers live in the menu + lobby UI files the same way).
