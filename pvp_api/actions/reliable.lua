local A = PVP._pvp_action_helpers.A

A("pvp_reliable_event", function(_at, from, envelope)
	PVP.receive_reliable_event(from, envelope)
end)
A("pvp_reliable_ack", function(_at, from, envelope)
	PVP.receive_reliable_ack(from, envelope)
end)
A("pvp_reliable_output", function(_at, from, envelope)
	PVP.receive_reliable_output(from, envelope)
end)
A("pvp_reliable_output_ack", function(_at, from, envelope)
	PVP.receive_reliable_output_ack(from, envelope)
end)
