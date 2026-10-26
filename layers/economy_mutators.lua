-- Shop prices climb +$1 per purchase, compounding across the run.
-- (card.lua: `if G.GAME.modifiers.inflation then G.GAME.inflation = ... + 1`)

MPAPI.Layer("inflation", {
	game_modifiers = { inflation = true },
})

-- No interest paid on held money
MPAPI.Layer("no_interest", {
	game_modifiers = { no_interest = true },
})

-- Every discard costs $1
MPAPI.Layer("discard_tax", {
	game_modifiers = { discard_cost = 1 },
})

-- Leftover discards pay out at end of round
MPAPI.Layer("frugal", {
	game_modifiers = { money_per_discard = 1 },
})

-- No cash reward from Small or Big blinds (Boss/PvP payout left intact).
-- (blind.lua: dollars zeroed when no_blind_reward[blind_type] is set)
MPAPI.Layer("spartan", {
	game_modifiers = { no_blind_reward = { Small = true, Big = true } },
})

-- Booster packs cost +$1 more for each ante you're into the run.
-- (card.lua set_cost: cost + round_resets.ante - 1 when booster_ante_scaling)
MPAPI.Layer("pricey_packs", {
	game_modifiers = { booster_ante_scaling = true },
})
