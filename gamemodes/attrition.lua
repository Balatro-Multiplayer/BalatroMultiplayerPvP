PVP.Gamemode({
	key = "attrition",
	get_blinds_by_ante = function(self, ante)
		if ante >= PVP.LOBBY.config.pvp_start_round then
			-- PVP.current_target_id() is always non-nil for 1v1 (sole opponent). For
			-- Nemesis (rotating pairing), nil means byed this ante -- fall through to a
			-- normal boss instead of the nemesis one, the entire bye mechanism. Royale
			-- has no bye/sit-out concept (the server ranks and cuts every alive
			-- player every PvP round), and the Royale target (now pvp.targets) once only latched as
			-- a side effect of a multiplayer joker/consumable interaction (Asteroid/
			-- Taxes/Penny Pincher) -- which can't happen before the first PvP blind ever
			-- runs. Treating an unresolved Royale target as a bye would mean a match with
			-- no multiplayer jokers owned/used never reaches a PvP blind at all, so only
			-- Nemesis-pairing's real bye gates on it.
			-- A playback has no opponent, which reads as a bye. The recorded run had a partner.
			local byed = PVP.is_byed() and not PVP.SP.playback_gamemode
			if not PVP.LOBBY.config.normal_bosses and not byed then
				return nil, nil, "bl_mp_nemesis"
			else
				G.GAME.round_resets.pvp_blind_choices.Boss = true
			end
		end
		return nil, nil, nil
	end,
	banned_jokers = {
		"j_mr_bones",
		"j_luchador",
		"j_matador",
		"j_chicot",
	},
	banned_consumables = {},
	banned_vouchers = {
		"v_hieroglyph",
		"v_petroglyph",
		"v_directors_cut",
		"v_retcon",
	},
	banned_enhancements = {},
	banned_tags = {
		"tag_boss",
	},
	banned_blinds = {
		"bl_wall",
		"bl_final_vessel",
	},
	reworked_jokers = {},
	reworked_consumables = {},
	reworked_vouchers = {},
	reworked_enhancements = {},
	reworked_tags = {},
	reworked_blinds = {},
}):inject()
