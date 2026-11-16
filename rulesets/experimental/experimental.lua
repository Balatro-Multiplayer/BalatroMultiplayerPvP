PVP.Ruleset({
	key = "experimental",
	layers = { "experimental", PVP.LayerKey.MULTIPLAYER_CONTENT },
	default_modifiers = { "pvp_timer", "pressure_timer" },
	forced_gamemode = "gamemode_mp_attrition",
	lobby_options = { the_order = true },
}):inject()
