-- §22.2/§22.3 (Phase 5): bootstraps a local, single-player run seeded to
-- reproduce a PREVIOUSLY RECORDED match's exact seed/deck/stake/ruleset --
-- distinct from PVP._start_practice (lib/practice_mode.lua), which uses
-- practice's own ephemeral defaults, since a human practicing doesn't care
-- about matching a specific past match's cards. Reuses the exact same
-- local-lobby machinery (MPAPI.create_local_lobby/setup_lobby_mirror)
-- practice mode does -- see practice_mode.lua's own header comment for why
-- that reuse is safe (same primitives real private lobbies use). A local
-- lobby's `.code` stays nil (MPAPI.create_local_lobby never sets one), which
-- is also why PVP.RLOG never records during a playback session already,
-- confirmed live: RLOG.is_active() (lib/replay_log.lua) already gates on
-- `PVP.LOBBY.code`, unchanged -- no separate "don't record during replay"
-- guard needed.
--
-- `manifest` is the {seed, deck, sleeve, challenge, stake, ruleset, gamemode,
-- ...} table recorded once per match by PVP.RLOG.begin_run (see
-- networking/action_handlers.lua's action_start_game) and shipped as the
-- carbon log's own "manifest" event -- i.e. exactly what
-- MPAPI.playback.build_timeline's first event already carries for whichever
-- player is chosen as POV.
function PVP._start_playback(manifest, on_ready)
	-- Guard against being invoked while still connected to a real lobby --
	-- confirmed live to hang the whole instance: creating a local lobby
	-- (below) while the real lobby's own leave/teardown is still an
	-- in-flight async API call (see PVP.pvp_leave_lobby -> lobby:leave(),
	-- api/lobby/state.lua) leaves two lobby objects
	-- fighting over MPAPI's current-lobby state at once. The real UI entry
	-- points (replay/spectate browsers) are only menu-reachable, never
	-- mid-match, so refusing here is a pure safety net, not a real-world
	-- workflow this blocks.
	if PVP.LOBBY and PVP.LOBBY.code then
		sendWarnMessage("PVP._start_playback: refusing to start while connected to a real lobby (" .. tostring(PVP.LOBBY.code) .. ")", "MULTIPLAYER")
		return
	end

	-- Queued for matchmaking: lobby_start_run below would be refused by MPAPI's
	-- start_run queue guard only AFTER this function had already set
	-- PVP.SP.practice, made a local lobby, and armed the BLIND_SELECT waiter --
	-- all left behind, so the waiter fired on the next BLIND_SELECT (the real
	-- matched run's) and started the replay there. Gate before touching anything;
	-- "Leave Queue & Continue" re-enters this whole function.
	if MPAPI.matchmaking.guard_queued(function() return PVP._start_playback(manifest, on_ready) end) then
		return
	end

	PVP._drop_playback_waiters()
	PVP.reset_lobby_config()
	PVP.SP.practice = true
	PVP.SP.ruleset = manifest.ruleset

	local lobby = MPAPI.create_local_lobby(PVP.id, { max_players = 1 })
	if not lobby then
		PVP.SP.practice = false
		return
	end
	lobby.suppress_lobby_view = true
	PVP._pvp_kind = PVP.LobbyAccess.PRACTICE
	PVP._pvp_gamemode = manifest.gamemode
	PVP.setup_lobby_mirror(lobby)

	-- lobby_start_run (networking/action_handlers.lua) reads deck/stake off
	-- PVP.LOBBY.deck, NOT off the args table passed to it (args.stake there is
	-- unused dead weight -- confirmed by reading its body) -- these must be set
	-- here for the seed to actually reproduce the original match's cards.
	-- The lobby config gets them too: set_metadata's mirror and copy_host_deck copy
	-- config back onto the deck, and a default config would reset it to Red Deck.
	PVP.apply_replay_loadout(PVP.LOBBY, manifest)

	PVP.GAME.lives = PVP.LOBBY.config.starting_lives

	-- A restart (a checkpoint seek, the second pass of a crash rejoin) starts this from inside a
	-- run that is still on screen. on_ready waits for the new run's own blind-select screen: the
	-- old run's would fire it before the new run exists.
	local old_game = G.GAME

	lobby:on(MPAPI.LobbyEvent.CONNECTED, function()
		PVP.LOBBY.guest = { username = "???", id = "practice" }
		lobby:set_metadata(PVP.pvp_lobby_metadata(manifest.gamemode, PVP.LobbyAccess.PRACTICE))
		-- MPAPI fires CONNECTED from inside a queued Event. G.FUNCS.start_run clears the event
		-- queue, and doing that while EventManager:update iterates it makes the manager remove the
		-- wrong event after this one returns: the queued delete_run (the new run then builds a
		-- second blind HUD, and the SMODS blind HUD assert crashes the game) or the queued
		-- G:start_run (the run never starts). Start the run from the next Game:update instead.
		PVP._playback_next_frame(function()
			G.FUNCS.lobby_start_run(nil, { seed = manifest.seed })
		end)
	end)

	PVP._playback_wait_for(function()
		return G.GAME ~= old_game and G.STATE == G.STATES.BLIND_SELECT
	end, on_ready)
end

-- Minimal, self-contained one-shot condition poll (no ClaudeControl
-- dependency -- MPAPI/PvP must work standalone without it installed).
-- Mirrors the shape of MPAPI's own Game:update-hook pattern
-- (BalatroMultiplayerAPI/api/playback/driver.lua) rather than copying
-- ClaudeControl's coroutine-based lib/wait.lua directly.
PVP._playback_waiters = PVP._playback_waiters or {}

function PVP._playback_wait_for(predicate, callback)
	PVP._playback_waiters[#PVP._playback_waiters + 1] = { predicate = predicate, callback = callback }
end

-- Runs `callback` from the next Game:update, outside any event the queue is running.
function PVP._playback_next_frame(callback)
	PVP._playback_wait_for(function()
		return true
	end, callback)
end

-- A waiter belongs to the playback run it was made in: a fresh playback run,
-- or leaving the run for the main menu, drops the rest. Left in, one acts on
-- whatever run shows the blind-select screen next. The driver dispatches the
-- next entry once the event queue is idle, without waiting on a deferred blind
-- handler, so it can run ahead of one: a recorded skip whose tag opens a pack,
-- then the select_blind after it, left the select's waiter polling inside the
-- pack, and after the player left, it selected the next run's Small Blind on
-- its own (e2e/pvp_live/playback_waiters.sh in ClaudeControl).
function PVP._drop_playback_waiters()
	PVP._playback_waiters = {}
end

local go_to_menu_ref = G.FUNCS.go_to_menu
G.FUNCS.go_to_menu = function(e)
	PVP._drop_playback_waiters()
	return go_to_menu_ref(e)
end

local _playback_launch_update_ref = Game.update
function Game:update(dt)
	_playback_launch_update_ref(self, dt)
	local waiters = PVP._playback_waiters
	for i = #waiters, 1, -1 do
		-- A callback that started a fresh run or left this one dropped the rest.
		if waiters ~= PVP._playback_waiters then
			break
		end
		local w = waiters[i]
		if w.predicate() then
			table.remove(waiters, i)
			w.callback()
		end
	end
end
