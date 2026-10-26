PVP.Ruleset({
	key = "vanilla",
	multiplayer_content = false,
	force_lobby_options = function(self)
		PVP.LOBBY.config.the_order = false
		return false
	end,
}):inject()
