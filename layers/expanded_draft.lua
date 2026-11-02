-- Stake weights merge by key when rulesets compose layers.
table.insert(MPAPI._LAYER_TABLE_FIELDS, "stake_weights")

MPAPI.Layer("expanded_draft", {
	allowed_stakes = {
		"stake_white",
		"stake_green",
		"stake_black",
		"stake_purple",
		"stake_gold",
		"stake_mp_spectralplus",
	},
	stake_weights = { stake_mp_spectralplus = 0.5 },
	allowed_backs = { "b_mp_cocktail" },
})
