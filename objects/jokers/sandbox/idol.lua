SMODS.Atlas({
	key = "idol_sandbox_zealot",
	path = "j_idol_sandbox_bw.png",
	px = 71,
	py = 95,
})

-- Override reset_idol_card to do weighted rank selection for Zealot Idol
-- Runs globally for all players so the pseudorandom queue stays in sync
local original_reset_idol_card = reset_idol_card
function reset_idol_card()
	original_reset_idol_card()

	G.GAME.current_round.zealot_idol = { id = 14, rank = "Ace" }

	if G.playing_cards == nil then return end

	local count_map = {}
	local valid_ranks = {}

	for _, v in ipairs(G.playing_cards) do
		if v.ability.effect ~= "Stone Card" then
			local val = v.base.value
			if not count_map[val] then
				count_map[val] = { count = 0, card = v }
				table.insert(valid_ranks, count_map[val])
			end
			count_map[val].count = count_map[val].count + 1
		end
	end

	if #valid_ranks == 0 then return end

	local value_order = {}
	for i, rank in ipairs(SMODS.Rank.obj_buffer) do
		value_order[rank] = i
	end

	table.sort(valid_ranks, function(a, b)
		if a.count ~= b.count then return a.count > b.count end
		return value_order[a.card.base.value] < value_order[b.card.base.value]
	end)

	local total_weight = 0
	for _, entry in ipairs(valid_ranks) do
		total_weight = total_weight + entry.count
	end

	local raw_random = pseudorandom("zealot_idol" .. G.GAME.round_resets.ante)
	local threshold = 0
	for _, entry in ipairs(valid_ranks) do
		threshold = threshold + (entry.count / total_weight)
		if raw_random < threshold then
			G.GAME.current_round.zealot_idol = { id = entry.card.base.id, rank = entry.card.base.value }
			return
		end
	end

	G.GAME.current_round.zealot_idol = { id = valid_ranks[1].card.base.id, rank = valid_ranks[1].card.base.value }
end

SMODS.Joker({
	key = "idol_sandbox_zealot",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 2,
	cost = 6,
	atlas = "idol_sandbox_zealot",
	config = { extra = { xmult = 1.5 }, mp_balanced = true },
	add_to_deck = function(self, card, from_debuff)
		G.GAME.banned_keys["j_mp_idol_sandbox_collector"] = true
		if G.shop_jokers and G.shop_jokers.cards then
			for i = #G.shop_jokers.cards, 1, -1 do
				local shop_card = G.shop_jokers.cards[i]
				if shop_card.config.center.key == "j_mp_idol_sandbox_collector" then
					shop_card.T.r = -0.2
					shop_card:juice_up(0.3, 0.4)
					shop_card:start_dissolve()
					break
				end
			end
		end
	end,
	loc_vars = function(self, info_queue, card)
		local zealot = G.GAME.current_round.zealot_idol or { rank = "Ace" }
		return {
			vars = {
				localize(zealot.rank, "ranks"),
				card.ability.extra.xmult,
			},
		}
	end,
	calculate = function(self, card, context)
		local zealot = G.GAME.current_round.zealot_idol
		if
			zealot
			and context.individual
			and context.cardarea == G.play
			and context.other_card:get_id() == zealot.id
		then
			return {
				xmult = card.ability.extra.xmult,
			}
		end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})

SMODS.Atlas({
	key = "idol_sandbox_collector",
	path = "j_idol_sandbox_color.png",
	px = 71,
	py = 95,
})

local function get_most_common_card()
	local count_map = {}
	local valid_idol_cards = {}

	if G.playing_cards == nil then return { id = 14, rank = "Ace", suit = "Spades", count = 1 } end

	for _, v in ipairs(G.playing_cards) do
		if v.ability.effect ~= "Stone Card" then
			local key = v.base.value .. "_" .. v.base.suit
			if not count_map[key] then
				count_map[key] = { count = 0, card = v }
				table.insert(valid_idol_cards, count_map[key])
			end
			count_map[key].count = count_map[key].count + 1
		end
	end

	if #valid_idol_cards == 0 then return { id = 14, rank = "Ace", suit = "Spades", count = 0 } end

	-- Sort by count descending first, then by suit/value for consistency
	local value_order = {}
	for i, rank in ipairs(SMODS.Rank.obj_buffer) do
		value_order[rank] = i
	end

	local suit_order = {}
	for i, suit in ipairs(SMODS.Suit.obj_buffer) do
		suit_order[suit] = i
	end

	table.sort(valid_idol_cards, function(a, b)
		if a.count ~= b.count then return a.count > b.count end
		local a_suit = a.card.base.suit
		local b_suit = b.card.base.suit
		if suit_order[a_suit] ~= suit_order[b_suit] then return suit_order[a_suit] < suit_order[b_suit] end
		local a_value = a.card.base.value
		local b_value = b.card.base.value
		return value_order[a_value] < value_order[b_value]
	end)

	-- Return the most common card
	local most_common = valid_idol_cards[1]
	return {
		id = most_common.card.base.id,
		rank = most_common.card.base.value,
		suit = most_common.card.base.suit,
		count = most_common.count,
	}
end

SMODS.Joker({
	key = "idol_sandbox_collector",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 2,
	cost = 6,
	atlas = "idol_sandbox_collector",
	config = { extra = { xmult = 1.0, xmult_per_card = 0.05 }, mp_balanced = true },
	add_to_deck = function(self, card, from_debuff)
		G.GAME.banned_keys["j_mp_idol_sandbox_zealot"] = true
		if G.shop_jokers and G.shop_jokers.cards then
			for i = #G.shop_jokers.cards, 1, -1 do
				local shop_card = G.shop_jokers.cards[i]
				if shop_card.config.center.key == "j_mp_idol_sandbox_zealot" then
					shop_card.T.r = -0.2
					shop_card:juice_up(0.3, 0.4)
					shop_card:start_dissolve()
					break
				end
			end
		end
	end,
	loc_vars = function(self, info_queue, card)
		local most_common_card = get_most_common_card()
		local xmult = card.ability.extra.xmult + card.ability.extra.xmult_per_card * most_common_card.count
		return {
			vars = {
				localize(most_common_card.rank, "ranks"),
				localize(most_common_card.suit, "suits_plural"),
				xmult,
				card.ability.extra.xmult_per_card,
				colours = { G.C.SUITS[most_common_card.suit] },
			},
		}
	end,
	calculate = function(self, card, context)
		local most_common_card = get_most_common_card()
		if
			context.individual
			and context.cardarea == G.play
			and context.other_card:get_id() == most_common_card.id
			and context.other_card:is_suit(most_common_card.suit)
		then
			return {
				xmult = card.ability.extra.xmult + card.ability.extra.xmult_per_card * most_common_card.count,
			}
		end
	end,
	mp_credits = { code = { "steph" }, idea = { "Fantom" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
