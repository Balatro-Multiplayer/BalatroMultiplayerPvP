SMODS.Atlas({
	key = "square_sandbox",
	path = "j_square_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "square_sandbox",
	no_collection = PVP.SANDBOX.no_collection,

	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	perishable_compat = false,
	rarity = 1,
	cost = 4,
	atlas = "square_sandbox",
	pixel_size = { h = 71 },
	config = { extra = { chips = 64, chip_mod = 16 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.chips, card.ability.extra.chip_mod } }
	end,
	calculate = function(self, card, context)
		if context.before and context.main_eval and not context.blueprint and #context.full_hand == 4 then
			card.ability.extra.chips = card.ability.extra.chips + card.ability.extra.chip_mod
			return {
				message = localize("k_upgrade_ex"),
				colour = G.C.CHIPS,
			}
		end
		if context.joker_main and #context.full_hand == 4 then return {
			chips = card.ability.extra.chips,
		} end
	end,
	mp_credits = { idea = { "Owen" }, code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
