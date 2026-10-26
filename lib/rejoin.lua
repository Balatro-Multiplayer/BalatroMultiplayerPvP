-- Rejoin (crash-relaunch resume): fast-forwards through the player's own
-- buffered RLOG events for the still-active run via the same bootstrap/
-- driver machinery "My Replays" uses (lib/playback_launch.lua/
-- lib/playback_handlers.lua), then hands off to live play by rejoining the
-- real lobby instead of ending in a "replay finished" toast. Opponent
-- catch-up (whatever they did while this player was disconnected) is NOT
-- triggered manually here -- it already fires automatically once
-- MPAPI.join_lobby reconnects: the lobby match sends the rejoining player a
-- REPLAY_TAIL of what the others did meanwhile, and
-- pvp_api/reconnect_tail.lua already applies it off that same
-- connection-state event chain, unrelated to this file.
--
-- Takes `active` (MPAPI.replay.get_active_run's own response shape --
-- {runId, lobbyCode, modId, events}) rather than fetching by run_id itself:
-- an ACTIVE run has no DB-persisted matchRunLogs row yet (only written at
-- finalize), so MPAPI.replay.get(run_id) 403s "not a participant" for a
-- genuinely active run's own participant -- confirmed live. `events` is
-- already this player's own buffered stream (server-side getTail against
-- the live in-memory buffer), so no second fetch is needed at all.
function PVP._launch_rejoin(active)
	local my_id = MPAPI.get_replay_player_id()

	-- Merges the first match_manifest (schema_version) + first lobby_info
	-- (gamemode/ruleset/sleeve/challenge) + first run_info (seed/deck/stake)
	-- event, same as ui/replay/replay_browser.lua's find_bootstrap -- kept as
	-- an inline loop here since `active.events` isn't a built timeline (no
	-- player_id per entry; it's already this player's own single stream).
	local bootstrap, found = {}, {}
	local timeline = {}
	for _, ev in ipairs(active.events or {}) do
		if not found.match_manifest and ev.opcode == "match_manifest" then
			found.match_manifest = true
			bootstrap.schema_version = ev.args.schema_version
		elseif not found.lobby_info and ev.opcode == "lobby_info" then
			found.lobby_info = true
			bootstrap.gamemode = ev.args.gamemode
			bootstrap.ruleset = ev.args.ruleset
			local options = ev.args.options or {}
			bootstrap.sleeve = options.sleeve
			bootstrap.challenge = options.challenge
			bootstrap.modifier_layers = options.modifier_layers
			bootstrap.multiplayer_jokers = options.multiplayer_jokers
		elseif not found.run_info and ev.opcode == "run_info" then
			found.run_info = true
			bootstrap.seed = ev.args.seed
			bootstrap.deck = ev.args.deck
			bootstrap.stake = ev.args.stake
		end
		timeline[#timeline + 1] = { t = ev.t, player_id = my_id, opcode = ev.opcode, args = ev.args }
	end
	if not (found.lobby_info and found.run_info) then
		MPAPI.sendWarnMessage("[rejoin] no bootstrap data in active run " .. tostring(active.runId))
		return
	end
	if not MPAPI.replay.is_schema_compatible(bootstrap.schema_version) then
		MPAPI.sendWarnMessage(
			"[rejoin] recording schema_version "
				.. tostring(bootstrap.schema_version)
				.. " is newer than this client understands ("
				.. tostring(MPAPI.replay.SCHEMA_VERSION)
				.. "); refusing to rejoin"
		)
		return
	end

	PVP._start_playback(bootstrap, function()
		local driver
		driver = MPAPI.playback.new_driver(timeline, {
			mod_id = "pvp",
			pov_player_id = my_id,
			schema_version = bootstrap.schema_version,
			on_complete = function()
				-- PVP.pvp_join_lobby (not the bare MPAPI.join_lobby primitive):
				-- also runs PVP.setup_lobby_mirror, the same reason
				-- pvp_api/flow.lua's own "Leave Queue & Continue" path re-enters
				-- this function rather than calling MPAPI.join_lobby directly
				-- (see that file's comment) -- needed so PvP's own opponent
				-- mirror/UI wiring is live again, not just the bare lobby
				-- match.
				-- _start_playback ran the fast-forward as a practice session;
				-- left set, the resumed run stays in practice mode and its PvP
				-- blinds never reach the referee, so the round never resolves.
				PVP.SP.practice = false
				PVP.pvp_join_lobby(active.lobbyCode)
				local lobby = MPAPI.get_current_lobby()
				-- Opt out of on_lobby_connected's "match formed while practicing,
				-- exit the run" behavior (api/mod_registry/focus.lua) -- we're
				-- reconnecting to the SAME run we just fast-forwarded, not
				-- discovering a new one; must be set before the async connect
				-- callback fires. Confirmed live: without this, rejoin silently
				-- exited the just-restored run back to the main menu.
				if lobby then lobby._skip_run_exit_on_connect = true end
				-- This relaunched process has no recording block, so nothing the player
				-- did after the rejoin reached their replay log, and it never got its
				-- closing chk (left 'partial'). Resume it from the stream just replayed,
				-- once the last replayed action's own animations have drained (an event
				-- they still emit is already in that stream). Non-blocking, so it never
				-- holds up the queue it waits on.
				local resolver = driver and driver._card_resolvers[my_id]
				G.E_MANAGER:add_event(Event({
					blocking = false,
					blockable = false,
					no_delete = true,
					func = function()
						if not MPAPI.playback._queues_empty() then return false end
						PVP.RLOG.resume_run(active.events, resolver and resolver.by_id)
						return true
					end,
				}))
			end,
		})
		driver:finish()
		driver:play()
	end)
end

MPAPI.playback.register_rejoin(PVP.id, PVP._launch_rejoin)
