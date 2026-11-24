SMODS.Atlas({
	key = "runner_sandbox",
	path = "j_runner_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "runner_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	blueprint_compat = true,
	perishable_compat = false,

	unlocked = true,
	discovered = true,
	rarity = 1,
	cost = 5,
	atlas = "runner_sandbox",
	config = { extra = { chips = 0, chip_mod = 50 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.chips } }
	end,
	calculate = function(self, card, context)
		if context.before and context.main_eval and not context.blueprint and next(context.poker_hands["Straight"]) then
			card.ability.extra.chips = card.ability.extra.chips + card.ability.extra.chip_mod
			return {
				message = localize("k_upgrade_ex"),
				colour = G.C.CHIPS,
			}
		end
		if context.joker_main and next(context.poker_hands["Straight"]) then
			return {
				chips = card.ability.extra.chips,
			}
		end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
