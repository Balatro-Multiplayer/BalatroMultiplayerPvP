local A = PVP._pvp_action_helpers.A
local A_host = PVP._pvp_action_helpers.A_host

-- Blind handshake (host-authoritative).
A("pvp_ready_blind", function(_at, from, params)
	PVP.referee_on_ready_blind(from, params and params.starting_hands, params and params.round_protocol)
end)

A("pvp_unready_blind", function(_at, from, _params)
	PVP.referee_on_unready_blind(from)
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
