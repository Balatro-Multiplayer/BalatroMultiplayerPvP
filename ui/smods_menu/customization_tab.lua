function PVP.UI.create_customization_tab()
	local blind_anim = AnimatedSprite(
		0,
		0,
		1.4,
		1.4,
		G.ANIMATION_ATLAS["mp_player_blind_col"],
		G.P_BLINDS[PVP.UTILS.blind_col_numtokey(PVP.LOBBY.blind_col)].pos
	)
	blind_anim:define_draw_steps({
		{ shader = "dissolve", shadow_height = 0.05 },
		{ shader = "dissolve" },
	})
	PVP.PREVIEW.text = PVP.config.preview.text or ""
	PVP.PREVIEW.button = PVP.config.preview.button or ""
	local ret = {
		n = G.UIT.ROOT,
		config = {
			r = 0.1,
			minw = 5,
			align = "cm",
			padding = 0.2,
			colour = G.C.BLACK,
		},
		nodes = {
			PVP.INTEGRATIONS.Preview and {
				n = G.UIT.R,
				config = {
					padding = 0.10,
					align = "cm",
					id = "preview_text_input",
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							scale = 0.5,
							text = localize("k_customize_preview"),
							colour = G.C.UI.TEXT_LIGHT,
						},
					},
				},
			} or nil,
			PVP.INTEGRATIONS.Preview and {
				n = G.UIT.R,
				config = {
					padding = 0,
					align = "cm",
					id = "preview_text_input",
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							scale = 0.3,
							text = localize("k_enter_to_save"),
							colour = G.C.UI.TEXT_LIGHT,
						},
					},
				},
			} or nil,
			PVP.INTEGRATIONS.Preview
					and {
						n = G.UIT.R,
						config = {
							padding = 0.15,
							align = "cm",
							id = "preview_text_input",
						},
						nodes = {
							create_text_input({
								id = "preview_text",
								w = 4,
								max_length = 25,
								prompt_text = "CALCULATING", -- raw string but this doesn't need localization
								colour = copy_table(G.C.BLACK),
								hooked_colour = darken(copy_table(G.C.BLACK), 0.3),
								ref_table = PVP.PREVIEW,
								ref_value = "text",
								extended_corpus = true,
								keyboard_offset = -3,
								callback = function(val)
									PVP.UTILS.save_preview(PVP.PREVIEW)
								end,
							}),
							create_text_input({
								id = "preview_button",
								w = 4,
								max_length = 25,
								prompt_text = "Calculate Score",
								colour = copy_table(G.C.RED),
								hooked_colour = darken(copy_table(G.C.RED), 0.3),
								ref_table = PVP.PREVIEW,
								ref_value = "button",
								extended_corpus = true,
								keyboard_offset = -3,
								callback = function(val)
									PVP.UTILS.save_preview(PVP.PREVIEW)
								end,
							}),
						},
					}
				or nil,
			{
				n = G.UIT.R,
				config = {
					padding = 0.5,
					align = "cm",
					id = "username_input_box",
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							scale = 0.6,
							text = localize("k_username"),
							colour = G.C.UI.TEXT_LIGHT,
						},
					},
					create_text_input({
						id = "enter_username",
						w = 4,
						max_length = 25,
						prompt_text = localize("k_enter_username"),
						ref_table = PVP.LOBBY,
						ref_value = "username",
						extended_corpus = true,
						keyboard_offset = -3,
						callback = function(val)
							PVP.UTILS.save_username(PVP.LOBBY.username)
						end,
					}),
					{
						n = G.UIT.T,
						config = {
							scale = 0.3,
							text = localize("k_enter_to_save"),
							colour = G.C.UI.TEXT_LIGHT,
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = {
					padding = 0.1,
					align = "cm",
					id = "blind_col_changer",
				},
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm" },
						nodes = {
							{ n = G.UIT.O, config = { id = "blind_col_changer_sprite", object = blind_anim } },
						},
					},
					{
						n = G.UIT.C,
						config = { align = "cm" },
						nodes = {
							create_option_cycle({
								id = "blind_col_changer_option",
								label = localize({
									type = "name_text",
									key = PVP.UTILS.blind_col_numtokey(PVP.LOBBY.blind_col),
									set = "Blind",
								}),
								scale = 0.8,
								options = {
									1,
									2,
									3,
									4,
									5,
									6,
									7,
									8,
									9,
									10,
									11,
									12,
									13,
									14,
									15,
									16,
									17,
									18,
									19,
									20,
									21,
									22,
									23,
									24,
									25,
								}, -- blind_cols are being saved as numbers because of this option cycle. if this is changed then we should probably change to keys
								opt_callback = "change_blind_col",
								current_option = PVP.LOBBY.blind_col,
							}),
						},
					},
				},
			},
		},
	}
	return ret
end

function PVP.UI.create_extra_tabs()
	return {
		{
			label = localize("k_customization"),
			tab_definition_function = PVP.UI.create_customization_tab,
		},
	}
end
