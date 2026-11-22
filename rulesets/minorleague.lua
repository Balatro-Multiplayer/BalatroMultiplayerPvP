PVP.Ruleset({
	key = "minorleague",
	forced_gamemode = "gamemode_mp_attrition",
	lobby_settings = {
		timer_base_seconds = { locked = 210 },
		timer_forgiveness = { locked = 1 },
		the_order = { locked = true },
	},
}):inject()
