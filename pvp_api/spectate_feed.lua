-- §22.3 (Phase 4): live spectate feed adapter. Turns a spectated lobby
-- (MPAPI.replay.spectate_lobby) into a running MPAPI.playback driver whose
-- timeline is fed incrementally from the live match instead of a finished
-- carbon log -- the same driver/registry/handler code Phase 2/3 already
-- built and tested for post-hoc replay, just with a different event source.
--
-- Deliberately NOT built on the normal participant pipeline (lobby actions
-- delivered through MPAPI's dispatch). That pipeline runs EVERY registered
-- ActionType -- pvp_play_hand, pvp_skip, mpapi_sync, mpapi_opponent_context,
-- etc. -- all of which assume they're running on a live PARTICIPANT's own
-- client, mutating that client's own G.GAME/PVP.GAME/PVP.REF. A spectator has
-- no stake in the match (may not even have an active run at all), so those
-- handlers firing against unrelated/nonexistent local state would corrupt it
-- at best, crash at worst. Instead the server's spectator match
-- (BalatroMultiplayerServer nakama/src/lobby/spectate.ts) forwards only the
-- participants' replay events, already driver-ready.
--
-- §22.3 full-fidelity update: S.start bootstraps its own seeded local run via
-- PVP._start_playback (lib/playback_launch.lua), using the manifest the
-- server's snapshot carries -- the same seed/deck/stake/ruleset a post-hoc
-- replay uses, so a spectator sees the real, deterministic cards too, not
-- just score/ante text. Known gap, not solved here: this only gives full
-- fidelity for a spectator who joins from the very start of a match -- one
-- joining mid-match has no way to replay the ALREADY-MISSED actions (only the
-- aggregated latest ante/score the snapshot carries), so their local run
-- starts at ante 1/blind-select while the live feed's next real event may be
-- from a much later point -- the display baseline (_apply_snapshot) still
-- shows the right ballpark score/ante, but the actual cards on screen won't
-- reflect a mid-match join. Same class of gap as the already-flagged missing
-- `lives` field.
PVP.SPECTATE = PVP.SPECTATE or {}
local S = PVP.SPECTATE
S._driver = nil
-- True while watching. Events that arrive while the local run is still
-- starting wait in _pending.
S._active = false
S._pending = nil

-- Applies the one-time join snapshot (MPAPI.replay.spectate_lobby's
-- {snapshot, ...} answer) as a baseline, through the SAME registered
-- handlers Phase 3 already tests (set_ante_key/hand_result) rather than
-- duplicating their projection logic here. The first player id in the
-- snapshot is picked as the nominal POV (drives PVP.GAME, the "own board"
-- side) -- a spectator has no real self in the match, this is a display
-- choice, not an identity claim. Known gap (flagged in the approved plan,
-- not solved here): the snapshot has no `lives` field, since the server's
-- getSpectatorSnapshot only derives ante/score/handsRemaining from buffered
-- carbon events -- live lives changes flow through pvp_player_lives, a
-- separate broadcast this file doesn't touch yet.
-- Exposed as a module field (not a local), same reasoning as
-- MPAPI.playback._queues_empty -- so a test can call it directly with a
-- synthetic snapshot, without needing a real spectate_lobby round trip.
function S._apply_snapshot(snapshot)
	local pov_player_id = snapshot[1] and snapshot[1].playerId
	for _, entry in ipairs(snapshot) do
		local ctx = { is_pov = entry.playerId == pov_player_id, player_id = entry.playerId }
		if entry.ante then
			MPAPI.playback.dispatch('pvp', MPAPI.OPCODE.SET_ANTE_KEY, entry.ante, ctx)
		end
		if entry.score or entry.handsRemaining then
			MPAPI.playback.dispatch('pvp', MPAPI.OPCODE.HAND_RESULT, { entry.score, entry.handsRemaining }, ctx)
		end
	end
	return pov_player_id
end

-- The feed's handlers: entries are already driver-ready.
local feed_handlers = {
	event = function(entry)
		if S._driver then
			S._driver:push_event(entry)
		elseif S._pending then
			S._pending[#S._pending + 1] = entry
		end
	end,
	ended = function(reason)
		if S._active then
			S.stop()
			MPAPI.sendWarnMessage('[spectate] stopped: ' .. tostring(reason))
		end
	end,
}

-- Starts spectating `code`. on_ready(err) reports whether the feed connected
-- (nil err = success); once it does, the driver is playing and PVP.GAME/
-- enemy already reflect the join-time snapshot, updating live as further
-- replay events arrive. Bootstraps its own seeded local run first (see file
-- header) -- this can take a moment (a real run start).
function S.start(code, on_ready)
	MPAPI.replay.spectate_lobby(code, function(err, data)
		if err or not data then
			if on_ready then
				on_ready((err and err.message) or 'spectate_lobby failed')
			end
			return
		end

		local snapshot = data.snapshot or {}
		local manifest = snapshot[1] and snapshot[1].manifest
		if not manifest then
			MPAPI.replay.stop_spectating()
			if on_ready then
				on_ready('spectate: no manifest available yet for this lobby (no buffered run)')
			end
			return
		end

		S._active = true
		S._pending = {}

		PVP._start_playback(manifest, function()
			local pov_player_id = S._apply_snapshot(snapshot)
			S._driver = MPAPI.playback.new_driver({}, { mod_id = 'pvp', pov_player_id = pov_player_id })
			S._driver:play()

			local pending = S._pending or {}
			S._pending = nil
			for _, entry in ipairs(pending) do
				S._driver:push_event(entry)
			end
			if on_ready then
				on_ready(nil)
			end
		end)
	end, feed_handlers, PVP.id)
end

function S.stop()
	if S._active then
		S._active = false
		S._pending = nil
		MPAPI.replay.stop_spectating()
	end
	if S._driver then
		S._driver:stop()
		S._driver = nil
	end
end

function S.is_active()
	return S._active
end
