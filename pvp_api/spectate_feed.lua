-- §22.3 (Phase 4): live spectate feed adapter. Turns a spectated lobby
-- (MPAPI.replay.spectate_lobby) into a running MPAPI.playback driver whose
-- timeline is fed incrementally from the live match instead of a finished
-- carbon log -- the same driver/registry/handler code Phase 2/3 already
-- built and tested for post-hoc replay, just with a different event source.
--
-- Deliberately NOT built on the normal participant pipeline (lobby actions
-- delivered through MPAPI's dispatch). That pipeline runs EVERY registered
-- ActionType -- the relay-kept pvp_* keys, mpapi_sync,
-- etc. -- all of which assume they're running on a live PARTICIPANT's own
-- client, mutating that client's own G.GAME/PVP.GAME. A spectator has
-- no stake in the match (may not even have an active run at all), so those
-- handlers firing against unrelated/nonexistent local state would corrupt it
-- at best, crash at worst. Instead the server's spectator match
-- (BalatroMultiplayerServer nakama/src/lobby/spectate.ts) forwards only the
-- participants' replay events, already driver-ready.
--
-- A spectator who joins mid-match starts from the real board of the player in view: the server
-- gives that player's latest Run save and the events after it (MPAPI.replay.request_spectate_run).
-- The local run is started from the save (or, with no save yet, from the first event), the later
-- events are fast-forwarded, and the live feed follows. Switching to another player loads that
-- player's run the same way. A save that does not read or load is asked for again as the whole log.
PVP.SPECTATE = PVP.SPECTATE or {}
local S = PVP.SPECTATE
S._driver = nil
-- True while watching. Events that arrive while the local run is still
-- starting wait in _pending.
S._active = false
S._pending = nil
-- Called once, when the first player's board is up (the callback S.start was given).
S._on_ready = nil
-- The player in view, and the player whose run the server has been asked for (nil once it came).
S._pov = nil
S._awaiting = nil
-- Bumped by every request, so an answer or a load that belongs to an earlier one is dropped.
S._generation = 0
S._snapshot = nil

-- Applies the one-time join snapshot (MPAPI.replay.spectate_lobby's {snapshot, ...} answer) as a
-- baseline for the players not in view, through the registered playback handlers
-- (set_ante_key/hand_result). The player in view gets their real board from their own run.
-- Known gap: the snapshot has no `lives` field; live lives changes flow through
-- pvp.lives, a separate state this file doesn't touch.
-- Exposed as a module field (not a local) so a test can call it with a synthetic snapshot.
function S._apply_snapshot(snapshot, pov_player_id)
	for _, entry in ipairs(snapshot) do
		if entry.playerId ~= pov_player_id then
			local ctx = { is_pov = false, player_id = entry.playerId }
			if entry.ante then
				MPAPI.playback.dispatch('pvp', MPAPI.OPCODE.SET_ANTE_KEY, entry.ante, ctx)
			end
			if entry.score or entry.handsRemaining then
				MPAPI.playback.dispatch('pvp', MPAPI.OPCODE.HAND_RESULT, { entry.score, entry.handsRemaining }, ctx)
			end
		end
	end
end

local function snapshot_entry(player_id)
	for _, entry in ipairs(S._snapshot or {}) do
		if entry.playerId == player_id then
			return entry
		end
	end
end

-- The run start a player's board is built from. A player the snapshot has no manifest for starts
-- from the first player's: all players of a match share the seed, deck and ruleset.
local function manifest_of(player_id)
	local entry = snapshot_entry(player_id)
	local first = S._snapshot and S._snapshot[1]
	return (entry and entry.manifest) or (first and first.manifest)
end

-- The driver timeline for a server answer's events: all of them are `player_id`'s.
function S._timeline_of(events, player_id)
	local timeline = {}
	for _, ev in ipairs(events or {}) do
		timeline[#timeline + 1] = { t = ev.t, player_id = player_id, opcode = ev.opcode, args = ev.args }
	end
	return timeline
end

-- Asks the server for `player_id`'s run and drops what was playing. The live events that come
-- before the answer are in the answer already, so they are not kept.
function S._request(player_id, from_start)
	S._generation = S._generation + 1
	S._pov = player_id
	S._awaiting = player_id
	S._pending = nil
	if S._driver then
		S._driver:stop()
		S._driver = nil
	end
	if not MPAPI.replay.request_spectate_run(player_id, from_start) then
		MPAPI.sendWarnMessage('[spectate] could not ask for the run of ' .. tostring(player_id))
	end
end

-- Asks again for the player's whole log, without a Run save, when the save could not be used.
local function fall_back_to_whole_log(player_id, reason)
	MPAPI.sendWarnMessage('[spectate] Run save not used, playing the whole log: ' .. tostring(reason))
	S._request(player_id, true)
end

-- The server's answer: start a local run from the Run save (if any) and play the events after it.
function S._on_run(data)
	if not S._active or data.playerId ~= S._awaiting then
		return
	end
	local player_id = data.playerId
	S._awaiting = nil
	local manifest = manifest_of(player_id)
	if not manifest then
		S.stop()
		return
	end
	local generation = S._generation

	local timeline = S._timeline_of(data.events, player_id)
	local session = { bootstrap = manifest, timeline = timeline, my_id = player_id }
	local opts = {
		mod_id = 'pvp',
		live = true,
		start_run = function(bootstrap, on_ready)
			PVP._start_playback(bootstrap, on_ready)
		end,
	}
	if data.runSave then
		local envelope, err = MPAPI.run_save.decode(data.runSave.data)
		if not envelope then
			fall_back_to_whole_log(player_id, MPAPI.run_save.SKIP.UNREADABLE .. ': ' .. tostring(err))
			return
		end
		opts.run_save = { envelope = envelope, pos = data.runSave.pos, events_follow = true }
		opts.on_load_failed = function(code, detail)
			if generation ~= S._generation or not S._active then
				return
			end
			fall_back_to_whole_log(player_id, code .. ': ' .. tostring(detail))
		end
	end

	S._pending = {}
	MPAPI.playback.restart_session_and_seek(session, #timeline + 1, function(driver)
		if generation ~= S._generation or not S._active then
			driver:stop()
			return
		end
		session.driver = driver
		S._driver = driver
		S._apply_snapshot(S._snapshot or {}, player_id)
		driver:play()
		local pending = S._pending or {}
		S._pending = nil
		for _, entry in ipairs(pending) do
			driver:push_event(entry)
		end
		local on_ready = S._on_ready
		S._on_ready = nil
		if on_ready then
			on_ready(nil)
		end
	end, opts)
end

-- The feed's handlers: entries are already driver-ready.
local feed_handlers = {
	event = function(entry)
		if S._awaiting then
			return
		end
		if S._driver then
			S._driver:push_event(entry)
		elseif S._pending then
			S._pending[#S._pending + 1] = entry
		end
	end,
	run = function(data)
		S._on_run(data)
	end,
	ended = function(reason)
		if S._active then
			S.stop()
			MPAPI.sendWarnMessage('[spectate] stopped: ' .. tostring(reason))
		end
	end,
}

-- Starts spectating `code`. on_ready(err) reports whether the feed connected and the first
-- player's board is up (nil err = success); the driver then plays, and further replay events
-- arrive live. Bootstraps its own seeded local run (see file header), which can take a moment.
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
		S._snapshot = snapshot
		S._on_ready = on_ready
		S._request(snapshot[1].playerId, false)
	end, feed_handlers, PVP.id)
end

-- Shows another player's board. Their run is loaded from their latest Run save, as on joining.
function S.switch_to(player_id)
	if not S._active or (player_id == S._pov and (S._driver or S._awaiting)) then
		return
	end
	S._request(player_id, false)
end

function S.stop()
	if S._active then
		S._active = false
		S._pending = nil
		S._awaiting = nil
		S._on_ready = nil
		S._generation = S._generation + 1
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
