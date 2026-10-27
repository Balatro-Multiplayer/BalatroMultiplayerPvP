PVP.ContentMode = { DEFAULT = "default", ON = "on", OFF = "off" }

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

MPAPI.Layer(PVP.LayerKey.NO_MULTIPLAYER_CONTENT, {
	removes_layers = { PVP.LayerKey.MULTIPLAYER_CONTENT },
	multiplayer_content = false,
})

function PVP.multiplayer_content_mode()
	if MPAPI.has_modifier(PVP.LayerKey.NO_MULTIPLAYER_CONTENT) then return PVP.ContentMode.OFF end
	if MPAPI.has_modifier(PVP.LayerKey.MULTIPLAYER_CONTENT) then return PVP.ContentMode.ON end
	return PVP.ContentMode.DEFAULT
end

function PVP.modifier_layers_for(ruleset_key, mode)
	local ruleset = ruleset_key and MPAPI.Rulesets[ruleset_key]
	local names = {}
	for i, name in ipairs(ruleset and ruleset.default_modifiers or {}) do
		names[i] = name
	end
	if mode == PVP.ContentMode.ON then
		names[#names + 1] = PVP.LayerKey.MULTIPLAYER_CONTENT
	elseif mode == PVP.ContentMode.OFF then
		names[#names + 1] = PVP.LayerKey.NO_MULTIPLAYER_CONTENT
	end
	return table.concat(names, ",")
end

function PVP.set_modifier_layers(serialized)
	MPAPI.modifiers_parse(serialized)
	PVP.LOBBY.config.modifier_layers = MPAPI.modifiers_serialize()
end

function PVP.set_multiplayer_content_mode(mode)
	PVP.set_modifier_layers(PVP.modifier_layers_for(PVP.get_active_ruleset(), mode))
end
