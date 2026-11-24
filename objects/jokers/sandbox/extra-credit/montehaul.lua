-- Monte Haul - Extra Credit Joker ported to Sandbox
-- After 1 round, sell this card to gain 2 random Joker Tags

SMODS.Joker({
	key = "montehaul_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = false,
	rarity = 2,
	cost = 5,
	atlas = "ec_jokers_sandbox",
	pos = { x = 5, y = 1 },
	config = {
		extra = {
			monty_rounds = 0,
			flavours = { "tag_foil", "tag_holo", "tag_polychrome", "tag_negative", "tag_uncommon", "tag_rare" },
		},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = { key = "tag_foil", set = "Tag" }
		info_queue[#info_queue + 1] = { key = "tag_holo", set = "Tag" }
		info_queue[#info_queue + 1] = { key = "tag_polychrome", set = "Tag" }
		info_queue[#info_queue + 1] = { key = "tag_negative", set = "Tag" }
		info_queue[#info_queue + 1] = { key = "tag_uncommon", set = "Tag" }
		info_queue[#info_queue + 1] = { key = "tag_rare", set = "Tag" }
		return { vars = { card.ability.extra.monty_rounds } }
	end,

	calculate = function(self, card, context)
		if context.end_of_round and not context.blueprint and not context.individual and not context.repetition then
			card.ability.extra.monty_rounds = card.ability.extra.monty_rounds + 1
			if card.ability.extra.monty_rounds >= 1 then
				local eval = function(c)
					return not c.REMOVED
				end
				juice_card_until(card, eval, true)
				return {
					message = localize("k_active_ex"),
					colour = G.C.FILTER,
				}
			end
		elseif context.selling_self and card.ability.extra.monty_rounds >= 1 then
			for i = 1, 2 do
				G.E_MANAGER:add_event(Event({
					func = function()
						add_tag(Tag(pseudorandom_element(card.ability.extra.flavours, pseudoseed("monty"))))
						play_sound("generic1", 0.9 + math.random() * 0.1, 0.8)
						play_sound("holo1", 1.2 + math.random() * 0.1, 0.4)
						return true
					end,
				}))
			end
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "UselessReptile8" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
