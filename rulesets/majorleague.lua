PVP.Ruleset({
	key = "majorleague",
	layers = { "majorleague" },
	forced_gamemode = "gamemode_mp_attrition",
	is_disabled = function(self)
		return false
	end,
	lobby_options = { timer_base_seconds = 180, timer_forgiveness = 0, the_order = false, preview_disabled = true },
}):inject()
