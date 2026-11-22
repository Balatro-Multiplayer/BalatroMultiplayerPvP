-- The private lobby's rules strip, under the mode banner: one pill per setting changed
-- from standard ("LIVES 6"), or one grey "Standard settings" pill. Every player sees the
-- rules without opening Lobby Options. Rebuilt with the lobby view on every metadata change.

local MAX_PILLS = 6

local function pill(label, standard)
	local colour = standard and G.C.UI.TEXT_INACTIVE or G.C.GOLD
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.07, r = 0.08, colour = G.C.BLACK, outline = 0.8, outline_colour = colour },
		nodes = { { n = G.UIT.T, config = { text = label, scale = 0.3, colour = colour } } },
	}
end

function PVP.lobby.build_rules_strip()
	local O = PVP.lobby_opts
	local config = PVP.LOBBY.config
	local changed = PVP.lobby_settings_changed(config, PVP.lobby_settings_policy(config.ruleset))
	local nodes = {}
	if #changed == 0 then
		nodes[1] = pill(localize("k_pvp_opt_standard_settings"):upper(), true)
	end
	for i, setting in ipairs(changed) do
		if i > MAX_PILLS then
			nodes[#nodes + 1] = pill("+" .. (#changed - MAX_PILLS))
			break
		end
		local value = O.value_label(setting, PVP.lobby_setting_get(setting, config))
		nodes[#nodes + 1] = pill((O.label(setting) .. " " .. value):upper())
	end
	return { n = G.UIT.R, config = { align = "cm", padding = 0.06 }, nodes = nodes }
end
