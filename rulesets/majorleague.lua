PVP.Ruleset({
	key = "majorleague",
	layers = { "majorleague" },
	multiplayer_content = false,
	forced_gamemode = "gamemode_mp_attrition",
	forced_lobby_options = true,
	is_disabled = function(self)
		return false
	end,
	force_lobby_options = function(self)
		PVP.LOBBY.config.timer_base_seconds = 180
		PVP.LOBBY.config.timer_forgiveness = 0
		PVP.LOBBY.config.the_order = false
		PVP.LOBBY.config.preview_disabled = true
		return true
	end,
}):inject()
