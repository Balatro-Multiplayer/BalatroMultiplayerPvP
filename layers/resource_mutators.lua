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

-- Manual and timed forms use the same recipe, with different lifecycles.
for _, key in ipairs({
	"second_wind",
	"fresh_start",
	"all_in",
	"paid_overtime",
	"discard_dividend",
	"working_capital",
}) do
	local payload = PVP.CHAOS.effects[key].payload
	resource_layer(key, payload.round_deltas, payload.modifiers)
end
