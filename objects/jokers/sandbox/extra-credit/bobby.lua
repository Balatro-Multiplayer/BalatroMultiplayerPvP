SMODS.Joker({
	key = "bobby_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,

	rarity = 2,
	cost = 6,
	atlas = "ec_jokers_sandbox",
	pos = { x = 0, y = 3 },

	config = {
		extra = {
			hands = 2,
			discards = 4,
		},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.hands, card.ability.extra.discards } }
	end,

	calculate = function(self, card, context)
		if context.setting_blind and not (context.blueprint_card or card).getting_sliced then
			G.E_MANAGER:add_event(Event({
				func = function()
					if G.GAME.current_round.hands_left < 2 then
					elseif G.GAME.current_round.hands_left == 2 then
						ease_hands_played(-(card.ability.extra.hands / 2), true)
						ease_discard((card.ability.extra.discards / 2), true, true)
						card_eval_status_text(context.blueprint_card or card, "extra", nil, nil, nil, {
							message = "+" .. tostring(card.ability.extra.discards / 2) .. " " .. localize(
								"k_hud_discards"
							),
							colour = G.C.RED,
						})
					elseif G.GAME.current_round.hands_left > 2 then
						ease_hands_played(-card.ability.extra.hands, true)
						ease_discard(card.ability.extra.discards, true, true)
						card_eval_status_text(context.blueprint_card or card, "extra", nil, nil, nil, {
							message = "+" .. tostring(card.ability.extra.discards) .. " " .. localize("k_hud_discards"),
							colour = G.C.RED,
						})
					end
					return true
				end,
			}))
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "R3venantR3mnant" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
