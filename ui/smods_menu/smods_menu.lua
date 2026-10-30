PVP.credits_tab = PVP.UI.create_credits_tab

PVP.config_tab = PVP.UI.create_config_tab

PVP.extra_tabs = PVP.UI.create_extra_tabs

function G.FUNCS.bmp_discord(e)
	love.system.openURL("https://discord.gg/gEemz4ptuF")
end

function G.FUNCS.bmp_github(e)
	love.system.openURL("https://github.com/Balatro-Multiplayer/BalatroMultiplayer/")
end

function G.FUNCS.change_blind_col(args) -- all we're doing is just saving + redefining the ui elements here
	PVP.UTILS.save_blind_col(args.to_val)
	PVP.LOBBY.blind_col = args.to_val
	local sprite = G.OVERLAY_MENU:get_UIE_by_ID("blind_col_changer_sprite")
	sprite.config.object:remove()
	sprite.config.object = AnimatedSprite(
		0,
		0,
		1.4,
		1.4,
		G.ANIMATION_ATLAS["mp_player_blind_col"],
		G.P_BLINDS[PVP.UTILS.blind_col_numtokey(PVP.LOBBY.blind_col)].pos
	)
	sprite.config.object:define_draw_steps({
		{ shader = "dissolve", shadow_height = 0.05 },
		{ shader = "dissolve" },
	})
	sprite.UIBox:recalculate()
	local option = G.OVERLAY_MENU:get_UIE_by_ID("blind_col_changer_option")
	option.children[1].children[1].config.text =
		localize({ type = "name_text", key = PVP.UTILS.blind_col_numtokey(PVP.LOBBY.blind_col), set = "Blind" })
	option.UIBox:recalculate()
end

function G.FUNCS.mp_change_timersfx(args)
	PVP.config.timersfx = args.to_key
	SMODS.save_mod_config(PVP) -- probably unnecessary?
end

-- A change applies at once: the Nemesis rows are only moved, so it is safe mid-run.
function G.FUNCS.mp_change_nemesis_layout(args)
	PVP.config.nemesis_layout = PVP.NEMESIS_LAYOUT_ORDER[args.to_key]
	SMODS.save_mod_config(PVP)
	if G.jokers and G.consumeables then PVP.place_nemesis_slots() end
end
