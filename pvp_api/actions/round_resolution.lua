local A = PVP._pvp_action_helpers.A

-- Round / match resolution (host-authoritative inputs).
A("pvp_fail_round", function(_at, from, _params)
	PVP.referee_on_fail_round(from)
end)

A("pvp_fail_timer", function(_at, from, _params)
	PVP.referee_on_fail_timer(from)
end)

-- A client's own result for a non-PvP blind: { ante, blind, beaten }.
A("pvp_blind_result", function(_at, from, params)
	PVP.referee_on_blind_result(from, params or {})
end)

A("pvp_fail_pvp_timer", function(_at, from, _params)
	PVP.referee_on_fail_pvp_timer(from)
end)
