local A = PVP._pvp_action_helpers.A

A("pvp_player_ready", function(_at, from, params)
	PVP.match_log(
		"debug",
		"[pvp] RECV pvp_player_ready from=" .. tostring(from) .. " ready=" .. tostring(params and params.ready)
	)
	-- Feeds MPAPI core's shared ready-status badge (every client, not just host).
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		MPAPI.set_player_ready(lobby, from, params and params.ready)
	end
	-- Every client tallies (own arrives via loopback); the host gates Start on it.
	PVP.set_player_ready(from, params and params.ready)
end)
