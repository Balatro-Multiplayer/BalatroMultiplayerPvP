-- Only implemented manual layers belong here. Pending Clock concepts are not
-- menu options. All entries are run-long; this is not a random event catalogue.
-- Group by what the rule changes, not its difficulty or the variable it reads.
for category, keys in pairs({
	[PVP.MutatorCategory.ECONOMY] = {
		"no_interest",
		"spartan",
		"discard_tax",
		"frugal",
		"inflation",
		"pricey_packs",
	},
	[PVP.MutatorCategory.CONSTRAINTS] = {
		"shrinking_hand",
		"shared_pockets",
		"flipped_cards",
		"debuff_played_cards",
		"all_eternal",
	},
	[PVP.MutatorCategory.POOL] = {
		"bigger_shop",
		"gambling_opportunity",
		"no_uncommons",
		"no_red_seals",
		"smallworld",
	},
	[PVP.MutatorCategory.SCORING] = {
		"glass_cannon",
		"score_instability",
		"chip_cap",
	},
	[PVP.MutatorCategory.CHAOS] = {
		"eeeee",
		"polymorph_spam",
	},
	[PVP.MutatorCategory.BALANCE] = { "wraith_rework", "dice_patch" },
	[PVP.MutatorCategory.CONTENT] = { "sandbox_rotation", "sandbox_retired", "sandbox_extra_credit" },
}) do
	for order, key in ipairs(keys) do
		assert(MPAPI.Layers[key], "Missing manual mutator layer: " .. key)
		PVP.Mutator(key, category, order)
	end
end

PVP.MUTATORS.sandbox_rotation.implied_by = "sandbox"
PVP.MUTATORS.sandbox_extra_credit.implied_by = "sandbox"
