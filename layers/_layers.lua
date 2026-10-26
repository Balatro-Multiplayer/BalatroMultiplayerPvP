-- Credit to @MathIsFun_ and the Balatro Multiplayer project for the layer system this is based on.
-- Content belongs to explicit included_*/reworked_* layer lists or a bespoke
-- mp_include. Mod ownership alone must not add a card to a run's pools.
PVP.LayerKey = {
	MULTIPLAYER_CONTENT = "multiplayer_content",
	NO_MULTIPLAYER_CONTENT = "no_multiplayer_content",
	SANDBOX = "sandbox",
}

-- PvP's *_mp_* keys are already excluded without a gate; registering a closed
-- one marks PvP as isolated, so MPAPI warns about content left out of a layer.
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

-- PVP.active_layer_chain()/get_active_ruleset() (rulesets/_rulesets.lua) resolve the
-- same lobby metadata MPAPI's own equivalents do, but additionally know about PvP's
-- practice-mode case that MPAPI doesn't -- kept as the PvP-owned resolution layer
-- for that reason, even though the two agree for any live lobby.
function PVP.is_layer_active(layer_name)
	if not layer_name then return false end
	for _, name in ipairs(PVP.active_layer_chain()) do
		if name == layer_name then return true end
	end
	return false
end

function PVP.is_any_layer_active(layers)
	for _, layer_name in pairs(layers) do
		if PVP.is_layer_active(layer_name) then return true end
	end
	return false
end
