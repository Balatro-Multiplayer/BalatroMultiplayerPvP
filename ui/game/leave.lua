-- Leave to the main menu from the end screen (mirrors Speed's spdrn_leave_from_game).
-- The match is already over, so no confirm; lobby:leave() fires the DISCONNECTED handler
-- which tears down the PVP-side lobby state.
--
-- A Pending death screen is not an end screen: the result is still open. Its match log
-- gets its end event here, before the lobby is left, so the server can check the log.
-- The result that arrives after Leave is dropped (it is outside a run) and never logged:
-- the server result is the source of truth.
function G.FUNCS.mp_pvp_leave_from_game()
	if PVP.GAME.pending_death_screen then
		PVP.RLOG.end_run({ result = "pending", lives = 0 })
	end
	G.FUNCS.exit_overlay_menu()
	G.SETTINGS.paused = false
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		lobby:leave()
	end
	G.FUNCS.go_to_menu()
end
