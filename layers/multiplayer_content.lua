-- Original PvP content, independent of balance replacements and match format.
function PVP.multiplayer_content_enabled()
	return PVP.in_session()
		and PVP.is_layer_active(PVP.LayerKey.MULTIPLAYER_CONTENT)
		and PVP.current_ruleset().multiplayer_content == true
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
	-- Their in_pool predicates still restrict these to Manhunt.
	included_vouchers = { "v_mp_hieroglyph_manhunt", "v_mp_petroglyph_manhunt" },
	pool_enabled = PVP.multiplayer_content_enabled,
})

MPAPI.Layer(PVP.LayerKey.NO_MULTIPLAYER_CONTENT, { multiplayer_content = false })

PVP.ContentMode = { DEFAULT = "default", ON = "on", OFF = "off" }

-- The selection is encoded in modifier layers, not a second pool-eligibility
-- boolean. A ruleset's inherited content flag remains the default.
function PVP.multiplayer_content_mode()
	for i = #MPAPI.MODIFIERS, 1, -1 do
		local name = MPAPI.MODIFIERS[i]
		if name == PVP.LayerKey.MULTIPLAYER_CONTENT then return PVP.ContentMode.ON end
		if name == PVP.LayerKey.NO_MULTIPLAYER_CONTENT then return PVP.ContentMode.OFF end
	end
	return PVP.ContentMode.DEFAULT
end

function PVP.set_multiplayer_content_mode(mode)
	assert(
		mode == PVP.ContentMode.DEFAULT or mode == PVP.ContentMode.ON or mode == PVP.ContentMode.OFF,
		"Unknown multiplayer content mode: " .. tostring(mode)
	)
	MPAPI.remove_modifier(PVP.LayerKey.MULTIPLAYER_CONTENT)
	MPAPI.remove_modifier(PVP.LayerKey.NO_MULTIPLAYER_CONTENT)
	if mode == PVP.ContentMode.ON then
		MPAPI.add_modifier(PVP.LayerKey.MULTIPLAYER_CONTENT)
	elseif mode == PVP.ContentMode.OFF then
		MPAPI.add_modifier(PVP.LayerKey.NO_MULTIPLAYER_CONTENT)
	end
	PVP.LOBBY.config.modifier_layers = MPAPI.modifiers_serialize()
end

-- Import old lobby/replay booleans at the boundary only. Native layer choices
-- take precedence; absence means the ruleset's defaults, never implicit On.
function PVP.restore_modifier_layers(ruleset_key, serialized, legacy_jokers)
	if serialized ~= nil then
		MPAPI.modifiers_parse(serialized)
	else
		MPAPI.apply_default_modifiers(ruleset_key)
		if legacy_jokers == true or legacy_jokers == "true" then
			PVP.set_multiplayer_content_mode(PVP.ContentMode.ON)
		elseif legacy_jokers == false or legacy_jokers == "false" then
			PVP.set_multiplayer_content_mode(PVP.ContentMode.OFF)
		end
	end
	PVP.LOBBY.config.modifier_layers = MPAPI.modifiers_serialize()
end
