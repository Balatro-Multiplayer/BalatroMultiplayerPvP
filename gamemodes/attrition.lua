PVP.RULES.Gamemode({
	key = "attrition",
	get_blinds_by_ante = function(self, ante)
		if ante >= PVP.LOBBY.config.pvp_start_ante then
			local resets = G.GAME.round_resets
			-- The only place the Boss slot is decided; the target screen asks again until the Boss is
			-- played. A bye the view has announced keeps the rolled normal boss but is still a blind
			-- Boss: it gets Ready, waits for everyone, and is played and reported as the blind. Until
			-- the view says either way the Boss is undecided: it cannot be picked. A playback has no
			-- view, and the recorded run had a partner.
			if resets.blind_choices.Boss ~= "bl_mp_nemesis" then
				resets.pvp_normal_boss = resets.blind_choices.Boss
			end
			local boss = "plays"
			if not PVP.PRACTICE.playback_gamemode then boss = PVP.READ.target.my_boss() end
			if boss == "bye" then
				resets.pvp_boss = "decided"
				resets.pvp_blind_choices.Boss = true
				return nil, nil, resets.pvp_normal_boss
			end
			if not PVP.LOBBY.config.normal_bosses then
				resets.pvp_boss = boss == "unknown" and "undecided" or "decided"
				return nil, nil, "bl_mp_nemesis"
			end
			resets.pvp_boss = "decided"
			resets.pvp_blind_choices.Boss = true
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
