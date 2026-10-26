PVP.Ruleset({
	key = "traditional",
	layers = { "standard", PVP.LayerKey.MULTIPLAYER_CONTENT },
	force_lobby_options = function(self)
		PVP.LOBBY.config.timer = false
		return false
	end,
}):inject()
