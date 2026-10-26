-- Candy Necklace - Extra Credit Joker ported to Sandbox
-- Random Booster Pack Tag at shop end (5 uses)

SMODS.Joker({
	key = "candynecklace_sandbox",
	no_collection = PVP.sandbox_no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = false,
	rarity = 2,
	cost = 8,
	atlas = "ec_jokers_sandbox",
	pos = { x = 9, y = 0 },
	config = {
		extra = {
			candies = 5,
			flavours = { "tag_buffoon", "tag_charm", "tag_meteor", "tag_standard", "tag_ethereal" },
		},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.candies } }
	end,

	calculate = function(self, card, context)
		if context.ending_shop and card.ability.extra.candies > 0 then
			local tag_key = pseudorandom_element(card.ability.extra.flavours, pseudoseed("candy_tag"))
			add_tag(Tag(tag_key))

			if not context.blueprint then
				card.ability.extra.candies = card.ability.extra.candies - 1

				if card.ability.extra.candies <= 0 then
					G.E_MANAGER:add_event(Event({
						func = function()
							play_sound("tarot1")
							card.T.r = -0.2
							card:juice_up(0.3, 0.4)
							card.states.drag.is = true
							card.children.center.pinch.x = true
							G.E_MANAGER:add_event(Event({
								trigger = "after",
								delay = 0.3,
								blockable = false,
								func = function()
									G.jokers:remove_card(card)
									card:remove()
									card = nil
									return true
								end,
							}))
							return true
						end,
					}))
					return {
						message = localize("k_eaten_ex"),
						colour = G.C.MONEY,
					}
				end
			end
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "DottyKitty" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
