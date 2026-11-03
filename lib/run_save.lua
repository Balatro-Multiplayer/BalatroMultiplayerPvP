-- PvP's part of a Run save (MPAPI.run_save): the match state that lives outside vanilla's
-- save table. PVP.GAME holds the lives, timers, scores and per-ante keys of the match. Only
-- a PvP session has any; in other runs the hook gives nothing.
--
-- next_blind_context is the blind select button (a UI node, with links back into the whole
-- UI tree): it cannot be saved, and the next blind select fills it in again.
MPAPI.run_save.register_state(PVP.id, {
	save = function()
		if not PVP.in_session() then return nil end
		local state = {}
		for key, value in pairs(PVP.GAME) do
			if key ~= "next_blind_context" then state[key] = value end
		end
		return state
	end,
	-- Puts the saved match state over a fresh match, so no key of the live state (or of a player
	-- watched before) survives. The blind button is always cleared.
	load = function(state)
		PVP.reset_game_states()
		for key, value in pairs(state) do
			PVP.GAME[key] = value
		end
		PVP.GAME.next_blind_context = nil
	end,
})
