-- The dead player's waiting screen while the view's run.waitingDeaths lists me (pvp_api/ui/pending_death.lua
-- opens and closes it). Leave goes through mp_pvp_leave_from_game, which is not a forfeit: the opponent plays
-- on and the result is decided later.

-- Shown as the PvP end screen (the same one an eliminated player gets) with the
-- pending wording and a Leave button only; game_end.lua reads
-- PVP.GAME.pending_death_screen for the title, text and buttons.
function PVP.UI.show_pending_death_screen()
	if G.STAGE ~= G.STAGES.RUN then
		return
	end
	PVP.GAME.pending_death_screen = true
	MPAPI.end_screen_show({
		won = false,
		title_key = "k_pvp_pending_death_title",
		no_esc = true,
		body = PVP.UI.end_game_body,
	})
end

-- Tells a player still in the match that a pending death waits on them beating the same blind; the
-- wording is the localization key the reader picked.
function PVP.UI.show_pending_death_notice(text_key)
	if G.STAGE ~= G.STAGES.RUN or not G.play then
		return
	end
	attention_text({
		scale = 0.5,
		text = localize(text_key),
		hold = 8,
		align = "cm",
		offset = { x = 0, y = -1.5 },
		major = G.play,
	})
end

-- The pending death is over (the view no longer lists it, or the result arrived): drop the screen and
-- unpause so the end screen can show.
PVP.UI.pending_death = PVP.UI.pending_death or {}
function PVP.UI.pending_death.close()
	if PVP.GAME.pending_death_screen then
		PVP.GAME.pending_death_screen = false
		MPAPI._restorable_overlay = nil
		G.FUNCS.exit_overlay_menu()
		G.SETTINGS.paused = false
	end
	PVP.GAME.pending_death = nil
end
