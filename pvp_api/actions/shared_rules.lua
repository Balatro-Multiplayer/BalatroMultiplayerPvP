local R = PVP.SHARED_RULES
local H = PVP._pvp_action_helpers
for _, key in ipairs({ "pvp_rules_open", "pvp_rules_pick", "pvp_rules_sync" }) do
	-- Consumed by the matching server build, never executed as peer requests.
	H.A(key, function() end)
end
H.A_host("pvp_rules_offer", function(_, _, params)
	if not R.enabled(MPAPI.get_current_lobby()) then return end
	if type(params.id) ~= "string" or type(params.choices) ~= "table" or #params.choices ~= 3 then return end
	for _, key in ipairs(params.choices) do
		if not R.definitions[key] then return end
	end
	R.offer = copy_table(params)
	R.offer.received_at = love.timer.getTime()
	R.show()
end)

function R.request(key, params)
	local lobby = MPAPI.get_current_lobby()
	if lobby then lobby:action(MPAPI.ActionTypes[key]):broadcast(params or {}) end
end

function R.sync()
	if R.enabled(MPAPI.get_current_lobby()) then R.request("pvp_rules_sync") end
end
