SMODS.Joker({
	key = "shipoftheseus_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = false,

	rarity = 3,
	cost = 9,
	atlas = "ec_jokers_sandbox",
	pos = { x = 7, y = 2 },

	config = {
		extra = {
			Xmult = 1,
			Xmult_mod = 0.4,
			tick = false,
		},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.Xmult, card.ability.extra.Xmult_mod } }
	end,

	calculate = function(self, card, context)
		if context.remove_playing_cards then
			card.ability.extra.tick = false
			for k, val in ipairs(context.removed) do
				if not context.blueprint then
					card.ability.extra.Xmult = card.ability.extra.Xmult + card.ability.extra.Xmult_mod
					card.ability.extra.tick = true
				end
				G.playing_card = (G.playing_card and G.playing_card + 1) or 1
				local _card = copy_card(val, nil, nil, G.playing_card)
				_card:add_to_deck()
				G.deck.config.card_limit = G.deck.config.card_limit + 1
				G.deck:emplace(_card)
				table.insert(G.playing_cards, _card)
				playing_card_joker_effects({ true })

				G.E_MANAGER:add_event(Event({
					func = function()
						_card:start_materialize()

						return true
					end,
				}))
				card_eval_status_text(
					context.blueprint_card or card,
					"extra",
					nil,
					nil,
					nil,
					{ message = localize("k_copied_ex"), colour = G.C.FILTER }
				)
			end

			if not context.blueprint and card.ability.extra.tick then
				delay(0.3)
				card_eval_status_text(card, "extra", nil, nil, nil, {
					message = localize({ type = "variable", key = "a_xmult", vars = { card.ability.extra.Xmult } }),
					colour = G.C.FILTER,
				})
			end
		elseif context.cardarea == G.jokers and context.joker_main and card.ability.extra.Xmult > 1 then
			return {
				message = localize({ type = "variable", key = "a_xmult", vars = { card.ability.extra.Xmult } }),
				Xmult_mod = card.ability.extra.Xmult,
			}
		end
	end,

	mp_credits = {
		code = { "CampfireCollective", "steph" },
		art = { "neatoqueen" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
