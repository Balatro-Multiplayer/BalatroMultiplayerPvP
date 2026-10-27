PVP.Ruleset({
	key = "vanilla",
	multiplayer_content = false,
	-- Vanilla plays without The Order in every lobby kind: Ranked, a Casual
	-- vote that rolls Vanilla, and a private lobby where the host picks it.
	force_lobby_options = function(self)
		PVP.LOBBY.config.the_order = false
		return false
	end,
}):inject()
