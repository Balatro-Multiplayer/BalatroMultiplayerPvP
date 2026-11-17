PVP.Ruleset({
	key = "sandbox",
	layers = { PVP.LayerKey.SANDBOX, PVP.LayerKey.MULTIPLAYER_CONTENT },

	lobby_options = { preview_disabled = true, the_order = true, starting_lives = 4 },
}):inject()
