local A = PVP._pvp_action_helpers.A
local self_id = PVP._pvp_action_helpers.self_id
local host_only = PVP._pvp_action_helpers.host_only
local A_host = PVP._pvp_action_helpers.A_host

-- Score / state resolution (referee). The opponent-facing DISPLAY of
-- score/hands/skips/lives is synced separately via the nemesis blind's
-- calculate/receive (see objects/blinds/nemesis.lua); these handlers now only
-- feed the host-authoritative referee.
A("pvp_play_hand", function(_at, from, params)
	PVP.referee_on_play_hand(from, params or {})
end)

A_host("pvp_round_state", function(_at, from, params)
	PVP.receive_round_state(from, params)
end)

A("pvp_skip", function(_at, from, params)
	PVP.referee_on_skip(from, params or {})
end)

-- §17.11: NOT a plain relay, unlike every sibling in this file -- relay() only
-- guards against the sender's own loopback, so in any N>2 mode EVERY lobby
-- member's location changes would apply here, and enemyLocation's single
-- PVP.GAME.enemy.location* fields would be stomped by whichever broadcast
-- physically lands last (a last-write-wins race, decoupled from who the
-- receiving client's actual current target is). Filtering to
-- PVP.current_target_id() -- the same shared "who is the enemy right now"
-- resolution the score display/HUD/joker targeting already use -- means a
-- stray non-target player's location update is simply ignored, exactly like
-- referee.lua's own guards against off-target senders.
A("pvp_location", function(_at, from, params)
	if from == self_id() then
		return
	end
	if from ~= PVP.current_target_id() then
		return
	end
	PVP.dispatch_action("enemyLocation", params or {})
end)

A("pvp_set_ante", function(_at, from, params)
	PVP.referee_on_set_ante(from, params or {})
end)

-- Nemesis-pairing (rotating no-repeat duels): host -> all, the current ante's full
-- pairing map. Each client picks out its own entry; PVP.current_target_id() reads it.
MPAPI.ActionType({
	key = "pvp_nemesis_pairing",
	prefix_config = { key = false },
	parameters = {
		{ key = "pairing", type = "table", required = true },
		{ key = "ante", type = "number", required = false },
	},
	on_receive = host_only("pvp_nemesis_pairing", function(_at, _from, params)
		local sid = self_id()
		local partner = params.pairing and params.pairing[sid]
		PVP.GAME.nemesis_partner_id = (partner and partner ~= "") and partner or nil
		PVP.GAME.nemesis_pairing_received = true
		if PVP.CURRENT_LOBBY then PVP.mirror_players(PVP.CURRENT_LOBBY) end
		PVP.on_nemesis_pairing(params.ante)
	end),
})

-- Royale live targeting: host -> all, a flat id -> target-id-or-"" map,
-- recomputed on every score update (see PVP.referee_rank_royale/
-- broadcast_royale_targets, pvp_api/referee.lua). Each client picks out its own
-- entry; PVP.current_target_id() reads it. Ids only -- the actual score/hands/
-- lives display comes from the existing raw per-sender relay above, filtered by
-- current_target_id().
MPAPI.ActionType({
	key = "pvp_royale_target",
	prefix_config = { key = false },
	parameters = { { key = "targets", type = "table", required = true } },
	on_receive = host_only("pvp_royale_target", function(_at, _from, params)
		local sid = self_id()
		local target = params.targets and params.targets[sid]
		PVP.GAME.royale_target_id = (target and target ~= "") and target or nil
		if PVP.CURRENT_LOBBY then PVP.mirror_players(PVP.CURRENT_LOBBY) end
	end),
})

A("pvp_set_furthest_blind", function(_at, from, params)
	PVP.referee_on_set_furthest_blind(from, params or {})
end)

A("pvp_new_round", function(_at, from, _params)
	PVP.referee_on_new_round(from)
end)

-- §17.12: the LOCAL consequence of a PvP-timer timeout for the specific
-- player it happened to -- consume one hand (matching the host's own
-- authoritative decrement, PVP.referee_on_fail_pvp_timer, so this player's
-- own NEXT normal hand-play reports the already-correct count back rather
-- than clobbering the host's decrement with a stale higher one), credit the
-- same time bonus a normal hand-play would have earned, and clear the "am I
-- currently being timered" flags so the timer can legitimately restart
-- rather than immediately re-firing. Deliberately does NOT touch
-- PVP.GAME.score/call PVP.ACTIONS.play_hand -- score is untouched by a
-- timeout, and re-reporting it here would risk a lossy round-trip through
-- play_hand's own to_big() conversion (PVP.GAME.score is an INSANE_INT, a
-- different big-number representation).
A_host("pvp_timer_hand_lost", function(_at, _from, params)
	if not params or params.player_id ~= self_id() then
		return
	end
	if G.GAME and G.GAME.current_round then
		G.GAME.current_round.hands_left = math.max(0, (G.GAME.current_round.hands_left or 0) - 1)
	end
	PVP.GAME.timer_consumed = false
	PVP.GAME.timer_started = false
	PVP.GAME.nemesis_timer_started = false
	local increment = PVP.LOBBY.config.pvp_timer_hand_played_increment_seconds
		or PVP.current_ruleset().pvp_timer_hand_played_increment_seconds
		or 0
	PVP.UI.restore_timer(increment)
end)
