-- The Major League Balatro rules on top of vanilla cards. Every client reads
-- them from the shared ruleset key, so none of them is a lobby option.
MPAPI.Layer("majorleague", {
	banned_silent = {
		"j_bloodstone",
	},
	reworked_jokers = {
		"j_mp_bloodstone",
	},
	enemy_location_disabled = true,
	-- Seconds: above this the timer shows this value and the opponent is not told it started.
	timer_display_threshold = 180,
})
