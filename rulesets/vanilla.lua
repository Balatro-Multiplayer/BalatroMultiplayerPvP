PVP.Ruleset({
	key = "vanilla",
	-- Vanilla plays without The Order in every lobby kind: Ranked, a Casual
	-- vote that rolls Vanilla, and a private lobby where the host picks it.
	lobby_options = { the_order = false },
}):inject()
