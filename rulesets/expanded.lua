PVP.Ruleset({
	key = "expanded",
	layers = { "balanced", "expanded", "pvp_timer" },
	allowed_stakes = { "stake_white", "stake_green", "stake_black", "stake_purple", "stake_gold", "stake_mp_spectralplus" },
	-- Spectral+ is drafted half as often as each other stake.
	stake_weights = { stake_mp_spectralplus = 0.5 },
	-- Ranked also drafts Cocktail (a fixed mix in matchmade games, see PVP.pvp_lobby_metadata).
	allowed_backs = { "b_mp_cocktail" },
}):inject()
