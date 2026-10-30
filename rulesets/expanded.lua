PVP.Ruleset({
	key = "expanded",
	layers = { "balanced", "expanded", "pvp_timer" },
	allowed_stakes = { "stake_white", "stake_green", "stake_black", "stake_purple", "stake_gold", "stake_mp_spectralplus" },
	-- Spectral+ is drafted half as often as each other stake.
	half_weight_stakes = { "stake_mp_spectralplus" },
	-- Ranked also drafts Cocktail (Bean's Cocktail in matchmade games, see objects/decks/ZZ_cocktail.lua).
	allowed_backs = { "b_mp_cocktail" },
}):inject()
