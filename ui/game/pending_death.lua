-- The dead player's waiting screen while a pending death waits for the opponent
-- (pvp_death_pending), in a match of any size. Leave goes through
-- mp_pvp_leave_from_game, which is not a forfeit: the opponent plays on and the
-- result is decided later.

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
		on_build = PVP.UI.prepare_nemesis_deck,
	})
end

-- Tells the player still in the match that an opponent is out of lives and the
-- match waits on this player beating the same blind.
function PVP.UI.show_pending_death_notice()
	if G.STAGE ~= G.STAGES.RUN or not G.play or PVP.GAME.eliminated then
		return
	end
	attention_text({
		scale = 0.5,
		text = localize("k_pvp_pending_death_survivor"),
		hold = 8,
		align = "cm",
		offset = { x = 0, y = -1.5 },
		major = G.play,
	})
end

-- The pending death is over (the result arrived): drop the screen and unpause so
-- the end screen can show.
function PVP.end_pending_death()
	if PVP.GAME.pending_death_screen then
		PVP.GAME.pending_death_screen = false
		MPAPI._restorable_overlay = nil
		G.FUNCS.exit_overlay_menu()
		G.SETTINGS.paused = false
	end
	PVP.GAME.pending_death = nil
end
