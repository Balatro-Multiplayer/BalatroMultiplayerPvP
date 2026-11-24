SMODS.Atlas({
	key = "satellite_sandbox",
	path = "j_satellite_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "satellite_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	rarity = 2,
	cost = 6,
	atlas = "satellite_sandbox",
	config = { extra = { dollars = 1 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.dollars } }
	end,
	calculate = function(self, card, context)
		if context.using_consumeable and not context.blueprint and context.consumeable.ability.set == "Planet" then
			card.ability.extra.dollars = card.ability.extra.dollars + 1
			return {
				-- todo fix
				message = localize({ type = "variable", key = "k_val_up", vars = { 1 } }),
			}
		end
		if context.ending_shop and not context.blueprint then
			if card.ability.extra.dollars > 0 then
				local decrease = math.min(card.ability.extra.dollars, 2)
				card.ability.extra.dollars = card.ability.extra.dollars - decrease
				play_sound("slice1", 0.96 + math.random() * 0.08)
				play_sound("slice1", 0.86 + math.random() * 0.08)
				-- todo fix
				return {
					message = localize({ type = "variable", key = "k_melted_ex", vars = { decrease } }),
				}
			end
		end
	end,
	calc_dollar_bonus = function(self, card)
		return card.ability.extra.dollars > 0 and card.ability.extra.dollars or nil
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
