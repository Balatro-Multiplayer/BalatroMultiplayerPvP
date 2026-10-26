-- Boot and exercise the real game without requiring Steam or a server.
return {
	{
		run = function(S)
			S.check(G.STATE == G.STATES.MENU and G.MAIN_MENU_UI ~= nil, "real main menu is present")
			S.check(SMODS.Mods.MultiplayerAPI ~= nil, "MPAPI mod loaded")
			S.check(PVP and PVP.id == "MultiplayerPvP", "PvP mod loaded")
			S.check(type(MPAPI.get_registered_mods) == "function", "MPAPI public API loaded")
		end,
	},
}
