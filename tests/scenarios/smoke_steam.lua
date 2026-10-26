-- Steam-dependent registration and page rendering; no server login or lobby required.
local menu_key

return {
	{
		until_ = function()
			return MPAPI.is_ready()
		end,
		run = function(S)
			S.check(G.STEAM ~= nil, "Steam initialized")
		end,
	},
	{
		run = function(S)
			S.check(MPAPI.is_ready(), "MPAPI startup callbacks ran")
			S.check(PVP and PVP.id == "MultiplayerPvP", "PvP loaded")
			local registered
			for _, mod in ipairs(MPAPI.get_registered_mods()) do
				if mod.id == "MultiplayerPvP" and mod.main_menu_ui then
					registered = mod
					break
				end
			end
			assert(S.check(registered ~= nil, "PvP registered its menu"), "cannot open unregistered menu")
			menu_key = registered.main_menu_ui
			MPAPI.pages.show(menu_key, { mod = registered })
		end,
	},
	{
		until_ = function()
			return MPAPI.pages.current_key() == menu_key and G.MAIN_MENU_UI
		end,
		run = function(S)
			local page = MPAPI.pages.current()
			S.check(page and page.instance ~= nil, "PvP main menu page rendered")
			S.check(G.MAIN_MENU_UI ~= nil and G.STATE == G.STATES.MENU, "real menu UI is present")
		end,
	},
}
