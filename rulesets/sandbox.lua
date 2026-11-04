PVP.Ruleset({
	key = "sandbox",
	layers = { PVP.LayerKey.SANDBOX },


	force_lobby_options = function(self)
		PVP.LOBBY.config.preview_disabled = true
		PVP.LOBBY.config.the_order = true
		PVP.LOBBY.config.starting_lives = 4
		return false
	end,
}):inject()
