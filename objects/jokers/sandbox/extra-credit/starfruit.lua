-- Starfruit - Extra Credit Joker ported to Sandbox
-- First played hand each round has a chance to gain 1 level (5 uses, then self-destructs)

SMODS.Joker({
	key = "starfruit_sandbox",
	no_collection = PVP.sandbox_no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = false,
	rarity = 1,
	cost = 6,
	atlas = "ec_jokers_sandbox",
	pos = { x = 2, y = 0 },
	config = { extra = { uses = 5, odds = 2 }, mp_sticker_extra_credit = true },

	loc_vars = function(self, info_queue, card)
		local num, denom = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "j_mp_starfruit_sandbox")
		return { vars = { card.ability.extra.uses, num, denom } }
	end,

	calculate = function(self, card, context)
		if context.cardarea == G.jokers and G.GAME.current_round.hands_played == 0 and context.before then
			if SMODS.pseudorandom_probability(card, "j_mp_starfruit_sandbox", 1, card.ability.extra.odds) then
				local text = context.scoring_name
				card_eval_status_text(
					context.blueprint_card or card,
					"extra",
					nil,
					nil,
					nil,
					{ message = localize("k_level_up_ex") }
				)
				update_hand_text({ sound = "button", volume = 0.7, pitch = 0.8, delay = 0.3 }, {
					handname = localize(text, "poker_hands"),
					chips = G.GAME.hands[text].chips,
					mult = G.GAME.hands[text].mult,
					level = G.GAME.hands[text].level,
				})
				level_up_hand(context.blueprint_card or card, text, nil, 1)
			end

			if not context.blueprint then
				card.ability.extra.uses = card.ability.extra.uses - 1
				if card.ability.extra.uses <= 0 then
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
