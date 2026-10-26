-- Fill consumable slots with The Fool cards after Boss Blind is defeated

SMODS.Joker({
	key = "clowncollege_sandbox",
	no_collection = PVP.sandbox_no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = true,
	rarity = 2,
	cost = 7,
	atlas = "ec_jokers_sandbox",
	pos = { x = 4, y = 1 },
	config = { extra = {}, mp_sticker_extra_credit = true },

	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = { key = "c_fool", set = "Tarot" }
		return { vars = {} }
	end,

	calculate = function(self, card, context)
		if
			context.end_of_round
			and not context.repetition
			and not context.individual
			and G.GAME.blind.boss
			and not context.blueprint
		then
			for i = 1, G.consumeables.config.card_limit do
				if #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit then
					G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
					G.E_MANAGER:add_event(Event({
						trigger = "before",
						delay = 0.0,
						func = function()
							local new_card = create_card("Tarot", G.consumeables, nil, nil, nil, nil, "c_fool")
							new_card:add_to_deck()
							G.consumeables:emplace(new_card)
							G.GAME.consumeable_buffer = 0
							new_card:juice_up(0.5, 0.5)
							return true
						end,
					}))
					card_eval_status_text(
						context.blueprint_card or card,
						"extra",
						nil,
						nil,
						nil,
						{ message = localize("k_plus_tarot"), colour = G.C.PURPLE }
					)
				end
			end
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "DottyKitty" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
