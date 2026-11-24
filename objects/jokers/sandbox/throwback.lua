local function calculate_total_mult(card)
	return 1 + (G.GAME.skips * card.ability.extra.base_mult) + card.ability.extra.owned_skip_mult
end

local function apply_skip_bonus(card)
	card.ability.extra.owned_skip_mult = card.ability.extra.owned_skip_mult + card.ability.extra.skip_bonus
	local total_mult = calculate_total_mult(card)
	return {
		message = localize({
			type = "variable",
			key = "a_xmult",
			vars = { total_mult },
		}),
	}
end

local function apply_round_penalty(card)
	local prev_mult = card.ability.extra.owned_skip_mult
	card.ability.extra.owned_skip_mult =
		math.max(0, card.ability.extra.owned_skip_mult - card.ability.extra.round_penalty)
	if prev_mult > card.ability.extra.owned_skip_mult then
		return {
			message = localize({
				type = "variable",
				key = "a_xmult_minus",
				vars = { card.ability.extra.round_penalty },
			}),
			colour = G.C.RED,
		}
	end
end

SMODS.Atlas({
	key = "throwback_sandbox",
	path = "j_throwback_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "throwback_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 2,
	cost = 6,
	atlas = "throwback_sandbox",
	config = {
		extra = {
			base_mult = 0.25,
			skip_bonus = 0.75,
			round_penalty = 0.75,
			owned_skip_mult = 0,
			skipped_this_round = false,
		},
		mp_balanced = true,
	},
	loc_vars = function(self, info_queue, card)
		return {
			vars = {
				calculate_total_mult(card),
				card.ability.extra.base_mult,
				card.ability.extra.skip_bonus,
				card.ability.extra.round_penalty,
			},
		}
	end,
	calculate = function(self, card, context)
		if context.skip_blind and not context.blueprint then
			card.ability.extra.skipped_this_round = true
			return apply_skip_bonus(card)
		end
		if context.end_of_round and context.game_over == false and context.main_eval and not context.blueprint then
			if not card.ability.extra.skipped_this_round then
				return apply_round_penalty(card)
			else
				card.ability.extra.skipped_this_round = false
			end
		end
		if context.joker_main then
			local total_mult = calculate_total_mult(card)
			return {
				xmult = total_mult,
			}
		end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
