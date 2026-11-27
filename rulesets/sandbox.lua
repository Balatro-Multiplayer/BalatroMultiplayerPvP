PVP.Ruleset({
	key = "sandbox",
	layers = { PVP.LayerKey.SANDBOX, PVP.LayerKey.MULTIPLAYER_CONTENT },

	lobby_settings = {
		preview_disabled = { locked = true },
		the_order = { default = true },
		starting_lives = { default = 4 },
	},
}):inject()
