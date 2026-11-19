local A = PVP._pvp_action_helpers.A
local A_host = PVP._pvp_action_helpers.A_host

-- Blind handshake (host-authoritative).
A("pvp_ready_blind", function(_at, from, params)
	if params and params.entry then
		PVP.referee_on_entry_sync(from, params.entry)
		return
	end
	PVP.referee_on_ready_blind(from, params and params.starting_hands, params and params.round_protocol)
end)

A("pvp_unready_blind", function(_at, from, params)
	if params and params.entry then
		PVP.referee_on_entry_sync(from, params.entry)
		return
	end
	PVP.referee_on_unready_blind(from)
end)

A("pvp_entry_sync", function(_at, from, params)
	PVP.referee_on_entry_sync(from, params)
end)

-- The host asks everyone who looks ready whether they are ready right now before it
-- starts the blind (see PVP.ReadyCheck). Yes only from the blind-select screen with
-- Ready pressed: a stored Ready can outlive its blind, and a player still inside the
-- previous blind must not be pulled out of it.
A_host("pvp_ready_check", function(_at, _from, params)
	local lobby = MPAPI.get_current_lobby()
	local asked = false
	for _, id in ipairs(params.players or {}) do
		asked = asked or (lobby and id == lobby.player_id)
	end
	if not asked then return end
	local ready = PVP.GAME.ready_blind == true and not PVP.GAME.eliminated and G.STATE == G.STATES.BLIND_SELECT
	local expected = params.entries and params.entries[lobby.player_id]
	if expected then ready = ready and PVP.same_choice_version(PVP.current_readiness_choice(), expected) end
	lobby
		:action(MPAPI.ActionTypes["pvp_ready_ack"])
		:broadcast({ nonce = params.nonce, ready = ready and true or false })
end)

A("pvp_ready_ack", function(_at, from, params)
	PVP.referee_on_ready_ack(from, params and params.nonce, params and params.ready)
end)

A_host("pvp_start_blind", function(_at, from, params)
	PVP.accept_round_start(params, from)
end)
