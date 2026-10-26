SMODS.Joker({
	key = "ambrosia_sandbox",
	no_collection = PVP.sandbox_no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = false,

	rarity = 2,
	cost = 5,
	atlas = "ec_jokers_sandbox",
	pos = { x = 5, y = 2 },

	config = {
		extra = {},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		return { vars = {} }
	end,

	calculate = function(self, card, context)
		if context.skip_blind then
			for i = 1, G.consumeables.config.card_limit do
				if #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit then
					G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
					G.E_MANAGER:add_event(Event({
						trigger = "before",
						delay = 0.0,
						func = function()
							local card = create_card("Spectral", G.consumeables, nil, nil, nil, nil, nil, "ambro")
							card:add_to_deck()
							G.consumeables:emplace(card)
							G.GAME.consumeable_buffer = 0
							card:juice_up(0.5, 0.5)
							return true
						end,
					}))
					card_eval_status_text(
						context.blueprint_card or card,
						"extra",
						nil,
						nil,
						nil,
						{ message = localize("k_plus_spectral"), colour = G.C.SECONDARY_SET.Spectral }
					)
				end
			end
		elseif context.selling_card then
			if context.card.ability.set == "Spectral" then
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
				card_eval_status_text(
					context.blueprint_card or card,
					"extra",
					nil,
					nil,
					nil,
					{ message = localize("k_drank_ex"), colour = G.C.SECONDARY_SET.Spectral }
				)
			end
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "DottyKitty" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
