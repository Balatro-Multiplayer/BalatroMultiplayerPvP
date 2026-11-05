local A = PVP._pvp_action_helpers.A
local self_id = PVP._pvp_action_helpers.self_id
local A_host = PVP._pvp_action_helpers.A_host

A_host("pvp_timer_state", function(_at, _from, params)
	PVP.TimerSync.receive(params)
end)
A_host("pvp_timer_expired", function(_at, _from, params)
	PVP.TimerSync.receive_expired(params)
end)

local function legacy(from)
	return from == self_id() or (PVP.TimerSync and PVP.TimerSync.ignore_legacy(from))
end

A("pvp_ante_timer", function(_at, from, params)
	if legacy(from) then
		return
	end
	PVP.dispatch_action("startAnteTimer", { time = params.time, isPvP = params.isPvP, fromNemesis = true })
end)

A("pvp_restart_ante_timer", function(_at, from, params)
	if legacy(from) then
		return
	end
	PVP.dispatch_action("restartAnteTimer", { time = params.time, rejoined = params.rejoined })
end)

A("pvp_pause_ante_timer", function(_at, from, params)
	if legacy(from) then
		return
	end
	PVP.dispatch_action("pauseAnteTimer", { time = params.time, fromNemesis = true })
end)
