-- Only implemented manual layers belong here. Pending Clock concepts are not
-- menu options. All entries are run-long; this is not a random event catalogue.
for category, keys in pairs({
	[PVP.MutatorCategory.ECONOMY] = {
		"inflation",
		"no_interest",
		"discard_tax",
		"frugal",
		"bigger_shop",
		"pricey_packs",
	},
	[PVP.MutatorCategory.MAYHEM] = {
		"flipped_cards",
		"debuff_played_cards",
		"all_eternal",
		"shrinking_hand",
		"shared_pockets",
	},
	[PVP.MutatorCategory.HAZARDS] = { "gambling_opportunity", "no_uncommons", "no_red_seals", "chip_cap", "smallworld" },
	[PVP.MutatorCategory.CHAOS] = {
		"glass_cannon",
		"score_instability",
		"eeeee",
		"polymorph_spam",
		"spartan",
	},
	[PVP.MutatorCategory.RESOURCES] = {
		"second_wind",
		"fresh_start",
		"all_in",
		"paid_overtime",
		"discard_dividend",
		"working_capital",
	},
	[PVP.MutatorCategory.CONTENT] = { "sandbox_rotation", "sandbox_retired", "sandbox_extra_credit" },
	[PVP.MutatorCategory.BALANCE] = { "wraith_rework", "dice_patch" },
}) do
	for order, key in ipairs(keys) do
		assert(MPAPI.Layers[key], "Missing manual mutator layer: " .. key)
		PVP.Mutator(key, category, order)
	end
end

PVP.MUTATORS.sandbox_rotation.implied_by = "sandbox"
PVP.MUTATORS.sandbox_extra_credit.implied_by = "sandbox"
