PVP.Ruleset({
	key = "experimental",
	layers = { "experimental", PVP.LayerKey.MULTIPLAYER_CONTENT },
	default_modifiers = { "pvp_timer", "pressure_timer" },
	forced_gamemode = "gamemode_mp_attrition",
	force_lobby_options = function(self)
		PVP.LOBBY.config.the_order = true
		return false
	end,
}):inject()
