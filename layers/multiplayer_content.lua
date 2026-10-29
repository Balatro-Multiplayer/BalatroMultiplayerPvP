function PVP.multiplayer_content_enabled()
	return PVP.is_layer_active(PVP.LayerKey.MULTIPLAYER_CONTENT)
end

MPAPI.Layer(PVP.LayerKey.MULTIPLAYER_CONTENT, {
	multiplayer_content = true,
	included_jokers = {
		"j_mp_speedrun",
		"j_mp_conjoined_joker",
		"j_mp_defensive_joker",
		"j_mp_pizza",
		"j_mp_penny_pincher",
		"j_mp_pacifist",
		"j_mp_lets_go_gambling",
		"j_mp_taxes",
		"j_mp_skip_off",
	},
	included_consumables = { "c_mp_asteroid" },
	reworked_vouchers = { "v_mp_hieroglyph_manhunt", "v_mp_petroglyph_manhunt" },
})
