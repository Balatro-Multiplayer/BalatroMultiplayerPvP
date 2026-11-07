-- The player-specific seed and exact offer are recorded, since a local replay
-- has no original network player ID. No opponent's draft mutates the POV board.
-- chaos_pick is the persisted replay opcode, not the feature's current name.
MPAPI.playback.register_handler("pvp", "chaos_pick", function(args, ctx)
	if not ctx.is_pov then return end
	PVP._playback_wait_for(function()
		return G.GAME
			and G.GAME.chaos_draft
			and (G.STATE == G.STATES.SHOP or G.STATE == G.STATES.BLIND_SELECT)
			and not G.GAME.chaos_draft.busy
	end, function()
		local D = PVP.ALMANAC_DRAFT
		local state = G.GAME.chaos_draft
		local ante = assert(tonumber(args[2]), "Invalid Almanac draft ante")
		if state.last_ante >= ante then return end
		state.seed, state.seed_pending = args[1], nil
		local choices = {}
		for key in args[4]:gmatch("[^,]+") do
			assert(D.definitions[key] and G.P_CENTERS[key], "Unknown Almanac deck: " .. key)
			choices[#choices + 1] = key
		end
		state.pending = { ante = ante, choices = choices, selected = args[3] }
		if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
		if args[3] == "pass" then
			for _, key in ipairs(choices) do
				assert(not D.can_acquire(key), "Replay passed a legal Almanac offer")
			end
			state.last_ante, state.pending = ante, nil
		else
			assert(D.commit(state, args[3], D.apply))
		end
	end)
end)
