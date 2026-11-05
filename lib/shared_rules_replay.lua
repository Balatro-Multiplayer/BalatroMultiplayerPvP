MPAPI.playback.register_handler("pvp", "shared_rules", function(args, ctx)
	if not ctx.is_pov then return end
	PVP._playback_wait_for(function()
		return G.GAME and G.STATE == G.STATES.BLIND_SELECT
	end, function()
		PVP.SHARED_RULES.prepare({ id = args[1], ante = tonumber(args[2]), rules = { args[3], args[4] } })
	end)
end)
