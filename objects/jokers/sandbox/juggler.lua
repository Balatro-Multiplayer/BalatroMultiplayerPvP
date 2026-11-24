SMODS.Atlas({
	key = "juggler_sandbox",
	path = "j_juggler_sandbox.png",
	px = 71,
	py = 95,
})
SMODS.Joker({
	key = "juggler_sandbox",
	no_collection = PVP.SANDBOX.no_collection,

	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	rarity = 1,
	cost = 4,
	atlas = "juggler_sandbox",
	config = { extra = { h_size = 3 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.h_size } }
	end,
	add_to_deck = function(self, card, from_debuff)
		G.hand:change_size(card.ability.extra.h_size)
	end,
	remove_from_deck = function(self, card, from_debuff)
		G.hand:change_size(-card.ability.extra.h_size)
	end,
	calculate = function(self, card, context)
		if context.before and context.main_eval and not context.blueprint then
			if #context.full_hand < 5 then
				card.ability.extra.h_size = card.ability.extra.h_size - 1
				G.hand:change_size(-1)
				card_eval_status_text(card, "extra", nil, nil, nil, { message = "-1 Hand Size" }) -- TODO localize

				if card.ability.extra.h_size <= 0 then
					G.E_MANAGER:add_event(Event({
						func = function()
							play_sound("tarot1")
							card.T.r = -0.2
							card:juice_up(0.3, 0.4)
							card.states.drag.is = false
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
					card_eval_status_text(card, "extra", nil, nil, nil, { message = localize("k_extinct_ex") })
				end
			end
		end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
