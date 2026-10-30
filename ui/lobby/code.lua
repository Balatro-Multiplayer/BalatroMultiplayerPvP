G.FUNCS.mp_pvp_view_code = function(e)
	local text_config = e.children[1].children[1].config
	local code = PVP.lobby.ref and PVP.lobby.ref.code
	if not code then
		return
	end
	if text_config.text ~= code then
		e.config.colour = G.C.ETERNAL
		text_config.text = code
	else
		e.config.colour = G.C.GREEN
		text_config.text = localize("b_view_code_cap")
	end
	e.UIBox:recalculate()
end

G.FUNCS.mp_pvp_copy_code = function(e)
	local code = PVP.lobby.ref and PVP.lobby.ref.code
	if not code then
		return
	end
	if love.system and love.system.setClipboardText then
		love.system.setClipboardText(code)
	end
	local text_config = e.children[1].children[1].config
	e.config.colour = G.C.ETERNAL
	text_config.text = localize("k_copied_cap")
	e.UIBox:recalculate()
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 1.5,
		func = function()
			e.config.colour = G.C.PURPLE
			text_config.text = localize("b_copy_code_cap")
			e.UIBox:recalculate()
			return true
		end,
	}))
end

G.FUNCS.mp_pvp_start_game = function()
	PVP.pvp_start_match()
end

G.FUNCS.mp_pvp_leave_lobby = function()
	local function do_leave()
		PVP.pvp_leave_lobby()
		MPAPI.refresh_current_view()
	end
	-- Mid-game (e.g. from the end screen) confirm before tearing down the run; from the
	-- main-menu lobby view leave immediately.
	if G.STAGE ~= G.STAGES.MAIN_MENU then
		G.FUNCS.confirm_selection(do_leave)
	else
		do_leave()
	end
end

-- Host: open the vanilla run setup screen to pick the lobby's deck and stake. Its Select
-- button lands in the G.FUNCS.start_run wrapper (overrides/run_start.lua), which publishes
-- the pick to the lobby metadata.
G.FUNCS.lobby_choose_deck = function(e)
	G.FUNCS.setup_run(e)
	if G.OVERLAY_MENU then
		local seed = G.OVERLAY_MENU:get_UIE_by_ID("run_setup_seed")
		if seed then
			seed:remove()
		end
	end
end

G.FUNCS.mp_pvp_lobby_options = function()
	G.FUNCS.overlay_menu({ definition = PVP.build_lobby_options() })
end
