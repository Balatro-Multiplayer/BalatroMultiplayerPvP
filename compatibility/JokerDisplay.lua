if SMODS.Mods["JokerDisplay"] and SMODS.Mods["JokerDisplay"].can_load then
	if JokerDisplay then
		local jd_def = JokerDisplay.Definitions
		jd_def["j_mp_conjoined_joker"] = {
			text = {
				{
					border_nodes = {
						{ text = "X" },
						{ ref_table = "card.joker_display_values", ref_value = "x_mult" },
					},
				},
			},
			calc_function = function(card)
				card.joker_display_values.x_mult = PVP.is_pvp_boss() and card.ability.extra.x_mult or 1
			end,
		}
		jd_def["j_mp_defensive_joker"] = {
			text = {
				{ text = "+" },
				{ ref_table = "card.joker_display_values", ref_value = "chips", retrigger_type = "mult" },
			},
			text_config = { colour = G.C.CHIPS },
			calc_function = function(card)
				card.joker_display_values.chips = card.ability.t_chips
			end,
		}
		jd_def["j_mp_lets_go_gambling"] = {
			text = {
				{
					border_nodes = {
						{ text = "X" },
						{ ref_table = "card.ability.extra", ref_value = "xmult" },
					},
				},
				{ text = " " },
				{ text = "$", colour = G.C.GOLD },
				{ ref_table = "card.ability.extra", ref_value = "dollars", colour = G.C.GOLD },
			},
			extra = {
				{
					{ text = "(" },
					{ ref_table = "card.joker_display_values", ref_value = "odds" },
					{ text = ")" },
				},
			},
			extra_config = { colour = G.C.GREEN, scale = 0.3 },
			calc_function = function(card)
				card.joker_display_values.odds = localize({
					type = "variable",
					key = "jdis_odds",
					vars = { SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "j_mp_lets_go_gambling") },
				})
			end,
		}
		jd_def["j_mp_magnet_sandbox"] = {
			reminder_text = {
				{ text = "(" },
				{ ref_table = "card.joker_display_values", ref_value = "active" },
				{ text = ")" },
			},
			calc_function = function(card)
				card.joker_display_values.active = card.ability.extra.current_rounds >= card.ability.extra.rounds
						and localize("k_active")
					or (card.ability.extra.current_rounds .. "/" .. card.ability.extra.rounds)
			end,
		}
		jd_def["j_mp_pacifist"] = {
			text = {
				{
					border_nodes = {
						{ text = "X" },
						{ ref_table = "card.joker_display_values", ref_value = "x_mult" },
					},
				},
			},
			calc_function = function(card)
				card.joker_display_values.x_mult = not PVP.is_pvp_boss() and card.ability.extra.x_mult or 1
			end,
		}
		jd_def["j_mp_pizza"] = {
			text = {
				{ text = "+", colour = G.C.RED },
				{ ref_table = "card.ability.extra", ref_value = "discards", colour = G.C.RED },
			},
		}
		jd_def["j_mp_skip_off"] = {
			text = {
				{ text = "+", colour = G.C.BLUE },
				{ ref_table = "card.ability.extra", ref_value = "hands", colour = G.C.BLUE },
				{ text = " " },
				{ text = "+", colour = G.C.RED },
				{ ref_table = "card.ability.extra", ref_value = "discards", colour = G.C.RED },
			},
			extra = {
				{ text = "(" },
				{ ref_table = "card.joker_display_values", ref_value = "skip_diff" },
				{ text = ")" },
			},
			calc_function = function(card)
				card.joker_display_values.skip_diff = G.GAME.skips ~= nil
						and PVP.GAME.enemy.skips ~= nil
						and localize({
							type = "variable",
							key = PVP.GAME.enemy.skips > G.GAME.skips and "a_mp_skips_behind"
								or PVP.GAME.enemy.skips == G.GAME.skips and "a_mp_skips_tied"
								or "a_mp_skips_ahead",
							vars = { math.abs(PVP.GAME.enemy.skips - G.GAME.skips) },
						})[1]
					or ""
			end,
		}
		jd_def["j_mp_taxes"] = {
			text = {
				{ text = "+", colour = G.C.RED },
				{ ref_table = "card.ability.extra", ref_value = "mult", colour = G.C.RED, retrigger_type = "mult" },
			},
		}
		jd_def["j_mp_hanging_chad"] = {
			retrigger_function = function(playing_card, scoring_hand, held_in_hand, joker_card)
				if held_in_hand then return 0 end
				local sorted_cards = JokerDisplay.sort_cards(scoring_hand)
				local first_card = sorted_cards and sorted_cards[1]
				local second_card = sorted_cards and sorted_cards[2]
				local retriggers = (
					(
						first_card
						and playing_card == first_card
						and joker_card.ability.extra * JokerDisplay.calculate_joker_triggers(joker_card)
					) or 0
				)
					+ (
						(
							second_card
							and playing_card == second_card
							and joker_card.ability.extra * JokerDisplay.calculate_joker_triggers(joker_card)
						) or 0
					)
				return retriggers
			end,
		}
		jd_def["j_mp_ticket"] = {
			text = {
				{ text = "+$" },
				{ ref_table = "card.joker_display_values", ref_value = "dollars", retrigger_type = "mult" },
			},
			text_config = { colour = G.C.GOLD },
			reminder_text = {
				{ text = "(" },
				{ ref_table = "card.joker_display_values", ref_value = "localized_text", colour = G.C.ORANGE },
				{ text = ")" },
			},
			calc_function = function(card)
				local dollars = 0
				local text, _, scoring_hand = JokerDisplay.evaluate_hand()
				if text ~= "Unknown" then
					for _, scoring_card in pairs(scoring_hand) do
						if SMODS.has_enhancement(scoring_card, "m_gold") then
							dollars = dollars
								+ card.ability.extra.dollars
									* JokerDisplay.calculate_card_triggers(scoring_card, scoring_hand)
						end
					end
				end
				card.joker_display_values.dollars = dollars
				card.joker_display_values.localized_text = localize("k_gold")
			end,
		}
		jd_def["j_mp_seltzer"] = {
			reminder_text = {
				{ text = "(" },
				{ ref_table = "card.ability.extra", ref_value = "hands_left" },
				{ text = "/" },
				{ ref_table = "card.joker_display_values", ref_value = "start_count" },
				{ text = ")" },
			},
			calc_function = function(card)
				card.joker_display_values.start_count = card.joker_display_values.start_count
					or card.ability.extra.hands_left
			end,
			style_function = function(card, text, reminder_text, extra)
				local children = reminder_text and reminder_text.children
				if not children then return end
				local colour = (card.ability.extra.hands_left == 1) and G.C.RED or G.C.UI.TEXT_INACTIVE
				for i = 2, 4 do
					local child = children[i]
					if child then child.config.colour = colour end
				end
			end,
			retrigger_function = function(playing_card, scoring_hand, held_in_hand, joker_card)
				if held_in_hand then return 0 end
				return JokerDisplay.in_scoring(playing_card, scoring_hand)
					and JokerDisplay.calculate_joker_triggers(joker_card)
			end,
		}
		jd_def["j_mp_turtle_bean"] = {
			reminder_text = {
				{ text = "(" },
				{ ref_table = "card.ability.extra", ref_value = "h_size" },
				{ text = "/" },
				{ ref_table = "card.joker_display_values", ref_value = "start_count" },
				{ text = ")" },
			},
			reminder_text_config = { scale = 0.35 },
			calc_function = function(card)
				card.joker_display_values.start_count = card.joker_display_values.start_count
					or card.ability.extra.h_size
			end,
			style_function = function(card, text, reminder_text, extra)
				local children = reminder_text and reminder_text.children
				if not children then return end
				local colour = (card.ability.extra.h_size == 1) and G.C.RED or G.C.UI.TEXT_INACTIVE
				for i = 2, 4 do
					local child = children[i]
					if child then child.config.colour = colour end
				end
			end,
		}
		jd_def["j_mp_bloodstone"] = {
			text = {
				{ ref_table = "card.joker_display_values", ref_value = "count", retrigger_type = "mult" },
				{ text = "x", scale = 0.35 },
				{
					border_nodes = {
						{ text = "X" },
						{ ref_table = "card.ability.extra", ref_value = "Xmult" },
					},
				},
			},
			reminder_text = {
				{ text = "(" },
				{ ref_table = "card.joker_display_values", ref_value = "localized_text" },
				{ text = ")" },
			},
			extra = {
				{
					{ text = "(" },
					{ ref_table = "card.joker_display_values", ref_value = "odds" },
					{ text = ")" },
				},
			},
			extra_config = { colour = G.C.GREEN, scale = 0.3 },
			calc_function = function(card)
				local text, _, scoring_hand = JokerDisplay.evaluate_hand()
				local count = 0
				if text ~= "Unknown" then
					for _, scoring_card in pairs(scoring_hand) do
						if scoring_card:is_suit("Hearts") then
							count = count + JokerDisplay.calculate_card_triggers(scoring_card, scoring_hand)
						end
					end
				end
				card.joker_display_values.count = count
				local numerator, denominator = 1, card.ability.extra.odds
				if SMODS then
					numerator, denominator = SMODS.get_probability_vars(card, numerator, denominator, "bloodstone")
				end
				card.joker_display_values.odds = localize({
					type = "variable",
					key = "jdis_odds",
					vars = { numerator, denominator },
				})
				card.joker_display_values.localized_text = localize("Hearts", "suits_plural")
			end,
			style_function = function(card, text, reminder_text, extra)
				local suit_node = reminder_text and reminder_text.children and reminder_text.children[2]
				if suit_node then suit_node.config.colour = lighten(G.C.SUITS["Hearts"], 0.35) end
			end,
		}
	end
end
