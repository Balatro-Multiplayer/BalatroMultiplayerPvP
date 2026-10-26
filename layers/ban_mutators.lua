-- Ban mutator layers (green knobs — pure ban deltas).
--
-- These are just `banned_*` arrays. When a layer is active (baked into a ruleset
-- or picked as a runtime modifier), current_ruleset() unions its ban arrays into
-- ApplyBans, so no extra wiring is needed.

-- "Gambling Opportunity" (Handsome-Devils): no easy money. Bans the
-- money-generating enhancements. (Gold-seal / money-edition bans need a card-set
-- hook, so they're out of the pure-data version — enhancements cover the bulk.)
MPAPI.Layer("gambling_opportunity", {
	banned_enhancements = {
		"m_gold",
		"m_lucky",
	},
})

MPAPI.Layer("no_uncommons", {
	calculate = function(self, context)
		if not context.apply_bans then return end
		for key, center in pairs(G.P_CENTERS) do
			if center.set == "Joker" and center.rarity == 2 then G.GAME.banned_keys[key] = true end
		end
	end,
})
