-- PVP.LOBBY <- API-lobby mirror.
--
-- The whole PVP codebase (HUD, gameplay, run-start) reads PVP.LOBBY.* / PVP.GAME.*,
-- but the API owns the real lobby. This shim subscribes to the API lobby's events
-- and mirrors its state (code, host/guest identity, is_host, metadata->config) into
-- PVP.LOBBY so PVP's existing code keeps working unchanged. It is the PvP analog of
-- SPDRN.setup_lobby_events (BalatroMultiplayerSpeed/ui/lobby/events.lua).
--
-- Call PVP.setup_lobby_mirror(lobby) right after MPAPI.create_lobby / join_lobby /
-- a matchmaking lobby_ready, before signalling ready.

-- Fixed opponent-side labels for gamemodes where the PvP boss blind doesn't
-- face a single named player (Royale/Manhunt/Teams) -- centralized here so
-- they're a one-line change to reskin later, instead of literals scattered
-- across every call site. Team.A/Team.B are placeholders until real
-- user-chosen team names exist.
PVP.DISPLAY_NAMES = {
	royale = "The Royale",
	manhunt_hunters = "The Hunters", -- shown to the Runner
	manhunt_runner = "The Runner", -- shown to a Hunter
	team = { A = "Team A", B = "Team B" }, -- shown to the opposing team
}

-- The " (catching up)" badge after the target's location in the HUD (ui/game/enemy_location.lua):
-- set while the server says the target is replaying its run after a crash. The target itself comes
-- from the view (pvp_api/target_screen.lua).
function PVP.refresh_catching_up_badge()
	if not (PVP.GAME and PVP.GAME.enemy) then
		return
	end
	local lobby = MPAPI.get_current_lobby()
	local target_id = lobby and PVP.current_target_id()
	local catching_up = target_id and lobby:is_player_catching_up(target_id)
	PVP.GAME.enemy.catching_up_text = catching_up and (" (" .. localize("k_catching_up") .. ")") or ""
end

-- The name shown on the PvP boss blind (key "bl_mp_nemesis", the shared marker
-- for every gamemode's PvP boss -- see gamemodes/attrition.lua) for the CURRENT
-- gamemode:
--  - Nemesis-pairing or a plain 2-player lobby: a single real opponent, so show
--    their actual username, same as everywhere else PVP.LOBBY.host/.guest is
--    read. That mirror is nil until the view names a target, so mask to "????"
--    rather than feed a nil string to DynaText.
--  - Manhunt (N>2): there's no single named opponent from either role's POV --
--    show the fixed "The Hunters"/"The Runner" label instead.
--  - Teams (N>2): the blind shows the whole opposing team's aggregate score,
--    not any one member -- show that team's fixed label.
--  - Royale (N>2, no pairing): show the fixed "The Royale" label.
-- A Nemesis player with no nemesis this ante (a bye) gets "Bye".
function PVP.pvp_blind_opponent_name()
	if (PVP.my_boss() == "bye") then
		return localize("k_bye")
	end
	-- The view has not said yet whether I have an opponent this ante.
	if PVP.my_boss() == "unknown" then
		return "????"
	end
	local lobby = MPAPI.get_current_lobby()
	if PVP.LOBBY.config.nemesis_pairing or not lobby or #lobby:get_players() == 2 then
		local opponent = PVP.LOBBY.is_host and PVP.LOBBY.guest or PVP.LOBBY.host
		return opponent.username or "????"
	end
	if PVP.LOBBY.config.manhunt then
		return PVP.LOBBY.team_id == "RUNNER" and PVP.DISPLAY_NAMES.manhunt_hunters
			or PVP.DISPLAY_NAMES.manhunt_runner
	end
	if PVP.LOBBY.config.team_based then
		local opposing = (PVP.LOBBY.team_id == "A") and "B" or "A"
		return PVP.DISPLAY_NAMES.team[opposing] or PVP.DISPLAY_NAMES.team.A
	end
	return PVP.DISPLAY_NAMES.royale
end

local function player_name(lobby, player_id)
	for _, p in ipairs(lobby:get_players()) do
		if p.id == player_id then
			return p.displayName or p.id
		end
	end
	return nil
end

-- Names seen in each lobby, by player id. A player who leaves or whose
-- disconnect grace runs out is already gone from the roster when that event
-- fires, so the notice reads their name from here.
local known_names = setmetatable({}, { __mode = "k" })

local function remember_names(lobby)
	local names = known_names[lobby] or {}
	known_names[lobby] = names
	for _, p in ipairs(lobby:get_players()) do
		if p.id and p.displayName then
			names[p.id] = p.displayName
		end
	end
end

local function departed_player_name(lobby, player_id)
	local names = known_names[lobby]
	local name = (names and names[player_id]) or player_name(lobby, player_id)
	if name and name ~= player_id then return name end
	for _, player in ipairs({ PVP.LOBBY.host, PVP.LOBBY.guest }) do
		if player and player.id == player_id and player.username then
			return player.username
		end
	end
	return "Opponent"
end

-- Copy the host-authored shared metadata into PVP.LOBBY.config / PVP.LOBBY.deck so
-- PVP's ruleset/gamemode/option reads resolve. Metadata carries the lobby config
-- fields plus PvP keys (gamemode/ruleset/kind/deck/stake).
local function mirror_metadata(lobby)
	local meta = lobby:get_metadata() or {}
	if meta.cocktail_recipe and not PVP.receive_cocktail_recipe(meta.cocktail_recipe) then return false end
	-- `gamemode`/`ruleset` in metadata are already MPAPI's own content keys
	-- ("gamemode_mp_attrition" / "ruleset_mp_balanced"), so they pass straight
	-- through -- MPAPI.get_active_gamemode()/get_active_ruleset() read this same
	-- metadata directly and need no translation. `queue_mode` carries the separate
	-- API/queue/bridge key (e.g. "pvp_nemesis") only nemesis_pairing derivation below
	-- still needs.
	local def = meta.queue_mode and PVP.PVP_GAMEMODES and PVP.PVP_GAMEMODES[meta.queue_mode]
	for k, v in pairs(meta) do
		if k ~= "deck" and k ~= "kind" then
			PVP.LOBBY.config[k] = v
		end
	end
	-- nemesis_pairing isn't part of the shared metadata schema, so it can't ride the
	-- generic loop above -- but every client (not just the host, who's the only one
	-- that runs the active gamemode's start_run) needs it set correctly, since
	-- attrition.lua's bye check and the target readers all run client-side.
	-- Derive it the same way gamemode/ruleset are derived here.
	PVP.LOBBY.config.nemesis_pairing = (def and def.nemesis_pairing) or nil
	-- Same derivation for Manhunt/Teams -- every client (not just the host) needs
	-- these to read the right target and the lobby-options picker, since none
	-- of them ride the generic per-key loop above.
	PVP.LOBBY.config.manhunt = (def and def.manhunt) or nil
	PVP.LOBBY.config.team_based = (def and def.team_based) or nil
	-- A ruleset's default_modifiers (Experimental's pvp_timer + pressure_timer) are
	-- layers on top of it for the whole lobby. Every client derives them from the
	-- mirrored ruleset, so they follow a Lobby Options ruleset change and agree
	-- without a metadata field of their own. The only other modifier is Trap
	-- cards: the private lobby host's switch here, the Casual vote below.
	if PVP.LOBBY.config.ruleset then
		MPAPI.apply_default_modifiers(PVP.LOBBY.config.ruleset)
		if (meta.kind or PVP._pvp_kind) == PVP.LobbyAccess.PRIVATE and meta.trap_cards == true then
			MPAPI.add_modifier("traps")
		end
		PVP.LOBBY.config.modifier_layers = MPAPI.modifiers_serialize()
	end
	-- With Different Decks a guest keeps their own pick; the host's deck is only the host's.
	local own_deck = PVP.LOBBY.config.different_decks == true and not lobby.is_host
	if meta.deck and not own_deck then
		PVP.LOBBY.deck.back = meta.deck
	end
	if meta.stake and not own_deck then
		PVP.LOBBY.deck.stake = tonumber(meta.stake) or PVP.LOBBY.deck.stake
	end
	if not meta.cocktail_recipe then PVP.LOBBY.deck.cocktail_recipe = nil end
	-- A guest's first mirror (from lobby_ready) runs before the host's metadata
	-- arrives, so the queued kind stands in for it.
	PVP.force_lobby_options(meta.kind or PVP._pvp_kind, PVP.LOBBY.config.ruleset)
	-- The Casual votes' ruleset and Trap cards go over the queued ones
	-- (pvp_api/setup.lua), after the modifier reset above.
	PVP.SETUP.apply_results(lobby)
end
PVP.mirror_lobby_metadata = mirror_metadata

-- Reflect roster/host state into the PVP.LOBBY.host / .guest identity slots that PVP's
-- HUD and enemy tracking read. Every live caller of these slots (blind_hud, game_end,
-- blind_choice, matchmaking cancel text, Distro.lua) uses the
-- `is_host and LOBBY.guest or LOBBY.host` idiom purely to mean "my current
-- opponent" -- never "whichever player is the literal lobby host" -- so the
-- non-self slot must resolve to PVP.current_target_id(), not an arbitrary roster
-- pick. It is empty until the view names a target; target_screen.lua mirrors
-- again when the target changes.
--
-- Teams is the one exception -- its blind shows the whole opposing TEAM's
-- combined score (run.targets.teamScores), not any single member's, so naming
-- it after the card target would show a name that doesn't match what the score
-- represents. "Team A"/"Team B" is the opposing team's label.
local function mirror_players(lobby)
	remember_names(lobby)
	local self_name = player_name(lobby, lobby.player_id) or PVP.LOBBY.username or "Guest"
	local opp_id = PVP.current_target_id()
	local opp_name
	if PVP.LOBBY.config.team_based and PVP.LOBBY.team_id then
		local opposing = (PVP.LOBBY.team_id == "A") and "B" or "A"
		opp_name = PVP.DISPLAY_NAMES.team[opposing]
	else
		opp_name = opp_id and player_name(lobby, opp_id) or nil
	end
	-- An opponent who leaves mid-match drops out of the roster, so current_target_id() goes
	-- nil and the slot would blank: the end screen then read "Your Nemesis ????". During a
	-- run, keep the name last seen in this same lobby.
	local previous = lobby.is_host and PVP.LOBBY.guest or PVP.LOBBY.host
	local opponent = opp_name and { username = opp_name, id = opp_id, lobby = lobby } or {}
	if not opp_name and previous and previous.lobby == lobby and previous.username and G.STAGE == G.STAGES.RUN then
		opponent = previous
	end
	PVP.LOBBY.is_host = lobby.is_host and true or false
	if lobby.is_host then
		PVP.LOBBY.host = { username = self_name, id = lobby.player_id }
		PVP.LOBBY.guest = opponent
	else
		PVP.LOBBY.host = opponent
		PVP.LOBBY.guest = { username = self_name, id = lobby.player_id }
	end
end
PVP.mirror_players = mirror_players

PVP.setup_lobby_mirror = function(lobby)
	-- Kept per lobby: a later PLAYER_LEFT after a socket drop means the
	-- disconnect grace period expired, rather than a voluntary leave.
	local disconnected_players = {}
	-- The "waiting for reconnection" notice pauses the game; closed once everyone is back,
	-- us included. Who is away, and when the server forfeits them, is read from the lobby roster
	-- (is_away, forfeits_at_local). Back or Esc hides the notice: the small line (reconnect_screen.lua,
	-- or away_screen.lua in a run) then counts down to the forfeit until they are back or gone. Both
	-- end on their own: our rejoin gives up after the seat's grace (the lobby is left), and an
	-- opponent past it is a PLAYER_LEFT.
	-- Shown only once a drop has lasted NOTICE_DELAY: a quick rejoin goes unseen. The server
	-- holds the clocks from the drop on, so nothing is lost meanwhile.
	local NOTICE_DELAY = 3
	local own_connection = "up" -- "up" | "dropped"
	local surfaced = {} -- ids whose absence the player has been shown
	local hidden = {} -- ids whose big notice the player dismissed
	local disconnect_notice = nil
	local notice_wait = nil -- the pending wait; replaced to drop it
	local on_frame
	-- Who is away: id -> { who = "me" } or { who = "other", name, forfeits_at }. Players no longer
	-- away leave `surfaced` and `hidden` here.
	local function away_now()
		local away = {}
		for _, player in ipairs(lobby:get_players()) do
			if player.is_away and player.id ~= lobby.player_id then
				away[player.id] = { who = "other", name = departed_player_name(lobby, player.id), forfeits_at = player.forfeits_at_local }
			end
		end
		if own_connection == "dropped" then away[lobby.player_id] = { who = "me" } end
		for id in pairs(surfaced) do
			if not away[id] then surfaced[id] = nil end
		end
		for id in pairs(hidden) do
			if not away[id] then hidden[id] = nil end
		end
		return away
	end
	-- The line belongs to the newest lobby; an older lobby's late events leave it alone.
	local function sync_line()
		if PVP.reconnect_screen.on_frame ~= on_frame then return end
		local listed = {}
		for id, entry in pairs(away_now()) do
			if surfaced[id] then listed[id] = entry end
		end
		PVP.reconnect_screen.sync(listed, disconnect_notice == nil)
	end
	local function show_away_notice()
		local id, entry
		for other, other_entry in pairs(away_now()) do
			if not hidden[other] and (id == nil or other_entry.who == "me") then id, entry = other, other_entry end
		end
		if id == nil then
			-- Only our notice: a menu the player opened over it stays open.
			if disconnect_notice and G.OVERLAY_MENU == disconnect_notice then G.FUNCS.exit_overlay_menu() end
			disconnect_notice = nil
			sync_line()
			return
		end
		if entry.who == "me" then
			PVP.UI.UTILS.overlay_message(localize("k_mp_reconnecting"))
		else
			PVP.UI.UTILS.overlay_message(localize({ type = "variable", key = "k_pvp_player_waiting", vars = { entry.name } }))
		end
		disconnect_notice = G.OVERLAY_MENU
		for other in pairs(away_now()) do
			surfaced[other] = true
		end
		sync_line()
	end
	-- Once a frame: the notice gone while players are still away means the player dismissed it.
	on_frame = function()
		if disconnect_notice and G.OVERLAY_MENU ~= disconnect_notice then
			disconnect_notice = nil
			for id in pairs(away_now()) do
				hidden[id] = true
			end
			sync_line()
		end
	end
	PVP.reconnect_screen.adopt(on_frame)
	local function update_away_notice()
		if next(away_now()) == nil or disconnect_notice then
			notice_wait = nil
			show_away_notice()
		elseif not notice_wait then
			local wait = {}
			notice_wait = wait
			G.E_MANAGER:add_event(Event({
				trigger = "after",
				delay = NOTICE_DELAY,
				timer = "REAL",
				blocking = false,
				blockable = false,
				func = function()
					if notice_wait == wait then
						notice_wait = nil
						if next(away_now()) then show_away_notice() end
					end
					return true
				end,
			}))
		end
		sync_line()
	end
	PVP.CURRENT_LOBBY = lobby
	PVP.LOBBY.code = lobby.code
	PVP.LOBBY.connected = true
	PVP.LOBBY.is_host = lobby.is_host and true or false
	-- Manhunt/Teams role state must NOT carry over from a previous lobby: the
	-- same two players reconnecting into a different lobby (any gamemode, not
	-- just another Manhunt/Teams match) would otherwise inherit a stale
	-- "HUNTER"/"RUNNER"/"A"/"B" roster entry, which can stick as an invalid
	-- team_id for the new mode instead of being freshly assigned.
	PVP.LOBBY.roster = {}
	PVP.LOBBY.team_id = nil
	PVP.reset_game_states()
	-- Speed-style lobby view state: player-card grid + fresh ready tracker + buttons.
	if PVP.lobby then
		PVP.lobby.ref = lobby
		PVP.lobby.ui_ref = MPAPI.create_lobby_ui(lobby)
		PVP.lobby.buttons_initialized = false
		PVP.lobby.start_broadcasted = false
		PVP.lobby.present = nil
		PVP.lobby_screen.reset()
		if PVP.lobby.ready then
			PVP.lobby.ready:reset()
		end
	end
	if mirror_metadata(lobby) == false then return end
	mirror_players(lobby)
	PVP._version_mismatch_shown = false

	-- Shows the version overlay once per run of mismatches; it re-arms when they clear.
	local function check_version_mismatch()
		local mismatches = PVP.UTILS.version_mismatches()
		if #mismatches == 0 then
			PVP._version_mismatch_shown = false
		elseif not PVP._version_mismatch_shown then
			PVP._version_mismatch_shown = true
			PVP.UI.UTILS.overlay_message(PVP.VersionGate.message(mismatches[1]))
		end
	end

	local function refresh()
		if PVP.UI and PVP.UI.update_connection_status then
			pcall(PVP.UI.update_connection_status)
		end
		-- Rebuild the lobby view so roster/host/ready changes are reflected (e.g. the
		-- host's Start button appearing once the guest joins). No-op outside the menu.
		pcall(MPAPI.refresh_current_view)
	end

	lobby:on(MPAPI.LobbyEvent.CONNECTED, function()
		PVP.LOBBY.connected = true
		PVP.LOBBY.code = lobby.code
		-- A joiner's first Nakama snapshot fires only CONNECTED, not
		-- METADATA_CHANGED (api/lobby/nakama.lua apply_snapshot announces
		-- nothing on the first one), and the mirror call above ran before that
		-- snapshot arrived. Without this the joiner kept the module-default
		-- ruleset (Expanded) and no queue_mode/nemesis_pairing/manhunt/
		-- team_based for the whole match, while the host played the real one.
		-- Skipped while the metadata is still empty (a fresh lobby's host,
		-- whose own metadata write follows in flow.lua).
		if next(lobby:get_metadata() or {}) ~= nil then
			if mirror_metadata(lobby) == false then return end
		end
		mirror_players(lobby)
		update_away_notice()
		-- A joiner's snapshot already holds the players (and their mods) who were
		-- here first, and fires no PLAYER_JOINED or PLAYER_INFO for them.
		check_version_mismatch()
		-- A crash-rejoin resumes a run that was rebuilt with no lobby, so its
		-- HUD has no Lives or Timer box until the lobby is back.
		if G.STAGE == G.STAGES.RUN and PVP.UI and PVP.UI.apply_lobby_hud then
			pcall(PVP.UI.apply_lobby_hud)
		end
		refresh()
	end)

	lobby:on(MPAPI.LobbyEvent.PLAYER_CATCHING_UP, function()
		PVP.refresh_catching_up_badge()
	end)

	lobby:on(MPAPI.LobbyEvent.PLAYER_JOINED, function(player_id)
		mirror_players(lobby)
		PVP.refresh_verified_lobby(lobby)
		refresh()
		check_version_mismatch()
	end)

	-- A player's mod list reaches the lobby after they join (the server sends
	-- it once their client reports its mods), so the join alone cannot judge
	-- their version.
	lobby:on(MPAPI.LobbyEvent.PLAYER_INFO, function()
		PVP.refresh_verified_lobby(lobby)
		check_version_mismatch()
	end)

	lobby:on(MPAPI.LobbyEvent.PLAYER_LEFT, function(player_id)
		local departed_name = departed_player_name(lobby, player_id)
		local disconnected = disconnected_players[player_id]
		if player_id ~= lobby.player_id then
			local message = disconnected and (departed_name .. " did not reconnect.")
				or (departed_name .. " left the lobby.")
			PVP.UI.UTILS.overlay_message(message)
		end
		disconnected_players[player_id] = nil
		if next(away_now()) == nil then update_away_notice() end
		sync_line()
		PVP.refresh_verified_lobby(lobby)
		if PVP.lobby and PVP.lobby.ready then
			PVP.lobby.ready:remove(player_id)
		end
		mirror_players(lobby)
		-- Re-arms the overlay once the mismatched player is gone.
		check_version_mismatch()
		refresh()
	end)

	-- A Party lobby's Find Game pillars (ui/main_menu/find_game.lua) refuse
	-- while a player is away, so they follow players dropping and coming back.
	lobby:on(MPAPI.LobbyEvent.PLAYER_DISCONNECTED, function(player_id)
		if player_id and player_id ~= lobby.player_id then
			disconnected_players[player_id] = true
			hidden[player_id] = nil
			update_away_notice()
		end
		refresh()
	end)

	lobby:on(MPAPI.LobbyEvent.PLAYER_RECONNECTED, function(player_id)
		disconnected_players[player_id] = nil
		if player_id ~= lobby.player_id then
			if surfaced[player_id] then
				PVP.reconnect_screen.add_back(departed_player_name(lobby, player_id), love.timer.getTime())
			end
			if next(away_now()) == nil then update_away_notice() end
			sync_line()
		end
		refresh()
	end)

	lobby:on(MPAPI.LobbyEvent.METADATA_CHANGED, function(metadata)
		if mirror_metadata(lobby) == false then return end
		-- Passive: whatever changed the settings (or created the lobby), the host re-checks the
		-- verdict against the mirrored config and republishes only if it moved.
		PVP.refresh_verified_lobby(lobby)
		-- Setup may wait for the host's write of the rolled ruleset.
		PVP.SETUP.continue(lobby)
		MPAPI.refresh_current_view()
	end)

	-- A Party lobby's Find Game pillars grey a mode a player's standing
	-- refuses, so a change that moves that verdict rebuilds them.
	-- Only those: a joiner's first standing lands just after the join, and a
	-- rebuild then would close an overlay the host had just opened. Not once
	-- a game is on: a rejoin's playback starts from the main menu, and a
	-- rebuild under it replays its first actions twice.
	lobby:on(MPAPI.LobbyEvent.PLAYER_STANDING_CHANGED, function(_, standing, before)
		PVP.refresh_verified_lobby(lobby)
		if MPAPI.matchmaking.group.changes_refusal(before, standing) and not lobby:is_game_started() then
			refresh()
		end
	end)

	-- The group queue panel (ui/lobby/group_panel.lua) follows the queue.
	if MPAPI.LobbyEvent.GROUP_QUEUE then
		lobby:on(MPAPI.LobbyEvent.GROUP_QUEUE, function()
			refresh()
		end)
	end

	lobby:on(MPAPI.LobbyEvent.HOST_CHANGED, function()
		mirror_players(lobby)
		-- Before the run: we open the next Setup step if one is due (the Draft
		-- itself is opened by MPAPI.BanPick).
		PVP.SETUP.continue(lobby)
		MPAPI.refresh_current_view()
	end)

	lobby:on(MPAPI.LobbyEvent.SETUP_CHANGED, function()
		PVP.SETUP.on_changed(lobby)
	end)

	-- The session state itself was already ended by the lobby's teardown
	-- (lib/session.lua), which knows whether a newer PvP lobby has taken over.
	-- Our own socket dropped: our game pauses too while the API rejoins.
	lobby:on(MPAPI.LobbyEvent.CONNECTION_DROPPED, function()
		own_connection = "dropped"
		hidden[lobby.player_id] = nil
		update_away_notice()
	end)
	lobby:on(MPAPI.LobbyEvent.CONNECTION_RESTORED, function()
		own_connection = "up"
		update_away_notice()
	end)

	-- A rejoin's snapshot (and a first one) may hold players already away, with their forfeit times.
	lobby:on(MPAPI.LobbyEvent.SNAPSHOT_APPLIED, function()
		update_away_notice()
	end)

	lobby:on(MPAPI.LobbyEvent.DISCONNECTED, function()
		own_connection, surfaced, hidden = "up", {}, {}
		update_away_notice()
		if PVP.reconnect_screen.on_frame == on_frame then PVP.reconnect_screen.clear() end
		-- An old lobby's leave can be answered after the player is in a newer PvP
		-- lobby: that lobby owns PVP.lobby and the match handle now.
		local current = MPAPI.get_current_lobby()
		if current ~= nil and current ~= lobby and current.mod_id == PVP.id then
			return
		end
		if PVP.lobby then
			PVP.lobby.ref = nil
			PVP.lobby.ui_ref = nil
			PVP.lobby.buttons_initialized = false
		end
		-- Drop the matchmaking handle for a matchmade lobby. Its match_id keeps it lingering
		-- in mm.handles until the game ends (MATCH_RESOLVED); leaving before that would
		-- otherwise leak the handle (confused re-queue). Idempotent.
		if PVP._match_handle then
			PVP._match_handle:leave()
			PVP._match_handle = nil
		end
		PVP._pvp_kind = nil
		PVP._version_mismatch_shown = false
		refresh()
	end)

	lobby:on(MPAPI.LobbyEvent.ERROR, function(err)
		sendWarnMessage("Lobby error: " .. tostring(err), "MULTIPLAYER")
		PVP.refusal_screen.show(err)
	end)

	-- Ready and Start are inputs of the lobby view (lobby_screen.lua); the game start and its end come from the server.
	lobby:on(MPAPI.LobbyEvent.GAME_STARTED, function(started)
		local recipe = (lobby:get_metadata() or {}).cocktail_recipe
		if recipe and not PVP.receive_cocktail_recipe(recipe) then return end
		if started.restarted then
			PVP.game_effects.start_game(started.seed, PVP.LOBBY.deck.stake)
		else
			PVP.on_game_start({ seed = started.seed, stake = tostring(started.stake or 1) })
		end
	end)

	-- A contest in a match of 2 ends it for both. In a larger match only the
	-- contester leaves (their own client shows the screen once the server accepted
	-- it); everyone else gets a chat line (ui/contest_modal.lua).
	lobby:on(MPAPI.LobbyEvent.CONTESTED, function(contested)
		local by = contested and contested.by
		local scope = PVP.Contest.scope(PVP._match_players and #PVP._match_players, by, lobby.player_id)
		if scope == PVP.Contest.Scope.EVERYONE then
			PVP.show_contested_screen()
		elseif scope == PVP.Contest.Scope.BYSTANDER then
			PVP.note_contest_by(by)
		end
	end)

	lobby:on(MPAPI.LobbyEvent.GAME_ENDED, function(ended)
		PVP.SETUP.game = nil
		PVP.match_log("debug", "[pvp] game ended: " .. tostring(ended.status))
		PVP.last_game_ended = ended
		-- Only a match of 2 ends on a contest; in a larger one the others already
		-- have their own result and the contester their contested screen.
		if
			ended.status == PVP.Contest.RunStatus.CONTESTED
			and PVP.Contest.scope(PVP._match_players and #PVP._match_players, nil, nil) == PVP.Contest.Scope.EVERYONE
		then
			PVP.show_contested_screen()
		end
		if PVP.reset_ready_state then
			PVP.reset_ready_state()
		end
	end)
end

-- The lobby grid shows a player who is out or gone debuffed: during a run from the live view, back in the
-- lobby from the game that ended (as on main), until the next game starts.
MPAPI.register_player_status_provider(PVP.id, function(_lobby, player_data)
	return PVP.view.is_out(PVP.match_net and PVP.match_net.view, player_data.id)
end)
