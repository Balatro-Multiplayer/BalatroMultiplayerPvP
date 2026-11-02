local A = PVP._pvp_action_helpers.A
local A_host = PVP._pvp_action_helpers.A_host

-- Blind handshake (host-authoritative).
A("pvp_ready_blind", function(_at, from, params)
	PVP.referee_on_ready_blind(from, params and params.starting_hands, params and params.round_protocol)
end)

A("pvp_unready_blind", function(_at, from, _params)
	PVP.referee_on_unready_blind(from)
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
	if not asked then
		return
	end
	local ready = PVP.GAME.ready_blind == true and not PVP.GAME.eliminated and G.STATE == G.STATES.BLIND_SELECT
	lobby:action(MPAPI.ActionTypes["pvp_ready_ack"]):broadcast({ nonce = params.nonce, ready = ready and true or false })
end)

A("pvp_ready_ack", function(_at, from, params)
	PVP.referee_on_ready_ack(from, params and params.nonce, params and params.ready)
end)

A_host("pvp_start_blind", function(_at, _from, params)
	local lobby = MPAPI.get_current_lobby()
	-- An eliminated player sits out the blinds the others still play.
	if not lobby or PVP.GAME.eliminated then
		return
	end
	if PVP.begin_round_sync(params.round_id, _from) == false then return end
	-- action_start_blind compares firstPlayer to (is_host and "host" or "guest");
	-- translate the authoritative first-player id into this client's frame.
	local me = lobby.is_host and "host" or "guest"
	local other = lobby.is_host and "guest" or "host"
	local fp = (params.first_player == lobby.player_id) and me or other
	local target_id = PVP.current_target_id()
	local starting_hands = target_id and params.starting_hands and params.starting_hands[target_id]
	PVP.dispatch_action("startBlind", { firstPlayer = fp, startingHands = starting_hands })
end)
