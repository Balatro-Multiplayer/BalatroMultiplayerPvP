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

-- The single opponent in a 1v1 PvP lobby (nil until a second player is present).
function PVP.get_opponent_id()
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return nil
	end
	for _, p in ipairs(lobby:get_players()) do
		if p.id ~= lobby.player_id then
			return p.id
		end
	end
	return nil
end

-- The gamemode-defined "current target": whichever player's enemy-facing state
-- (score/hands/lives sync, HUD, joker targeting like Asteroid/Penny Pincher/the
-- Nemesis boss blind) should be treated as "the enemy" right now. Host-computed
-- and broadcast in every N>2 case -- never a client-side race.
--  - Nemesis-pairing (rotating no-repeat duels, N>2): this ante's assigned partner,
--    broadcast by the host each ante; nil if byed or not yet received.
--  - Plain 1v1: the sole other lobby player, unchanged from before this existed.
--  - Manhunt (N>2): a Hunter's target is always the sole Runner, resolved locally
--    from the roster (static for the whole match, no broadcast needed). The
--    Runner's target is whichever Hunter currently has the highest score --
--    PVP.GAME.manhunt_target_id, broadcast live by the host (pvp_api/referee.lua).
--  - Teams (N>2): PVP.GAME.team_card_target_id, one random opposing-team member
--    per player, re-picked once per ante by the host (same cadence as Nemesis
--    pairing) -- used for joker/consumable triggering. The Teams score DISPLAY is
--    a separate aggregate broadcast (pvp_team_score_board) read directly by the
--    HUD, not routed through current_target_id().
--  - Royale (N>2, no pairing): PVP.GAME.royale_target_id, broadcast live by the
--    host and personalized per player -- a safe player's target is the adjacent
--    player with the next-lower score (their safety margin), an unsafe player's
--    target is the adjacent player with the next-higher score (what they need to
--    beat). See PVP.referee_rank_royale/broadcast_royale_targets.
function PVP.current_target_id()
	if PVP.LOBBY.config.nemesis_pairing then
		return PVP.GAME.nemesis_partner_id
	end
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return nil
	end
	if #lobby:get_players() == 2 then
		return PVP.get_opponent_id()
	end
	if PVP.LOBBY.config.manhunt then
		if PVP.LOBBY.team_id == "HUNTER" then
			for id, role in pairs(PVP.LOBBY.roster or {}) do
				if role == "RUNNER" then
					return id
				end
			end
			return nil
		end
		return PVP.GAME.manhunt_target_id
	end
	if PVP.LOBBY.config.team_based then
		return PVP.GAME.team_card_target_id
	end
	return PVP.GAME.royale_target_id
end

-- The " (catching up)" badge after the target's location in the HUD (ui/game/enemy_location.lua):
-- set while the server says the target is replaying its run after a crash.
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
-- gamemode. Mirrors current_target_id()'s own branch order/reasoning above:
--  - Nemesis-pairing or a plain 2-player lobby: a single real opponent, so show
--    their actual username, same as everywhere else PVP.LOBBY.host/.guest is
--    read. That mirror is nil ("not yet known") until PVP.current_target_id()
--    latches, so mask to "????" rather than feed a nil string to DynaText.
--  - Manhunt (N>2): there's no single named opponent from either role's POV --
--    show the fixed "The Hunters"/"The Runner" label instead.
--  - Teams (N>2): the blind shows the whole opposing team's aggregate score,
--    not any one member -- show that team's fixed label.
--  - Royale (N>2, no pairing): show the fixed "The Royale" label.
-- A Nemesis player with no nemesis this ante (a bye) gets "Bye".
function PVP.pvp_blind_opponent_name()
	if PVP.is_announced_bye() then
		return localize("k_bye")
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

-- True only while byed in Nemesis-pairing mode (an odd-numbered alive roster
-- leaves one player without a partner this ante) -- distinct from "target not
-- yet received", which current_target_id() also represents as nil. Guards that
-- need to reject stray senders while genuinely byed must check this explicitly
-- rather than relying on current_target_id() == nil, which is ambiguous between
-- the two cases.
function PVP.is_byed()
	return PVP.LOBBY.config.nemesis_pairing and PVP.GAME.nemesis_partner_id == nil
end

-- True only for a bye the host has announced: is_byed() is also true before the
-- first pairing arrives, when the opponent is not yet known ("????", not "Bye").
function PVP.is_announced_bye()
	return PVP.is_byed() and PVP.GAME.nemesis_pairing_received == true
end

local function player_name(lobby, player_id)
	for _, p in ipairs(lobby:get_players()) do
		if p.id == player_id then
			return p.displayName or p.id
		end
	end
	return nil
end

-- Copy the host-authored shared metadata into PVP.LOBBY.config / PVP.LOBBY.deck so
-- PVP's ruleset/gamemode/option reads resolve. Metadata carries the lobby config
-- fields plus PvP keys (gamemode/ruleset/kind/deck/stake).
local function mirror_metadata(lobby)
	local meta = lobby:get_metadata() or {}
	-- `gamemode`/`ruleset` in metadata are already MPAPI's own content keys
	-- ("gamemode_mp_attrition" / "ruleset_mp_balanced"), so they pass straight
	-- through -- MPAPI.get_active_gamemode()/get_active_ruleset() read this same
	-- metadata directly and need no translation. `queue_mode` carries the separate
	-- API/queue/bridge key (e.g. "pvp_nemesis") only nemesis_pairing derivation below
	-- still needs.
	local def = meta.queue_mode and PVP.PVP_GAMEMODES and PVP.PVP_GAMEMODES[meta.queue_mode]
	for k, v in pairs(meta) do
		-- The referee's own checkpoint (referee.lua) isn't lobby config.
		if k ~= "deck" and k ~= "kind" and k ~= PVP.REF_CHECKPOINT_KEY then
			PVP.LOBBY.config[k] = v
		end
	end
	-- nemesis_pairing isn't part of the shared metadata schema, so it can't ride the
	-- generic loop above -- but every client (not just the host, who's the only one
	-- that runs the active gamemode's start_run) needs it set correctly, since
	-- PVP.current_target_id/attrition.lua's bye check/the joker-targeting guards all
	-- run client-side. Derive it the same way gamemode/ruleset are derived here.
	PVP.LOBBY.config.nemesis_pairing = (def and def.nemesis_pairing) or nil
	-- Same derivation for Manhunt/Teams -- every client (not just the host) needs
	-- these to resolve PVP.current_target_id(), the referee's mode branch, and the
	-- lobby-options picker, since none of them ride the generic per-key loop above.
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
	if meta.deck then
		PVP.LOBBY.deck.back = meta.deck
	end
	if meta.stake then
		PVP.LOBBY.deck.stake = tonumber(meta.stake) or PVP.LOBBY.deck.stake
	end
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
-- pick. In 1v1 that's still just the sole other player (current_target_id()
-- delegates to PVP.get_opponent_id() there); in Royale/Nemesis (N>2) it's nil
-- until a target latches, same "not yet known" semantics as the masked
-- score/hands fields elsewhere -- not a wrong name.
--
-- §17.2: Teams is the one exception -- its blind shows the whole opposing
-- TEAM's combined score (pvp_team_score_board), not any single member's, so
-- naming it after current_target_id()'s pick (one random opposing-team member,
-- chosen for joker-targeting purposes only -- see that function's own header
-- comment) would show a name that doesn't match what the score represents.
-- "Team A"/"Team B" mirrors the exact enemy_team derivation team_manhunt.lua's
-- own pvp_team_score_board receive handler already uses for the same purpose.
local function mirror_players(lobby)
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
	-- Who was out of the last lobby's match (the referee's lives, the lives
	-- cache) means nothing in another lobby: a group back home from its public
	-- match otherwise showed whoever lost there crossed out on the home
	-- lobby's cards (ui/game/player_status_provider.lua). By the lobby object,
	-- not its code: a join by code has no code until its first snapshot.
	if PVP.CURRENT_LOBBY ~= lobby then
		PVP._player_lives_cache = nil
		if PVP.REF then
			PVP.REF.players = {}
		end
	end
	PVP.CURRENT_LOBBY = lobby
	PVP.LOBBY.code = lobby.code
	PVP.LOBBY.connected = true
	PVP.LOBBY.is_host = lobby.is_host and true or false
	-- Manhunt/Teams role state must NOT carry over from a previous lobby: the
	-- same two players reconnecting into a different lobby (any gamemode, not
	-- just another Manhunt/Teams match) would otherwise inherit a stale
	-- "HUNTER"/"RUNNER"/"A"/"B" roster entry, which -- since referee_reset's
	-- team_based default ("pl.team_id or 'A'") only fires when team_id is still
	-- nil -- can silently stick as an invalid team_id for the new mode instead of
	-- being freshly assigned.
	PVP.LOBBY.roster = {}
	PVP.LOBBY.team_id = nil
	PVP.reset_game_states()
	-- Speed-style lobby view state: player-card grid + fresh ready tracker + buttons.
	if PVP.lobby then
		PVP.lobby.ref = lobby
		PVP.lobby.ui_ref = MPAPI.create_lobby_ui(lobby)
		PVP.lobby.buttons_initialized = false
		PVP.lobby.local_ready = false
		PVP.lobby.start_broadcasted = false
		if PVP.lobby.ready then
			PVP.lobby.ready:reset()
		end
	end
	mirror_metadata(lobby)
	mirror_players(lobby)

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
			mirror_metadata(lobby)
		end
		mirror_players(lobby)
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
		PVP.TRAP_ROW.on_player_back(player_id)
		refresh()
		local mismatches = PVP.UTILS.version_mismatches()
		if #mismatches > 0 and not PVP._version_mismatch_shown then
			PVP._version_mismatch_shown = true
			PVP.UI.UTILS.overlay_message(PVP.UTILS.version_mismatch_message(mismatches[1]))
		end
	end)

	lobby:on(MPAPI.LobbyEvent.PLAYER_LEFT, function(player_id)
		if PVP.lobby and PVP.lobby.ready then
			PVP.lobby.ready:remove(player_id)
		end
		if PVP.lobby and PVP.lobby.seed_votes then
			PVP.lobby.seed_votes:remove(player_id)
		end
		if PVP.lobby and PVP.lobby.draw_votes then
			PVP.lobby.draw_votes:remove(player_id)
		end
		mirror_players(lobby)
		PVP.TRAP_ROW.forget(player_id)
		-- The gamemode's forfeit hook (host-authoritative) handles a mid-match leave.
		local gm = lobby.get_gamemode_instance and lobby:get_gamemode_instance()
		-- A pending death decides it instead: leaving with one is not a forfeit.
		if
			gm
			and gm.on_player_forfeit
			and G.STAGE == G.STAGES.RUN
			and not PVP.referee_pending_death_on_player_gone(player_id)
		then
			MPAPI._handle_gamemode_result(gm, gm:on_player_forfeit(player_id))
		end
		refresh()
	end)

	-- Phase 9: reconnect tail-replay. PLAYER_RECONNECTED fires to every lobby
	-- member (including the reconnecting player's own client, once it
	-- rejoins the match) -- only act when the reconnecting
	-- player IS us; the opponent's own client needs no catch-up, it never
	-- disconnected. See pvp_api/reconnect_tail.lua.
	-- A Party lobby's Find Game pillars (ui/main_menu/find_game.lua) refuse
	-- while a player is away, so they follow players dropping and coming back.
	lobby:on(MPAPI.LobbyEvent.PLAYER_DISCONNECTED, function()
		refresh()
	end)

	lobby:on(MPAPI.LobbyEvent.PLAYER_RECONNECTED, function(player_id)
		refresh()
		PVP.TRAP_ROW.on_player_back(player_id)
		if player_id ~= lobby.player_id then
			PVP.referee_on_player_reconnected(player_id)
			return
		end
		-- The host may have changed while we were away.
		PVP._pvp_action_helpers.forget_host(lobby)
		if G.STAGE ~= G.STAGES.RUN then return end
		local opponent_id = PVP.get_opponent_id()
		if opponent_id then
			PVP.RECONNECT_TAIL.catch_up(opponent_id)
		end
	end)

	-- The same catch-up on a Nakama lobby: the tail comes with the rejoin
	-- itself, and the server tells only the others that we're back.
	lobby:on(MPAPI.LobbyEvent.REPLAY_TAIL, function(tails)
		PVP.RECONNECT_TAIL.receive_pushed_tails(tails)
		if G.STAGE ~= G.STAGES.RUN then return end
		local opponent_id = PVP.get_opponent_id()
		if opponent_id then
			PVP.RECONNECT_TAIL.catch_up(opponent_id)
		end
	end)

	lobby:on(MPAPI.LobbyEvent.METADATA_CHANGED, function(metadata)
		mirror_metadata(lobby)
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

	lobby:on(MPAPI.LobbyEvent.HOST_CHANGED, function(host_id)
		-- Host-only actions are taken from this player now (pvp_api/actions/_helpers.lua).
		PVP._pvp_action_helpers.note_host(lobby, host_id)
		mirror_players(lobby)
		-- The host left mid-run (a crash, a dropped connection) and the server
		-- made us host: the referee is ours now.
		if lobby.is_host and G.STAGE == G.STAGES.RUN and not PVP.is_practice_mode() then
			PVP.referee_take_over()
		end
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
	lobby:on(MPAPI.LobbyEvent.DISCONNECTED, function()
		if PVP.lobby then
			PVP.lobby.ref = nil
			PVP.lobby.ui_ref = nil
			PVP.lobby.buttons_initialized = false
		end
		if PVP.stop_ready_resync then
			PVP.stop_ready_resync()
		end
		-- Drop the matchmaking handle for a matchmade lobby. Its match_id keeps it lingering
		-- in mm.handles until the game ends (MATCH_RESOLVED); leaving before that would
		-- otherwise leak the handle (confused re-queue). Idempotent.
		if PVP._match_handle then
			PVP._match_handle:leave()
			PVP._match_handle = nil
		end
		PVP._pvp_kind = nil
		refresh()
	end)

	lobby:on(MPAPI.LobbyEvent.ERROR, function(err)
		sendWarnMessage("Lobby error: " .. tostring(err), "MULTIPLAYER")
	end)

	-- Server-refereed lobbies: ready, start, restart and the end of a game come from
	-- the server rather than from PVP's own actions (whose handlers do the same work).
	lobby:on(MPAPI.LobbyEvent.PLAYER_READY_CHANGED, function(player_id, ready)
		if MPAPI.has_server_referee(lobby) then
			PVP.set_player_ready(player_id, ready)
		end
	end)

	lobby:on(MPAPI.LobbyEvent.GAME_STARTED, function(started)
		if started.restarted then
			PVP.on_reseed(started.seed)
		else
			PVP.on_game_start({ seed = started.seed, stake = tostring(started.stake or 1) })
		end
	end)

	-- A contest in a match of 2 ends it for both. In a larger match only the
	-- contester leaves (their own client shows the screen once the server accepted
	-- it); everyone else gets a chat line (ui/contest_modal.lua).
	lobby:on(MPAPI.LobbyEvent.CONTESTED, function(contested)
		local by = contested and contested.by
		local scope = PVP.Contest.scope(PVP._match_players and #PVP._match_players, by, PVP.self_player_id())
		if scope == PVP.Contest.Scope.EVERYONE then
			PVP.show_contested_screen()
		elseif scope == PVP.Contest.Scope.BYSTANDER then
			PVP.note_contest_by(by)
		end
	end)

	lobby:on(MPAPI.LobbyEvent.GAME_ENDED, function(ended)
		PVP.SETUP.game = nil
		sendDebugMessage("[pvp] game ended: " .. tostring(ended.status), "MULTIPLAYER")
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
