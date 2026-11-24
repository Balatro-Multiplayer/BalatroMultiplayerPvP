SMODS.Atlas({
	key = "ride_the_bus_sandbox",
	path = "j_ride_the_bus_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "ride_the_bus_sandbox",
	blueprint_compat = true,
	perishable_compat = false,
	no_collection = PVP.SANDBOX.no_collection,

	unlocked = true,
	discovered = true,
	rarity = 1,
	cost = 6,
	atlas = "ride_the_bus_sandbox",
	config = { extra = { mult_gain = 1, mult = 0, max_gain = 5 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.mult } }
	end,
	calculate = function(self, card, context)
		if context.before and context.main_eval and not context.blueprint then
			local faces = false
			for _, playing_card in ipairs(context.scoring_hand) do
				if playing_card:is_face() then
					faces = true
					break
				end
			end
			if faces then
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
			else
				card.ability.extra.mult = card.ability.extra.mult + card.ability.extra.mult_gain
				if card.ability.extra.mult_gain < card.ability.extra.max_gain then
					card.ability.extra.mult_gain = card.ability.extra.mult_gain + 1
				end
			end
		end
		if context.joker_main then return {
			mult = card.ability.extra.mult,
		} end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
