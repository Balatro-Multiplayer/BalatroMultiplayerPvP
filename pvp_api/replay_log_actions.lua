-- This mod's live transport for PVP.RLOG (an alias to MPAPI.replay, the
-- generic recorder in BalatroMultiplayerAPI/api/replay/recorder.lua -- see
-- lib/replay_log.lua).
--
-- One event per broadcast, not batched: this is deliberately per-line, not
-- per-25-lines/2-seconds like the old stream, so a spectator (once built) is
-- literally watching each log line arrive as it happens, not a periodic
-- catch-up dump. `args` carries either the positional action-args table (an
-- array, mirrors the local carbon line's own tokens) or, for the reserved
-- framing opcodes "manifest"/"end"/"chk", the frame's own dict payload --
-- MPAPI's action-param validation only checks `type(value) == "table"`, so
-- both shapes satisfy the same schema without a second ActionType.
--
-- on_receive tracks the opponent's own elapsed-t high-water mark (Phase 9:
-- reconnect tail-replay) -- PVP.RLOG._last_seen_t[player_id] is how far into
-- that player's own RLOG stream this client has observed live, so a
-- reconnecting client knows what `since_t` to request via
-- MPAPI.replay.get_tail after missing some broadcasts while disconnected.
-- Keyed by the SENDER's own clock (params.t, elapsed since THEIR begin_run),
-- not local wall-clock time, so it stays meaningful regardless of when this
-- client itself connected/reconnected. Broadcasts loop back to the sender
-- (see pvp_api/actions.lua's self_id() convention), so a client's own events
-- are skipped -- there's nothing to "catch up" on for your own stream. The
-- server-side buffering client and, later, spectators are the other
-- consumers of this same broadcast; this is purely an additional local
-- bookkeeping side effect, not a second dispatch path.
PVP.RLOG._last_seen_t = PVP.RLOG._last_seen_t or {}

local function self_id()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.player_id
end

PVP.RLOG_EVENT_ACTION = MPAPI.ActionType({
	key = "pvp_log_event",
	prefix_config = { key = false },
	parameters = {
		{ key = "t", type = "number", required = true },
		{ key = "opcode", type = "string", required = true },
		{ key = "args", type = "table", required = false },
	},
	on_receive = function(_at, from, params)
		if from == self_id() then return end
		local prev = PVP.RLOG._last_seen_t[from] or 0
		if params.t and params.t > prev then PVP.RLOG._last_seen_t[from] = params.t end
	end,
})

-- Normalizes PVP.RLOG.record's flexible args shape (nil | scalar | array/dict
-- table) into what pvp_log_event's `args` param actually needs: nil (omitted
-- entirely, since it's optional) or a table. A bare scalar (e.g. pack_skip's
-- literal `0`) gets wrapped as a single-element array so it still round-trips.
local function normalize_args(args)
	if args == nil then return nil end
	if type(args) == "table" then return args end
	return { args }
end

-- Broadcasts one event live. No-ops cleanly with no lobby (e.g. practice mode,
-- or the headless test harness) -- the local carbon/human text lines this
-- pairs with (lib/replay_log.lua) are unaffected either way.
--
-- Registered by mod id (MPAPI.replay.register_broadcaster), not assigned
-- directly to MPAPI.replay.broadcast_event: that's a single shared singleton
-- across every consuming mod, so a second consumer (e.g. SPDRN) loading its
-- own transport wiring would otherwise silently clobber this one (or vice
-- versa, depending on load order) for every game afterward, regardless of
-- which mod's lobby was actually live.
MPAPI.replay.register_broadcaster(PVP.id, function(t, opcode, args)
	local lobby = MPAPI.get_current_lobby()
	if not lobby then return end
	lobby:action(PVP.RLOG_EVENT_ACTION):broadcast({ t = t, opcode = opcode, args = normalize_args(args) })
end)
