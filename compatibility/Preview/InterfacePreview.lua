-- The user interface components that display simulation results.

-- Append node for preview text to the HUD:
local orig_hud = create_UIBox_HUD
function create_UIBox_HUD()
	local contents = orig_hud()

	if not FN.PRE.in_play() then return contents end

	-- Check if preview is disabled in lobby options
	if PVP.LOBBY.config and PVP.LOBBY.config.preview_disabled then return contents end

	local score_node_wrap =
		{ n = G.UIT.R, config = { id = "fn_pre_score_wrap", align = "cm", padding = 0.1 }, nodes = {} }
	table.insert(score_node_wrap.nodes, FN.PRE.get_score_node())
	local calculate_score_button_wrap =
		{ n = G.UIT.R, config = { id = "fn_calculate_score_button_wrap", align = "cm", padding = 0.1 }, nodes = {} }
	table.insert(calculate_score_button_wrap.nodes, FN.PRE.get_calculate_score_button())
	local score_wrap = {
		n = G.UIT.R,
		config = { id = "fn_real_wrap", align = "cm", padding = 0.0 },
		nodes = { score_node_wrap, calculate_score_button_wrap },
	}

	table.insert(contents.nodes[1].nodes[1].nodes[4].nodes[1].nodes, score_wrap) -- you can only do one so we have to wrap both of them. do not ask. i have no idea why

	return contents
end

function G.FUNCS.calculate_score_button()
	FN.PRE.money_mode = false
	FN.PRE.start_new_coroutine()
end

function G.FUNCS.calculate_money_button()
	FN.PRE.money_mode = true
	FN.PRE.start_new_coroutine()
end

local function calculate_button(id, text, colour)
	return {
		n = G.UIT.C,
		config = {
			id = id,
			button = id,
			align = "cm",
			minh = 0.5,
			minw = 2,
			maxw = 2,
			padding = 0.05,
			r = 0.1,
			colour = colour,
			hover = true,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = { text = text, colour = G.C.UI.TEXT_LIGHT, shadow = true, scale = 0.36 },
			},
		},
	}
end

-- Two buttons sized like the chips/mult boxes above
function FN.PRE.get_calculate_score_button()
	return {
		n = G.UIT.C,
		config = { align = "cm" },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.1 },
				nodes = {
					calculate_button("calculate_score_button", PVP.UTILS.get_preview_cfg("button"), G.C.RED),
					calculate_button("calculate_money_button", "Calc Money", G.C.MONEY),
				},
			},
		},
	}
end

function FN.PRE.get_score_node()
	local text_scale = nil
	if true then
		text_scale = 0.5
	else
		text_scale = 0.75
	end

	return {
		n = G.UIT.C,
		config = { id = "fn_pre_score", align = "cm", minh = 0.5 },
		nodes = {
			{
				n = G.UIT.O,
				config = {
					id = "fn_pre_l",
					func = "fn_pre_score_UI_set",
					object = DynaText({
						string = { { ref_table = FN.PRE.text.score, ref_value = "l" } },
						colours = { G.C.UI.TEXT_LIGHT },
						shadow = true,
						float = true,
						scale = text_scale,
                        maxw = 2,
					}),
				},
			},
			{
				n = G.UIT.O,
				config = {
					id = "fn_pre_m",
					func = "fn_pre_score_UI_set",
					object = DynaText({
						string = { { ref_table = FN.PRE.text.score, ref_value = "m" } },
						colours = { G.C.UI.TEXT_LIGHT },
						shadow = true,
						float = true,
						scale = text_scale,
                        maxw = 4,
					}),
				},
			},
			{
				n = G.UIT.O,
				config = {
					id = "fn_pre_r",
					func = "fn_pre_score_UI_set",
					object = DynaText({
						string = { { ref_table = FN.PRE.text.score, ref_value = "r" } },
						colours = { G.C.UI.TEXT_LIGHT },
						shadow = true,
						float = true,
						scale = text_scale,
                        maxw = 2,
					}),
				},
			},
		},
	}
end

-- TODO Implement
function FN.get_preview_settings_page()
	local function preview_score_toggle_callback(e)
		if not G.HUD then return end

		if G.SETTINGS.FN.preview_score then
			-- Preview was just enabled, so add preview node:
			G.HUD:add_child(FN.PRE.get_score_node(), G.HUD:get_UIE_by_ID("fn_pre_score_wrap"))
			FN.PRE.data = FN.PRE.simulate()
		else
			-- Preview was just disabled, so remove preview node:
			G.HUD:get_UIE_by_ID("fn_pre_score").parent:remove()
		end
		G.HUD:recalculate()
	end

	local function preview_dollars_toggle_callback(_)
		if not G.HUD then return end

		if G.SETTINGS.FN.preview_dollars then
			-- Preview was just enabled, so add preview node:
			G.HUD:add_child(FN.PRE.get_dollars_node(), G.HUD:get_UIE_by_ID("fn_pre_dollars_wrap"))
			FN.PRE.data = FN.PRE.simulate()
		else
			-- Preview was just disabled, so remove preview node:
			G.HUD:get_UIE_by_ID("fn_pre_dollars").parent:remove()
		end
		G.HUD:recalculate()
	end

	local function face_down_toggle_callback(_)
		if not G.HUD then return end

		FN.PRE.data = FN.PRE.simulate()
		G.HUD:recalculate()
	end

	return {
		n = G.UIT.ROOT,
		config = { align = "cm", padding = 0.05, colour = G.C.CLEAR },
		nodes = {
			create_toggle({
				id = "score_toggle",
				label = "Enable Score Preview",
				ref_table = G.SETTINGS.FN,
				ref_value = "preview_score",
				callback = preview_score_toggle_callback,
			}),
			create_toggle({
				id = "dollars_toggle",
				label = "Enable Money Preview",
				ref_table = G.SETTINGS.FN,
				ref_value = "preview_dollars",
				callback = preview_dollars_toggle_callback,
			}),
			create_toggle({
				label = "Hide Preview if Any Card is Face-Down",
				ref_table = G.SETTINGS.FN,
				ref_value = "hide_face_down",
				callback = face_down_toggle_callback,
			}),
		},
	}
end
