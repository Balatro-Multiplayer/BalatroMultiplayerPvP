-- §22.5: reconnect tail-replay.
--
-- Catch-up bookkeeping after this client's own network reconnect: while
-- disconnected it missed pvp_log_event broadcasts the opponent sent. The server sends the
-- missed events (the lobby match's REPLAY_TAIL, see pvp_api/lobby_bridge.lua) the instant this
-- client rejoins, and this notes them once it's safe to do so. It sets no opponent HUD value:
-- score and hands come only from the server's "pvp.round" (one owner per fact), skips/lives
-- from the opponent's next live sync.
PVP.RECONNECT_TAIL = PVP.RECONNECT_TAIL or {}

-- Pushed tails received so far, keyed by the opponent player id they belong
-- to -- may arrive before or after the lobby's own player_reconnected event,
-- so this just accumulates until on_checkpoint drains whatever's pending.
PVP.RECONNECT_TAIL._received_tails = PVP.RECONNECT_TAIL._received_tails or {}

-- At most one pending catch-up -- a second reconnect before the first drains
-- just replaces it.
local pending_opponent_id = nil

-- The tail writes no enemy fact: the opponent's score and hands are the server's alone
-- (pvp_api/enemy_score_net.lua reads "pvp.round", again on CONNECTED). It only moves the
-- last seen time, so the replay log knows how far it has heard.
local function apply_tail(opponent_id, events)
	local last_t = PVP.RLOG._last_seen_t[opponent_id] or 0
	for _, ev in ipairs(events or {}) do
		if ev.t and ev.t > last_t then last_t = ev.t end
	end
	PVP.RLOG._last_seen_t[opponent_id] = last_t
	if PVP.UI and PVP.UI.juice_up_pvp_hud then pcall(PVP.UI.juice_up_pvp_hud) end
end

-- Called from the lobby's REPLAY_TAIL event (pvp_api/lobby_bridge.lua) the
-- moment the server sends a §22.5 catch-up -- may arrive before or after
-- PLAYER_RECONNECTED, so this only stores; on_checkpoint decides when it's
-- safe to actually apply.
function PVP.RECONNECT_TAIL.receive_pushed_tails(tails)
	for _, tail in ipairs(tails or {}) do
		PVP.RECONNECT_TAIL._received_tails[tail.playerId] = tail.events
	end
end

-- Called from PLAYER_RECONNECTED when THIS client is the one that just
-- reconnected (see pvp_api/lobby_bridge.lua). Never applies inline -- always
-- queues for the next confirmed-safe checkpoint (PVP.RECONNECT_TAIL.on_checkpoint,
-- called from the select_blind/cash_out hooks), since "reconnect just
-- happened" carries no guarantee about what's currently animating on screen.
function PVP.RECONNECT_TAIL.catch_up(opponent_id)
	if not opponent_id then return end
	pending_opponent_id = opponent_id
end

-- Called from the two confirmed-safe checkpoint hooks (select_blind,
-- cash_out -- see ui/game/functions.lua / overrides/game.lua). A third
-- checkpoint ("pack resolved") has no confirmed discrete hook in this repo
-- (base-game Lua, not visible here) -- not added; a mid-pack reconnect simply
-- waits for the next select_blind/cash_out, never applies mid-pack. If the
-- server's push hasn't arrived yet by the time this fires, there's simply
-- nothing to apply this checkpoint -- it's harmless: whatever's missed stays
-- pending in _received_tails until it does arrive (or the next reconnect
-- replaces pending_opponent_id entirely).
-- A session's pushed tails and its pending catch-up end with it.
function PVP.RECONNECT_TAIL.forget()
	pending_opponent_id = nil
	PVP.RECONNECT_TAIL._received_tails = {}
end

function PVP.RECONNECT_TAIL.on_checkpoint()
	if not pending_opponent_id then return end
	local opponent_id = pending_opponent_id
	pending_opponent_id = nil
	local events = PVP.RECONNECT_TAIL._received_tails[opponent_id]
	PVP.RECONNECT_TAIL._received_tails[opponent_id] = nil
	if events then apply_tail(opponent_id, events) end
end
