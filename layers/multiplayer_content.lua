-- Original PvP content, independent of balance replacements and match format.
PVP.ContentMode = { DEFAULT = "default", ON = "on", OFF = "off" }

-- The layer owns the cards; the resolved multiplayer_content flag is the switch
-- the Off layer turns off.
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
	-- Manhunt's replacements for the vanilla Hieroglyph/Petroglyph, which
	-- Attrition bans. Their in_pool predicates still restrict these to Manhunt.
	reworked_vouchers = { "v_mp_hieroglyph_manhunt", "v_mp_petroglyph_manhunt" },
	-- TODO(mpapi): needed only because MPAPI.active_layer_chain can't resolve
	-- PvP's chain: it reads the ruleset from lobby metadata with no session or
	-- Practice check, and adds the prefixed ruleset key where PvP's layer uses the
	-- short name. A consumer-registered active-ruleset resolver in MPAPI would
	-- remove this, PVP.active_layer_chain and PVP.is_layer_active.
	pool_enabled = PVP.multiplayer_content_enabled,
})

-- TODO(mpapi): modifiers can only add layers, so Off vetoes through the flag
-- rather than removing the content layer. A modifier that removes layers from
-- the chain would make layer membership the only signal.
MPAPI.Layer(PVP.LayerKey.NO_MULTIPLAYER_CONTENT, { multiplayer_content = false })

-- The Default/On/Off choice is at most one of the two layers above, added as a
-- modifier on top of the ruleset's default_modifiers. No separate lobby field.
function PVP.multiplayer_content_mode()
	if MPAPI.has_modifier(PVP.LayerKey.NO_MULTIPLAYER_CONTENT) then return PVP.ContentMode.OFF end
	if MPAPI.has_modifier(PVP.LayerKey.MULTIPLAYER_CONTENT) then return PVP.ContentMode.ON end
	return PVP.ContentMode.DEFAULT
end

-- The serialized modifier list for a ruleset and content choice.
-- TODO(mpapi): the ruleset-defaults-plus-extras part is generic; it belongs next
-- to MPAPI.apply_default_modifiers as a function that returns the list instead of
-- applying it.
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

-- The one writer of a session's modifiers. Keeps the copy that lobby metadata
-- and replays carry in step with MPAPI.MODIFIERS.
function PVP.set_modifier_layers(serialized)
	MPAPI.modifiers_parse(serialized)
	PVP.LOBBY.config.modifier_layers = MPAPI.modifiers_serialize()
end

function PVP.set_multiplayer_content_mode(mode)
	PVP.set_modifier_layers(PVP.modifier_layers_for(PVP.get_active_ruleset(), mode))
end
