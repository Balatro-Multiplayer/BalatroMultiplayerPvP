PVP.Ruleset({
	key = "minorleague",
	multiplayer_content = false,
	forced_gamemode = "gamemode_mp_attrition",
	force_lobby_options = function(self)
		PVP.LOBBY.config.timer_base_seconds = 210
		PVP.LOBBY.config.timer_forgiveness = 1
		PVP.LOBBY.config.the_order = true
		return true
	end,
}):inject()
