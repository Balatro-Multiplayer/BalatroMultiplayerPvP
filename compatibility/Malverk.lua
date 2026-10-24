-- Malverk (texture pack manager) compatibility: register the alt_t_*.png art
-- (see objects/consumables/traps.lua for the base art on the shared "Trap" sheet) as a
-- selectable alternate texture pack for the Trap consumable type. Malverk reads the default
-- art from G.ASSET_ATLAS["Trap"], so that sheet must exist (one row, TRAPS order). Optional -- no-ops entirely
-- if Malverk isn't installed.
if SMODS.Mods["malverk"] and SMODS.Mods["malverk"].can_load then
	sendDebugMessage("Malverk compatibility detected", "MULTIPLAYER")

	local TRAP_ALTS = {
		{ key = "c_mp_trap_glyph_of_warding", atlas = "alt_t_glyph_of_warding.png" },
		{ key = "c_mp_trap_symbol", atlas = "alt_t_symbol.png" },
		{ key = "c_mp_trap_alarm", atlas = "alt_t_alarm.png" },
		{ key = "c_mp_trap_explosive_runes", atlas = "alt_t_explosive_runes.png" },
		{ key = "c_mp_trap_sepia_snake_sigil", atlas = "alt_t_sepia_snake_sigil.png" },
		{ key = "c_mp_trap_fire_trap", atlas = "alt_t_fire_trap.png" },
		{ key = "c_mp_trap_guards_and_wards", atlas = "alt_t_guards_and_wards.png" },
		{ key = "c_mp_trap_magic_mouth", atlas = "alt_t_magic_mouth.png" },
		{ key = "c_mp_trap_snare", atlas = "alt_t_snare.png" },
		{ key = "c_mp_trap_arcane_lock", atlas = "alt_t_arcane_lock.png" },
		{ key = "c_mp_trap_programmed_illusion", atlas = "alt_t_programmed_illusion.png" },
		{ key = "c_mp_trap_web", atlas = "alt_t_web.png" },
		{ key = "c_mp_trap_forbiddance", atlas = "alt_t_forbiddance.png" },
		{ key = "c_mp_trap_faithful_hound", atlas = "alt_t_faithful_hound.png" },
		{ key = "c_mp_trap_phase_door", atlas = "alt_t_phase_door.png" },
		{ key = "c_mp_trap_mental_prison", atlas = "alt_t_mental_prison.png" },
	}

	-- TexturePack.textures entries need the mod-prefixed key (AltTexture's own
	-- registration -- SMODS.add_prefixes -- adds mod prefix, then class prefix
	-- "alt_tex" on top; TexturePack.inject only re-adds the "alt_tex" class prefix,
	-- so it expects the mod-prefixed form here, matching the README's own example).
	local alt_texture_keys = {}
	for _, def in ipairs(TRAP_ALTS) do
		local alt_key = def.key:gsub("^c_mp_", "") .. "_alt"
		AltTexture({
			key = alt_key,
			set = "Trap",
			path = def.atlas,
			keys = { def.key },
		})
		alt_texture_keys[#alt_texture_keys + 1] = "mp_" .. alt_key
	end

	TexturePack({
		key = "trap_alt",
		textures = alt_texture_keys,
		loc_txt = {
			name = "Alternate Trap Art",
			text = { "An alternate look for", "Trap cards" },
		},
	})
end
