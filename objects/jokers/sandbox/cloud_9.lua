SMODS.Atlas({
	key = "cloud_9_sandbox",
	path = "j_cloud_9_sandbox.png",
	px = 71,
	py = 95,
})

local function calculate_cloud_9_bonus(card)
	local nine_tally = 0
	if G.playing_cards ~= nil then
		for k, v in pairs(G.playing_cards) do
			if v:get_id() == 9 then nine_tally = nine_tally + 1 end
		end
	end

	local base_bonus = math.min(nine_tally, 4)
	local excess_nines = math.max(nine_tally - 4, 0)
	local multiplied_bonus = excess_nines * card.ability.extra.money

	return base_bonus + multiplied_bonus
end

SMODS.Joker({
	key = "cloud_9_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	perishable_compat = true,
	eternal_compat = true,
	rarity = 2,
	cost = 7,
	atlas = "cloud_9_sandbox",
	config = { extra = { money = 2, odds = 4 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		local numerator, denominator =
			SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "j_mp_cloud_9_sandbox")

		return {
			vars = {
				numerator,
				denominator,
				calculate_cloud_9_bonus(card),
			},
		}
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
	calc_dollar_bonus = function(self, card)
		return calculate_cloud_9_bonus(card)
	end,
	calculate = function(self, card, context)
		if context.individual and context.cardarea == G.play and not context.other_card.debuff then
			if SMODS.pseudorandom_probability(card, "j_mp_cloud_9_sandbox", 1, card.ability.extra.odds) then
				SMODS.modify_rank(context.other_card, 9 - context.other_card:get_id())
				play_sound("card1", 1)
				context.other_card:juice_up(0.3, 0.3)
			end
		end
	end,
})
