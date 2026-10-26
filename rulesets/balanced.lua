PVP.Ruleset({
	key = "balanced",
	layers = { "standard", PVP.LayerKey.MULTIPLAYER_CONTENT, "ranked", "pvp_timer" },
	forced_gamemode = "gamemode_mp_attrition",
}):inject()
