-- PvP's part of a Run save (MPAPI.run_save): the match state that lives outside vanilla's
-- save table. PVP.GAME holds the lives, timers, scores and per-ante keys of the match. Only
-- a PvP session has any; in other runs the hook gives nothing.
MPAPI.run_save.register_state(PVP.id, {
	save = function()
		if PVP.in_session() then return PVP.GAME end
		return nil
	end,
})
