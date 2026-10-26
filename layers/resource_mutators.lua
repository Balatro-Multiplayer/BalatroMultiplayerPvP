-- Fixed recipes from the Clock design, exposed as run-long manual house rules.
-- Random cadence/reveal/expiry belongs to the director, not these setup layers.
local function resource_layer(key, deltas, modifiers)
	MPAPI.Layer(key, {
		game_modifiers = modifiers,
		calculate = function(self, context)
			if context.apply_bans then PVP.apply_round_deltas(key, deltas) end
		end,
	})
end

resource_layer("second_wind", { hands = 1 })
resource_layer("fresh_start", { discards = 1 })
resource_layer("all_in", { hands = 1, discards = -1 })
resource_layer("paid_overtime", { hands = 1 }, { no_extra_hand_money = true })
resource_layer("discard_dividend", { discards = 1 }, { discard_cost = 1, money_per_discard = 2 })
resource_layer("working_capital", { hands = 1 }, { no_interest = true })
