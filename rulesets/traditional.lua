PVP.RULES.Ruleset({
	key = "traditional",
	layers = { "balanced", "expanded", PVP.RULES.LayerKey.MULTIPLAYER_CONTENT },
	force_lobby_options = function(self)
		PVP.LOBBY.config.timer = false
		return false
	end,
}):inject()
