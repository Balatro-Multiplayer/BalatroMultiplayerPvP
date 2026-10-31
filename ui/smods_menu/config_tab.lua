function PVP.UI.create_config_tab()
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
			{
				n = G.UIT.R,
				config = {
					padding = 0,
					align = "cm",
					on_demand_tooltip = {
						text = {
							localize("k_preview_integration_desc"),
							localize("k_preview_credit"),
						},
					},
				},
				nodes = {
					create_toggle({
						id = "fantoms_preview_integration_toggle",
						label = localize("b_preview_integration"),
						ref_table = PVP.config.integrations,
						ref_value = "Preview",
					}),
				},
			},
			{
				n = G.UIT.R,
				config = {
					padding = 0,
					align = "cm",
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = localize("k_preview_credit"),
							shadow = true,
							scale = 0.375,
							colour = G.C.UI.TEXT_INACTIVE,
						},
					},
					{
						n = G.UIT.B,
						config = {
							w = 0.1,
							h = 0.1,
						},
					},
					{
						n = G.UIT.T,
						config = {
							text = localize("k_requires_restart"),
							shadow = true,
							scale = 0.375,
							colour = G.C.UI.TEXT_INACTIVE,
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = {
					padding = 0,
					align = "cm",
					on_demand_tooltip = {
						text = {
							localize("k_applies_singleplayer_vanilla_rulesets"),
						},
					},
				},
				nodes = {
					create_toggle({
						id = "singleplayer_show_content_toggle",
						label = localize("k_show_mp_content_anyway"),
						ref_table = PVP.config,
						ref_value = "show_mp_content_anyway",
					}),
				},
			},
			{
				n = G.UIT.R,
				config = {
					padding = 0,
					align = "cm",
				},
				nodes = {
					create_toggle({
						id = "queue_match_sound_toggle",
						label = localize("k_queue_match_sound"),
						ref_table = PVP.config,
						ref_value = "queue_match_sound",
					}),
				},
			},
			{
				n = G.UIT.R,
				config = {
					padding = 0.1,
					align = "cm",
				},
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm" },
						nodes = {
							create_option_cycle({
								label = localize("k_timer_sfx"),
								w = 4,
								scale = 0.8,
								options = localize("ml_mp_timersfx_opt"),
								opt_callback = "mp_change_timersfx",
								current_option = PVP.config.timersfx or 1,
							}),
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = {
					padding = 0.1,
					align = "cm",
				},
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm" },
						nodes = {
							create_option_cycle({
								label = localize("k_nemesis_layout"),
								w = 4,
								scale = 0.8,
								options = localize("ml_nemesis_layout_opt"),
								opt_callback = "mp_change_nemesis_layout",
								current_option = PVP.nemesis_layout_index(),
							}),
						},
					},
				},
			},
		},
	}
	return ret
end
