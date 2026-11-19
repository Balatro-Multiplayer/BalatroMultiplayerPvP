-- Leave to the main menu from the end screen (mirrors Speed's spdrn_leave_from_game).
-- The match is already over, so no confirm; lobby:leave() fires the DISCONNECTED handler
-- which tears down the PVP-side lobby state.
--
-- The match log is ended by lobby:leave() (MPAPI), for this and every other leave path.
function G.FUNCS.mp_pvp_leave_from_game()
	G.FUNCS.exit_overlay_menu()
	G.SETTINGS.paused = false
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		lobby:leave()
	end
	G.FUNCS.go_to_menu()
end
