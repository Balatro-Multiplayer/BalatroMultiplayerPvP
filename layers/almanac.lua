MPAPI.Layer("almanac", {
	draft_policy = "almanac",
	required_back = "b_mp_almanac",
	allowed_backs = { "b_mp_almanac" },
	allowed_stakes = { "stake_mp_white_minus" },
	forced_lobby_options = true,
	force_lobby_options = function()
		local center = G.P_CENTERS.b_mp_almanac
		if center then
			PVP.LOBBY.config.back = center.name
			PVP.LOBBY.deck.back = center.name
		end
		PVP.LOBBY.config.different_decks = false
		PVP.LOBBY.config.random_loadout = false
		PVP.LOBBY.config.sleeve = "sleeve_casl_none"
		PVP.LOBBY.deck.sleeve = "sleeve_casl_none"
		PVP.LOBBY.config.challenge = ""
		PVP.LOBBY.deck.challenge = ""
		PVP.LOBBY.config.shared_pvp_rules = true
		return true
	end,
})
