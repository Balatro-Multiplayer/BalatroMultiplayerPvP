-- Cosmetic fixture: acquired keys are supplied directly, without claiming to
-- exercise their gameplay effects. Optional screenshots go to a caller-owned dir.
local old_reduced
local function capture(name)
	local directory = os.getenv("BMP_SCREENSHOT_DIR")
	if not directory then return end
	love.graphics.captureScreenshot(function(image)
		local file = assert(io.open(directory .. "/" .. name .. ".png", "wb"))
		file:write(image:encode("png"):getString())
		file:close()
	end)
end
return {
	{
		run = function(S)
			local back = MPAPI.back_for_key("b_mp_chaos")
			S.check(back ~= nil, "Almanac carrier is registered")
			PVP._start_practice("ruleset_mp_vanilla", {
				back = back.name,
				stake = 1,
				seed = "BACKTEST",
			})
		end,
	},
	{
		until_ = function()
			return G.blind_select_opts and G.blind_select_opts.small
		end,
		timeout = 20,
		run = function(S)
			old_reduced = G.SETTINGS.reduced_motion
			G.SETTINGS.reduced_motion = true
			G.GAME.chaos_draft.acquired = {
				"b_red",
				"b_blue",
				"b_yellow",
				"b_mp_violet",
				"b_ghost",
				"b_mp_gradient",
				"b_mp_heidelberg",
				"b_black",
				"b_checkered",
			}
			S.check(#G.playing_cards == 52, "visual fixture leaves real deck intact")
		end,
	},
	{
		until_ = function()
			return #PVP.ALMANAC_DRAFT.visuals.sprites == 8
		end,
		run = function(S)
			local V = PVP.ALMANAC_DRAFT.visuals
			S.check(V.badge ~= nil, "overflow badge exists")
			S.check(V.arrival == 1 and V.fan == 0, "reduced-motion stack is static")
			capture("almanac-pile")
		end,
	},
	{
		run = function(S)
			local V = PVP.ALMANAC_DRAFT.visuals
			V.choose_collection = true
			G.FUNCS.deck_info()
			V.choose_collection = nil
			S.check(G.OVERLAY_MENU ~= nil, "native deck viewer opens collection tab")
		end,
	},
	{
		run = function()
			capture("almanac-collection")
		end,
	},
	{
		run = function()
			G.FUNCS.pvp_almanac_next_page()
		end,
	},
	{
		run = function(S)
			S.check(PVP.ALMANAC_DRAFT.visuals.page == 2, "collection page two opens")
			G.FUNCS.exit_overlay_menu()
			G.SETTINGS.reduced_motion = old_reduced
			G.FUNCS.go_to_menu()
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.MENU
		end,
		run = function(S)
			S.check(#PVP.ALMANAC_DRAFT.visuals.sprites == 0, "visual cache released on exit")
		end,
	},
}
