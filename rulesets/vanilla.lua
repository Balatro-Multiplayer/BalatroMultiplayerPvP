PVP.Ruleset({
	key = "vanilla",
	multiplayer_content = false,
	-- Vanilla Ranked plays without The Order, as its Find Game pillar says.
	-- kind is set only on the Ranked path (PVP.force_ranked_lobby_options);
	-- a Casual vote or a private lobby keeps the host's choice.
	force_lobby_options = function(self, kind)
		if kind == PVP.LobbyAccess.RANKED then
			PVP.LOBBY.config.the_order = false
		end
		return false
	end,
}):inject()
