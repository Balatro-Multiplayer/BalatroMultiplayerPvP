local A = PVP._pvp_action_helpers.A
local self_id = PVP._pvp_action_helpers.self_id

A("pvp_ante_timer", function(_at, from, params)
	if from == self_id() then
		return
	end
	PVP.dispatch_action("startAnteTimer", { time = params.time, isPvP = params.isPvP, fromNemesis = true })
end)

A("pvp_restart_ante_timer", function(_at, from, params)
	if from == self_id() then
		return
	end
	PVP.dispatch_action("restartAnteTimer", { time = params.time, resume = params.resume })
end)

A("pvp_pause_ante_timer", function(_at, from, params)
	if from == self_id() then
		return
	end
	PVP.dispatch_action("pauseAnteTimer", { time = params.time, fromNemesis = true })
end)
