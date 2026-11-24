-- Gates all Trap consumables (objects/consumables/traps.lua) behind this layer --
-- MPAPI's pool-gating auto-attaches mp_include to any card listed in a layer's
-- reworked_consumables, so they only spawn when "traps" is part of the active
-- ruleset's layers or toggled on as a runtime modifier.
MPAPI.Layer("traps", {
	reworked_consumables = {
		"c_mp_trap_glyph_of_warding",
		"c_mp_trap_symbol",
		"c_mp_trap_alarm",
		"c_mp_trap_explosive_runes",
		"c_mp_trap_sepia_snake_sigil",
		"c_mp_trap_fire_trap",
		"c_mp_trap_guards_and_wards",
		"c_mp_trap_magic_mouth",
		"c_mp_trap_snare",
		"c_mp_trap_arcane_lock",
		"c_mp_trap_programmed_illusion",
		"c_mp_trap_web",
		"c_mp_trap_forbiddance",
		"c_mp_trap_faithful_hound",
		"c_mp_trap_phase_door",
		"c_mp_trap_mental_prison",
	},
})

-- Booster registration isn't covered by MPAPI's auto-gate (pool_gating.lua only patches
-- Joker/Consumable/Tag:register, and get_pack()'s shop pack-type roll only consults
-- G.GAME.banned_keys, not mp_include) -- so ban the pack keys directly whenever "traps"
-- isn't active. See objects/boosters/traps.lua.
MPAPI.register_ban_source(function()
	if PVP.RULES.is_layer_active("traps") then
		return nil
	end
	return { "p_mp_trap_normal", "p_mp_trap_jumbo" }
end)
