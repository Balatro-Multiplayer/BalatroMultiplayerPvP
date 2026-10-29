-- The dead player's waiting screen while a pending death waits for the opponent
-- (pvp_death_pending). Leave goes through mp_pvp_leave_from_game, which is not a
-- forfeit: the opponent plays on and the result is decided later.

local function text_row(key, scale, colour)
	return PVP.UI.UTILS.create_row({ align = "cm", padding = 0.08 }, {
		PVP.UI.UTILS.create_text_node(localize(key), { scale = scale, colour = colour or G.C.UI.TEXT_LIGHT }),
	})
end

function G.UIDEF.pending_death_waiting()
	return {
		n = G.UIT.ROOT,
		config = { align = "cm", colour = G.C.CLEAR, minw = 8 },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", padding = 0.3, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK },
				nodes = {
					text_row("k_pvp_pending_death_title", 0.8, G.C.RED),
					text_row("k_pvp_pending_death_result", 0.5),
					text_row("k_pvp_pending_death_wait", 0.4),
					text_row("k_pvp_pending_death_leave", 0.4),
					UIBox_button({
						button = "mp_pvp_leave_from_game",
						label = { localize("b_leave") },
						minw = 5,
						colour = G.C.RED,
					}),
				},
			},
		},
	}
end

function PVP.UI.show_pending_death_screen()
	if G.STAGE ~= G.STAGES.RUN then
		return
	end
	G.SETTINGS.paused = true
	G.FUNCS.overlay_menu({ definition = G.UIDEF.pending_death_waiting() })
	PVP.GAME.pending_death_screen = true
end

-- The pending death is over (the result arrived): drop the screen and unpause so
-- the end screen can show.
function PVP.end_pending_death()
	if PVP.GAME.pending_death_screen then
		PVP.GAME.pending_death_screen = false
		G.FUNCS.exit_overlay_menu()
		G.SETTINGS.paused = false
	end
	PVP.GAME.pending_death = nil
end
