--- Divvy's Simulation for Balatro - _Vanilla.lua
--
-- The simulation functions for all of the vanilla Balatro jokers.

local FNSJ = FN.SIM.JOKERS

FNSJ.simulate_joker = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_greedy_joker = function(joker_obj, context)
	FN.SIM.JOKERS.add_suit_mult(joker_obj, context)
end
FNSJ.simulate_lusty_joker = function(joker_obj, context)
	FN.SIM.JOKERS.add_suit_mult(joker_obj, context)
end
FNSJ.simulate_wrathful_joker = function(joker_obj, context)
	FN.SIM.JOKERS.add_suit_mult(joker_obj, context)
end
FNSJ.simulate_gluttenous_joker = function(joker_obj, context)
	FN.SIM.JOKERS.add_suit_mult(joker_obj, context)
end
FNSJ.simulate_jolly = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_mult(joker_obj, context)
end
FNSJ.simulate_zany = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_mult(joker_obj, context)
end
FNSJ.simulate_mad = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_mult(joker_obj, context)
end
FNSJ.simulate_crazy = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_mult(joker_obj, context)
end
FNSJ.simulate_droll = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_mult(joker_obj, context)
end
FNSJ.simulate_sly = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_chips(joker_obj, context)
end
FNSJ.simulate_wily = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_chips(joker_obj, context)
end
FNSJ.simulate_clever = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_chips(joker_obj, context)
end
FNSJ.simulate_devious = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_chips(joker_obj, context)
end
FNSJ.simulate_crafty = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_chips(joker_obj, context)
end
FNSJ.simulate_half = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if #context.full_hand <= joker_obj.ability.extra.size then FN.SIM.add_mult(joker_obj.ability.extra.mult) end
	end
end
FNSJ.simulate_stencil = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local xmult = G.jokers.config.card_limit - #FN.SIM.env.jokers
		for _, joker in ipairs(FN.SIM.env.jokers) do
			if joker.ability.name == "Joker Stencil" then xmult = xmult + 1 end
		end
		if joker_obj.ability.x_mult > 1 then FN.SIM.x_mult(joker_obj.ability.x_mult) end
	end
end
FNSJ.simulate_four_fingers = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_mime = function(joker_obj, context)
	if context.cardarea == G.hand and context.repetition then FN.SIM.add_reps(joker_obj.ability.extra) end
end
FNSJ.simulate_credit_card = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_ceremonial = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_banner = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if G.GAME.current_round.discards_left > 0 then
			local chips = G.GAME.current_round.discards_left * joker_obj.ability.extra
			FN.SIM.add_chips(chips)
		end
	end
end
FNSJ.simulate_mystic_summit = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if G.GAME.current_round.discards_left == joker_obj.ability.extra.d_remaining then
			FN.SIM.add_mult(joker_obj.ability.extra.mult)
		end
	end
end
FNSJ.simulate_marble = function(joker_obj, context)
	-- Effect not relevant (Blind)
end
FNSJ.simulate_loyalty_card = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local loyalty_diff = G.GAME.hands_played - joker_obj.ability.hands_played_at_create
		local loyalty_remaining = ((joker_obj.ability.extra.every - 1) - loyalty_diff)
			% (joker_obj.ability.extra.every + 1)
		if loyalty_remaining == joker_obj.ability.extra.every then FN.SIM.x_mult(joker_obj.ability.extra.Xmult) end
	end
end
FNSJ.simulate_8_ball = function(joker_obj, context)
	-- Effect might be relevant?
end
FNSJ.simulate_misprint = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local exact_mult = pseudorandom("nope", joker_obj.ability.extra.min, joker_obj.ability.extra.max)
		FN.SIM.add_mult(exact_mult, joker_obj.ability.extra.min, joker_obj.ability.extra.max)
	end
end
FNSJ.simulate_dusk = function(joker_obj, context)
	if context.cardarea == G.play and context.repetition then
		-- Note: Checking against 1 is needed as hands_left is not decremented as part of simulation
		if G.GAME.current_round.hands_left == 1 then FN.SIM.add_reps(joker_obj.ability.extra) end
	end
end
FNSJ.simulate_raised_fist = function(joker_obj, context)
	if context.cardarea == G.hand and context.individual then
		local cur_mult, cur_rank = 15, 15
		local raised_card = nil
		for _, card in ipairs(FN.SIM.env.held_cards) do
			if cur_rank >= card.rank and card.ability.effect ~= "Stone Card" then
				cur_mult = card.base_chips
				cur_rank = card.rank
				raised_card = card
			end
		end
		if raised_card == context.other_card and not context.other_card.debuff then FN.SIM.add_mult(2 * cur_mult) end
	end
end
FNSJ.simulate_chaos = function(joker_obj, context)
	-- Effect not relevant (Free Reroll)
end
FNSJ.simulate_fibonacci = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_rank(context.other_card, { 2, 3, 5, 8, 14 }) and not context.other_card.debuff then
			FN.SIM.add_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_steel_joker = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		FN.SIM.x_mult(1 + joker_obj.ability.extra * joker_obj.ability.steel_tally)
	end
end
FNSJ.simulate_scary_face = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_face(context.other_card) and not context.other_card.debuff then
			FN.SIM.add_chips(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_abstract = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		FN.SIM.add_mult(#FN.SIM.env.jokers * joker_obj.ability.extra)
	end
end
FNSJ.simulate_delayed_grat = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_hack = function(joker_obj, context)
	if context.cardarea == G.play and context.repetition then
		if not context.other_card.debuff and FN.SIM.is_rank(context.other_card, { 2, 3, 4, 5 }) then
			FN.SIM.add_reps(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_pareidolia = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_gros_michel = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.extra.mult) end
end
FNSJ.simulate_even_steven = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if not context.other_card.debuff and FN.SIM.check_rank_parity(context.other_card, true) then
			FN.SIM.add_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_odd_todd = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if not context.other_card.debuff and FN.SIM.check_rank_parity(context.other_card, false) then
			FN.SIM.add_chips(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_scholar = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_rank(context.other_card, 14) and not context.other_card.debuff then
			FN.SIM.add_chips(joker_obj.ability.extra.chips)
			FN.SIM.add_mult(joker_obj.ability.extra.mult)
		end
	end
end
FNSJ.simulate_business = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_face(context.other_card) and not context.other_card.debuff then
			local exact_dollars, min_dollars, max_dollars, expected_dollars =
				FN.SIM.get_probabilistic_extremes(pseudorandom("false"), joker_obj.ability.extra, 2, 0)
			FN.SIM.add_dollars(exact_dollars, min_dollars, max_dollars, expected_dollars)
		end
	end
end
FNSJ.simulate_supernova = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		FN.SIM.add_mult(G.GAME.hands[context.scoring_name].played)
	end
end
FNSJ.simulate_ride_the_bus = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		local faces = false
		for _, scoring_card in ipairs(context.scoring_hand) do
			if FN.SIM.is_face(scoring_card) then faces = true end
		end
		if faces then
			joker_obj.ability.mult = 0
		else
			joker_obj.ability.mult = joker_obj.ability.mult + joker_obj.ability.extra
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_space = function(joker_obj, context)
	-- TODO: Verify
	if context.cardarea == G.jokers and context.before then
		local hand_data = G.GAME.hands[FN.SIM.env.scoring_name]

		local rand = pseudorandom("bad") -- Must reuse same pseudorandom value:
		local exact_chips, min_chips, max_chips =
			FN.SIM.get_probabilistic_extremes(rand, joker_obj.ability.extra, hand_data.l_chips, 0)
		local exact_mult, min_mult, max_mult =
			FN.SIM.get_probabilistic_extremes(rand, joker_obj.ability.extra, hand_data.l_mult, 0)

		FN.SIM.add_chips(exact_chips, min_chips, max_chips)
		FN.SIM.add_mult(exact_mult, min_mult, max_mult)
	end
end
FNSJ.simulate_egg = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_burglar = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_blackboard = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local black_suits, all_cards = 0, 0
		for _, card in ipairs(FN.SIM.env.held_cards) do
			all_cards = all_cards + 1
			if FN.SIM.is_suit(card, "Clubs", true) or FN.SIM.is_suit(card, "Spades", true) then
				black_suits = black_suits + 1
			end
		end
		if black_suits == all_cards then FN.SIM.x_mult(joker_obj.ability.extra) end
	end
end
FNSJ.simulate_runner = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		if next(context.poker_hands["Straight"]) then
			joker_obj.ability.extra.chips = joker_obj.ability.extra.chips + joker_obj.ability.extra.chip_mod
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chips) end
end
FNSJ.simulate_ice_cream = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chips) end
end
FNSJ.simulate_dna = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before then
		if G.GAME.current_round.hands_played == 0 and #context.full_hand == 1 then
			local new_card = copy_table(context.full_hand[1])
			table.insert(FN.SIM.env.held_cards, new_card)
		end
	end
end
FNSJ.simulate_splash = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_blue_joker = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		FN.SIM.add_chips(joker_obj.ability.extra * #G.deck.cards)
	end
end
FNSJ.simulate_sixth_sense = function(joker_obj, context)
	-- Effect might be relevant?
end
FNSJ.simulate_constellation = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_hiker = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if not context.other_card.debuff then
			context.other_card.ability.perma_bonus = (context.other_card.ability.perma_bonus or 0)
				+ joker_obj.ability.extra
		end
	end
end
FNSJ.simulate_faceless = function(joker_obj, context)
	-- Effect not relevant (Discard)
end
FNSJ.simulate_green_joker = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		joker_obj.ability.mult = joker_obj.ability.mult + joker_obj.ability.extra.hand_add
	end
	if
		context.cardarea == G.hand
		and context.discard
		and context.other_card == context.cards[1]
		and not context.blueprint
	then
		joker_obj.ability.mult = math.max(0, joker_obj.ability.mult - joker_obj.ability.extra.discard_sub)
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_superposition = function(joker_obj, context)
	-- Effect might be relevant?
end
FNSJ.simulate_todo_list = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before then
		if context.scoring_name == joker_obj.ability.to_do_poker_hand then
			FN.SIM.add_dollars(joker_obj.ability.extra.dollars)
		end
	end
end
FNSJ.simulate_cavendish = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.x_mult(joker_obj.ability.extra.Xmult) end
end
FNSJ.simulate_card_sharp = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if G.GAME.hands[context.scoring_name] and G.GAME.hands[context.scoring_name].played_this_round > 1 then
			FN.SIM.x_mult(joker_obj.ability.extra.Xmult)
		end
	end
end
FNSJ.simulate_red_card = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_madness = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_square = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		if #context.full_hand == 4 then
			joker_obj.ability.extra.chips = joker_obj.ability.extra.chips + joker_obj.ability.extra.chip_mod
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chips) end
end
FNSJ.simulate_seance = function(joker_obj, context)
	-- Effect might be relevant? (Consumable)
end
FNSJ.simulate_riff_raff = function(joker_obj, context)
	-- Effect not relevant (Blind)
end
FNSJ.simulate_vampire = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		local num_enhanced = 0
		for _, card in ipairs(context.scoring_hand) do
			if card.ability.name ~= "Default Base" and not card.debuff then
				num_enhanced = num_enhanced + 1
				FN.SIM.set_ability(card, G.P_CENTERS.c_base)
			end
		end
		if num_enhanced > 0 then
			joker_obj.ability.x_mult = joker_obj.ability.x_mult + (joker_obj.ability.extra * num_enhanced)
		end
	end

	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_shortcut = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_hologram = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_vagabond = function(joker_obj, context)
	-- Effect might be relevant? (Consumable)
end
FNSJ.simulate_baron = function(joker_obj, context)
	if context.cardarea == G.hand and context.individual then
		if FN.SIM.is_rank(context.other_card, 13) and not context.other_card.debuff then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_cloud_9 = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_rocket = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_obelisk = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		local reset = true
		local play_more_than = (G.GAME.hands[context.scoring_name].played or 0)
		for hand_name, hand in pairs(G.GAME.hands) do
			if hand_name ~= context.scoring_name and hand.played >= play_more_than and hand.visible then
				reset = false
			end
		end
		if reset then
			joker_obj.ability.x_mult = 1
		else
			joker_obj.ability.x_mult = joker_obj.ability.x_mult + joker_obj.ability.extra
		end
	end
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_midas_mask = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		for _, card in ipairs(context.scoring_hand) do
			if FN.SIM.is_face(card) then FN.SIM.set_ability(card, G.P_CENTERS.m_gold) end
		end
	end
end
FNSJ.simulate_luchador = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_photograph = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		local first_face = nil
		for i = 1, #context.scoring_hand do
			if FN.SIM.is_face(context.scoring_hand[i]) then
				first_face = context.scoring_hand[i]
				break
			end
		end
		if context.other_card == first_face and not context.other_card.debuff then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_gift = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_turtle_bean = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_erosion = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local diff = G.GAME.starting_deck_size - #G.playing_cards
		if diff > 0 then FN.SIM.add_mult(joker_obj.ability.extra * diff) end
	end
end
FNSJ.simulate_reserved_parking = function(joker_obj, context)
	if context.cardarea == G.hand and context.individual then
		if FN.SIM.is_face(context.other_card) and not context.other_card.debuff then
			local exact_dollars, min_dollars, max_dollars, expected_dollars = FN.SIM.get_probabilistic_extremes(
				pseudorandom("notthistime"),
				joker_obj.ability.extra.odds,
				joker_obj.ability.extra.dollars,
				0
			)
			FN.SIM.add_dollars(exact_dollars, min_dollars, max_dollars, expected_dollars)
		end
	end
end
FNSJ.simulate_mail = function(joker_obj, context)
	if context.cardarea == G.hand and context.discard then
		if context.other_card.id == G.GAME.current_round.mail_card.id and not context.other_card.debuff then
			FN.SIM.add_dollars(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_to_the_moon = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_hallucination = function(joker_obj, context)
	-- Effect not relevant (Outside of Play)
end
FNSJ.simulate_fortune_teller = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if G.GAME.consumeable_usage_total and G.GAME.consumeable_usage_total.tarot then
			FN.SIM.add_mult(G.GAME.consumeable_usage_total.tarot)
		end
	end
end
FNSJ.simulate_juggler = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_drunkard = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_stone = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		FN.SIM.add_chips(joker_obj.ability.extra * joker_obj.ability.stone_tally)
	end
end
FNSJ.simulate_golden = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_lucky_cat = function(joker_obj, context)
	if not joker_obj.ability.x_mult_range then
		joker_obj.ability.x_mult_range = {
			min = joker_obj.ability.x_mult,
			exact = joker_obj.ability.x_mult,
			max = joker_obj.ability.x_mult,
		}
	end

	if context.cardarea == G.play and context.individual and not context.blueprint then
		local function lucky_cat(field)
			if context.other_card.lucky_trigger and context.other_card.lucky_trigger[field] then
				joker_obj.ability.x_mult_range[field] = joker_obj.ability.x_mult_range[field] + joker_obj.ability.extra
				if joker_obj.ability.x_mult_range[field] < 1 then joker_obj.ability.x_mult_range[field] = 1 end -- Precaution
			end
		end
		lucky_cat("min")
		lucky_cat("exact")
		lucky_cat("max")
	end

	if context.cardarea == G.jokers and context.global then
		FN.SIM.x_mult(
			joker_obj.ability.x_mult_range.exact,
			joker_obj.ability.x_mult_range.min,
			joker_obj.ability.x_mult_range.max
		)
	end
end
FNSJ.simulate_baseball = function(joker_obj, context)
	if context.cardarea == G.jokers and context.other_joker then
		if context.other_joker.rarity == 2 and context.other_joker ~= joker_obj then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_bull = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local function bull(data)
			return joker_obj.ability.extra * math.max(0, G.GAME.dollars + data.dollars)
		end
		local min_chips = bull(FN.SIM.running.min)
		local exact_chips = bull(FN.SIM.running.exact)
		local max_chips = bull(FN.SIM.running.max)
		FN.SIM.add_chips(exact_chips, min_chips, max_chips)
	end
end
FNSJ.simulate_diet_cola = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_trading = function(joker_obj, context)
	-- Effect not relevant (Discard)
end
FNSJ.simulate_flash = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_popcorn = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_trousers = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		if next(context.poker_hands["Two Pair"]) or next(context.poker_hands["Full House"]) then
			joker_obj.ability.mult = joker_obj.ability.mult + joker_obj.ability.extra
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_ancient = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if
			FN.SIM.is_suit(context.other_card, G.GAME.current_round.ancient_card.suit)
			and not context.other_card.debuff
		then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_ramen = function(joker_obj, context)
	if context.cardarea == G.hand and context.discard then
		joker_obj.ability.x_mult = math.max(1, joker_obj.ability.x_mult - joker_obj.ability.extra)
	end
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_walkie_talkie = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_rank(context.other_card, { 10, 4 }) and not context.other_card.debuff then
			FN.SIM.add_chips(joker_obj.ability.extra.chips)
			FN.SIM.add_mult(joker_obj.ability.extra.mult)
		end
	end
end
FNSJ.simulate_selzer = function(joker_obj, context)
	if context.cardarea == G.play and context.repetition then FN.SIM.add_reps(1) end
end
FNSJ.simulate_castle = function(joker_obj, context)
	if context.cardarea == G.hand and context.discard and not context.blueprint then
		if
			FN.SIM.is_suit(context.other_card, G.GAME.current_round.castle_card.suit) and not context.other_card.debuff
		then
			joker_obj.ability.extra.chips = joker_obj.ability.extra.chips + joker_obj.ability.extra.chip_mod
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chips) end
end
FNSJ.simulate_smiley = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_face(context.other_card) and not context.other_card.debuff then
			FN.SIM.add_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_campfire = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_ticket = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if context.other_card.ability.effect == "Gold Card" and not context.other_card.debuff then
			FN.SIM.add_dollars(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_mr_bones = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_acrobat = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		-- Note: Checking against 1 is needed as hands_left is not decremented as part of simulation
		if G.GAME.current_round.hands_left == 1 then FN.SIM.x_mult(joker_obj.ability.extra) end
	end
end
FNSJ.simulate_sock_and_buskin = function(joker_obj, context)
	if context.cardarea == G.play and context.repetition then
		if FN.SIM.is_face(context.other_card) and not context.other_card.debuff then
			FN.SIM.add_reps(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_swashbuckler = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_troubadour = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_certificate = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_smeared = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_throwback = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_hanging_chad = function(joker_obj, context)
	if joker_obj.ability.extra == 1 then
		if context.cardarea == G.play and context.repetition then
			if context.other_card == context.scoring_hand[1] and not context.other_card.debuff then
				FN.SIM.add_reps(joker_obj.ability.extra)
			end
			if context.other_card == context.scoring_hand[2] and not context.other_card.debuff then
				FN.SIM.add_reps(joker_obj.ability.extra)
			end
		end
	else
		if context.cardarea == G.play and context.repetition then
			if context.other_card == context.scoring_hand[1] and not context.other_card.debuff then
				FN.SIM.add_reps(joker_obj.ability.extra)
			end
		end
	end
end
FNSJ.simulate_rough_gem = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_suit(context.other_card, "Diamonds") and not context.other_card.debuff then
			FN.SIM.add_dollars(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_bloodstone = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_suit(context.other_card, "Hearts") and not context.other_card.debuff then
			local exact_xmult, min_xmult, max_xmult = FN.SIM.get_probabilistic_extremes(
				pseudorandom("nopeagain"),
				joker_obj.ability.extra.odds,
				joker_obj.ability.extra.Xmult,
				1
			)
			FN.SIM.x_mult(exact_xmult, min_xmult, max_xmult)
		end
	end
end
FNSJ.simulate_arrowhead = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_suit(context.other_card, "Spades") and not context.other_card.debuff then
			FN.SIM.add_chips(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_onyx_agate = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_suit(context.other_card, "Clubs") and not context.other_card.debuff then
			FN.SIM.add_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_glass = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_ring_master = function(joker_obj, context)
	-- Effect not relevant (Note: this is actually Showman)
end
FNSJ.simulate_flower_pot = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local suit_count = {
			["Hearts"] = 0,
			["Diamonds"] = 0,
			["Spades"] = 0,
			["Clubs"] = 0,
		}

		function inc_suit(suit)
			suit_count[suit] = suit_count[suit] + 1
		end

		-- Account for all 'real' suits.
		-- NOTE: Debuffed (non-wild) cards are still counted for their suits
		for _, card in ipairs(context.scoring_hand) do
			if card.ability.effect ~= "Wild Card" then
				if FN.SIM.is_suit(card, "Hearts", true) and suit_count["Hearts"] == 0 then
					inc_suit("Hearts")
				elseif FN.SIM.is_suit(card, "Diamonds", true) and suit_count["Diamonds"] == 0 then
					inc_suit("Diamonds")
				elseif FN.SIM.is_suit(card, "Spades", true) and suit_count["Spades"] == 0 then
					inc_suit("Spades")
				elseif FN.SIM.is_suit(card, "Clubs", true) and suit_count["Clubs"] == 0 then
					inc_suit("Clubs")
				end
			end
		end

		-- Let Wild Cards fill in the gaps.
		-- NOTE: Debuffed wild cards are completely ignored
		for _, card in ipairs(context.scoring_hand) do
			if card.ability.effect == "Wild Card" then
				if FN.SIM.is_suit(card, "Hearts") and suit_count["Hearts"] == 0 then
					inc_suit("Hearts")
				elseif FN.SIM.is_suit(card, "Diamonds") and suit_count["Diamonds"] == 0 then
					inc_suit("Diamonds")
				elseif FN.SIM.is_suit(card, "Spades") and suit_count["Spades"] == 0 then
					inc_suit("Spades")
				elseif FN.SIM.is_suit(card, "Clubs") and suit_count["Clubs"] == 0 then
					inc_suit("Clubs")
				end
			end
		end

		if
			suit_count["Hearts"] > 0
			and suit_count["Diamonds"] > 0
			and suit_count["Spades"] > 0
			and suit_count["Clubs"] > 0
		then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_blueprint = function(joker_obj, context)
	local joker_to_mimic = nil
	for idx, joker in ipairs(FN.SIM.env.jokers) do
		if joker == joker_obj then joker_to_mimic = FN.SIM.env.jokers[idx + 1] end
	end
	if joker_to_mimic then
		context.blueprint = (context.blueprint and (context.blueprint + 1)) or 1
		if context.blueprint > #FN.SIM.env.jokers + 1 then return end
		FN.SIM.simulate_joker(joker_to_mimic, context)
	end
end
FNSJ.simulate_wee = function(joker_obj, context)
	if context.cardarea == G.play and context.individual and not context.blueprint then
		if FN.SIM.is_rank(context.other_card, 2) and not context.other_card.debuff then
			joker_obj.ability.extra.chips = joker_obj.ability.extra.chips + joker_obj.ability.extra.chip_mod
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chips) end
end
FNSJ.simulate_merry_andy = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_oops = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_idol = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if
			FN.SIM.is_rank(context.other_card, G.GAME.current_round.idol_card.id)
			and FN.SIM.is_suit(context.other_card, G.GAME.current_round.idol_card.suit)
			and not context.other_card.debuff
		then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_seeing_double = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local suit_count = {
			["Hearts"] = 0,
			["Diamonds"] = 0,
			["Spades"] = 0,
			["Clubs"] = 0,
		}

		function inc_suit(suit)
			suit_count[suit] = suit_count[suit] + 1
		end

		-- Account for all 'real' suits:
		for _, card in ipairs(context.scoring_hand) do
			if card.ability.effect ~= "Wild Card" then
				if FN.SIM.is_suit(card, "Hearts") then inc_suit("Hearts") end
				if FN.SIM.is_suit(card, "Diamonds") then inc_suit("Diamonds") end
				if FN.SIM.is_suit(card, "Spades") then inc_suit("Spades") end
				if FN.SIM.is_suit(card, "Clubs") then inc_suit("Clubs") end
			end
		end

		-- Let Wild Cards fill in the gaps:
		for _, card in ipairs(context.scoring_hand) do
			if card.ability.effect == "Wild Card" then
				-- IMPORTANT: Clubs must come first here, because Clubs are required for xmult. This is in line with game's implementation.
				if FN.SIM.is_suit(card, "Clubs") and suit_count["Clubs"] == 0 then
					inc_suit("Clubs")
				elseif FN.SIM.is_suit(card, "Hearts") and suit_count["Hearts"] == 0 then
					inc_suit("Hearts")
				elseif FN.SIM.is_suit(card, "Diamonds") and suit_count["Diamonds"] == 0 then
					inc_suit("Diamonds")
				elseif FN.SIM.is_suit(card, "Spades") and suit_count["Spades"] == 0 then
					inc_suit("Spades")
				end
			end
		end

		if
			suit_count["Clubs"] > 0
			and (suit_count["Hearts"] > 0 or suit_count["Diamonds"] > 0 or suit_count["Spades"] > 0)
		then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_matador = function(joker_obj, context)
	if context.cardarea == G.jokers and context.debuffed_hand then
		if G.GAME.blind.triggered then FN.SIM.add_dollars(joker_obj.ability.extra) end
	end
end
FNSJ.simulate_hit_the_road = function(joker_obj, context)
	if context.cardarea == G.hand and context.discard and not context.blueprint then
		if FN.SIM.is_rank(context.other_card, 11) and not context.other_card.debuff then
			joker_obj.ability.x_mult = joker_obj.ability.x_mult + joker_obj.ability.extra
		end
	end
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_duo = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_trio = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_family = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_order = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_tribe = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_stuntman = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chip_mod) end
end
FNSJ.simulate_invisible = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_brainstorm = function(joker_obj, context)
	local joker_to_mimic = FN.SIM.env.jokers[1]
	if joker_to_mimic and joker_to_mimic ~= joker_obj then
		context.blueprint = (context.blueprint and (context.blueprint + 1)) or 1
		if context.blueprint > #FN.SIM.env.jokers + 1 then return end
		FN.SIM.simulate_joker(joker_to_mimic, context)
	end
end
FNSJ.simulate_satellite = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_shoot_the_moon = function(joker_obj, context)
	if context.cardarea == G.hand and context.individual then
		if FN.SIM.is_rank(context.other_card, 12) and not context.other_card.debuff then FN.SIM.add_mult(13) end
	end
end
FNSJ.simulate_drivers_license = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if (joker_obj.ability.driver_tally or 0) >= 16 then FN.SIM.x_mult(joker_obj.ability.extra) end
	end
end
FNSJ.simulate_cartomancer = function(joker_obj, context)
	-- Effect not relevant (Blind)
end
FNSJ.simulate_astronomer = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_burnt = function(joker_obj, context)
	-- Effect not relevant (Discard)
end
FNSJ.simulate_bootstraps = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local function bootstraps(data)
			return joker_obj.ability.extra.mult
				* math.floor((G.GAME.dollars + data.dollars) / joker_obj.ability.extra.dollars)
		end
		local min_mult = bootstraps(FN.SIM.running.min)
		local exact_mult = bootstraps(FN.SIM.running.exact)
		local max_mult = bootstraps(FN.SIM.running.max)
		FN.SIM.add_mult(exact_mult, min_mult, max_mult)
	end
end
FNSJ.simulate_caino = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if joker_obj.ability.caino_xmult > 1 then FN.SIM.x_mult(joker_obj.ability.caino_xmult) end
	end
end
FNSJ.simulate_triboulet = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_rank(context.other_card, { 12, 13 }) and not context.other_card.debuff then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_yorick = function(joker_obj, context)
	if context.cardarea == G.hand and context.discard and not context.blueprint then
		-- This is only necessary for 'The Hook' blind.
		if joker_obj.ability.yorick_discards > 1 then
			joker_obj.ability.yorick_discards = joker_obj.ability.yorick_discards - 1
		else
			joker_obj.ability.yorick_discards = joker_obj.ability.extra.discards
			joker_obj.ability.x_mult = joker_obj.ability.x_mult + joker_obj.ability.extra.xmult
		end
	end

	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_chicot = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_perkeo = function(joker_obj, context)
	-- Effect not relevant (Blind)
end
