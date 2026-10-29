-- Credit to @MathIsFun_ and the Balatro Multiplayer project for the layer system this is based on.
PVP.LayerKey = {
	MULTIPLAYER_CONTENT = "multiplayer_content",
	SANDBOX = "sandbox",
}

MPAPI.register_mod_isolation(PVP.id, function()
	return false
end)

-- ----------------------------------------------------------------------------
-- Modifier layers
-- ----------------------------------------------------------------------------
-- MPAPI.MODIFIERS/add_modifier/etc. already exist (identical shape, same "not
-- materialized onto the ruleset" design) -- delegate rather than keep a second
-- copy. modifiers_parse is called from networking/action_handlers.lua and
-- apply_default_modifiers from pvp_api/lobby_bridge.lua's mirror_metadata.
PVP.modifiers_parse = MPAPI.modifiers_parse

PVP.is_layer_active = MPAPI.is_layer_active
PVP.is_any_layer_active = MPAPI.is_any_layer_active
