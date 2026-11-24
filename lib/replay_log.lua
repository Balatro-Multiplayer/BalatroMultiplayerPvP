-- PVP.REPLAY.log: alias to MPAPI's generic replay-log recorder
-- (BalatroMultiplayerAPI/api/replay/recorder.lua, MPAPI.replay).
--
-- The recording/hashing/buffering machinery -- record/begin_run/end_run,
-- the carbon+human dual-stream, card_ref/card_refs -- is mod-agnostic (no
-- PvP-specific knowledge required), so it's owned by MPAPI, the same way
-- MPAPI.playback already owns generic dispatch/timeline for the playback
-- side (api/playback/registry.lua, api/playback/timeline.lua). PVP.REPLAY.log is
-- kept as this alias purely so the many existing PVP.REPLAY.log.record(...) /
-- PVP.REPLAY.log.card_ref(...) call sites throughout this mod (overrides/game.lua,
-- ui/game/timer.lua, compatibility/Preview/CorePreview.lua, etc.) -- the
-- ONLY genuinely PvP-specific part, since only this mod's own game logic
-- knows what a "play"/"buy"/"sell" opcode means -- don't need to change.
--
-- MPAPI fully loads before this mod's core.lua even starts (it's a hard
-- Steamodded dependency, see MultiplayerPvP.json), so MPAPI.replay is
-- guaranteed populated here.
PVP.REPLAY.log = MPAPI.replay

-- PVP.REPLAY.log.is_active() alone only checks "is there ANY active lobby with a
-- code", not which mod's lobby it is -- a second mod (e.g. SPDRN) overriding
-- the SAME vanilla G.FUNCS names (play/discard/buy/sell/etc, since those are
-- ordinary Balatro globals, not PvP-namespaced) would otherwise also fire ITS
-- own recording, and vice versa, while the OTHER mod's match is live, if both
-- are installed at once. Call sites overriding a vanilla function PvP does
-- NOT own exclusively (see overrides/game.lua, ui/game/timer.lua,
-- compatibility/Preview/CorePreview.lua) must gate on this, not bare
-- PVP.REPLAY.log.is_active() -- confirmed live via cctl the first time a second
-- mod's own RLOG recording (SPDRN) was added: a single play_hand produced two
-- "play" events, one from each mod's wrapper, before this fix. Call sites
-- overriding a PvP-owned function/button name (mp_toggle_ready, etc.) don't
-- need this -- they can never fire from another mod's context in the first
-- place.
function PVP.REPLAY.logging()
	return MPAPI.is_active(PVP.id) and PVP.REPLAY.log.is_active()
end
