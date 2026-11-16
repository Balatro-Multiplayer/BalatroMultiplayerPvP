PVP.Ruleset({
	key = "balanced",
	layers = { "balanced", "pvp_timer" },
	optional_layers = { "traps", PVP.LayerKey.MULTIPLAYER_CONTENT },
	banned_backs = { "b_mp_orange", "b_mp_violet" },
}):inject()
