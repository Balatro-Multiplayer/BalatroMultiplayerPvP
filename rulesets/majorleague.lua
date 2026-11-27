PVP.Ruleset({
	key = "majorleague",
	layers = { "majorleague" },
	forced_gamemode = "gamemode_mp_attrition",
	is_disabled = function(self)
		return false
	end,
	lobby_settings = {
		timer_base_seconds = { locked = 180 },
		timer_forgiveness = { locked = 0 },
		the_order = { locked = false },
		preview_disabled = { locked = true },
	},
}):inject()
