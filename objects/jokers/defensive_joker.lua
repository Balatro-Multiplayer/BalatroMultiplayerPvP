SMODS.Atlas({
	key = "defensive_joker",
	path = "j_defensive_joker.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "defensive_joker",
	atlas = "defensive_joker",
	rarity = 1,
	cost = 4,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = true,
	config = { t_chips = 0, extra = { extra = 125, highstake = 75 } },
	loc_vars = function(self, info_queue, card)
		local chips = G.GAME.stake >= 6 and card.ability.extra.highstake or card.ability.extra.extra
		return { vars = { chips, card.ability.t_chips } }
	end,
	update = function(self, card, dt)
		if not PVP.LOBBY.code then
			card.ability.t_chips = 0
			return
		end

		if G.STAGE ~= G.STAGES.RUN then return end

		local chips = G.GAME.stake >= 6 and card.ability.extra.highstake or card.ability.extra.extra
		local enemy_lives = PVP.GAME.enemy.lives
		card.ability.t_chips = enemy_lives and math.max((enemy_lives - PVP.GAME.lives) * chips, 0) or 0
	end,
	calculate = function(self, card, context)
		if context.cardarea == G.jokers and context.joker_main then
			return {
				message = localize({
					type = "variable",
					key = "a_chips",
					vars = { card.ability.t_chips },
				}),
				chip_mod = card.ability.t_chips,
			}
		end
	end,
	mp_credits = {
		idea = { "didon't" },
		art = { "TheTrueRaven" },
		code = { "Virtualized" },
	},
})
