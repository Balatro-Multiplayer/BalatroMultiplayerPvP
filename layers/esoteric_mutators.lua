MPAPI.Layer("flipped_cards", {
	game_modifiers = { flipped_cards = 1 },
})

MPAPI.Layer("debuff_played_cards", {
	game_modifiers = { debuff_played_cards = true },
})

MPAPI.Layer("all_eternal", {
	game_modifiers = { all_eternal = true },
})

MPAPI.Layer("chip_cap", {
	game_modifiers = { chips_dollar_cap = true },
})

MPAPI.Layer("shrinking_hand", {
	game_modifiers = { minus_hand_size_per_X_dollar = 10 },
})
