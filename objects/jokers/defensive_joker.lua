SMODS.Atlas({
	key = "defensive_joker",
	path = "j_defensive_joker.png",
	px = 71,
	py = 95,
})

-- The warning for unknown lives is logged once per run (keyed by run id), not every frame.
local warned_unknown_lives = { done = false, run_id = nil }

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
		-- Unknown lives (either side) give no bonus; the first time is logged, except in
		-- practice, where the opponent's lives are always unknown.
		local enemy_lives, own_lives = PVP.GAME.enemy.lives, PVP.GAME.lives
		local run_id = PVP.current_run_id()
		local unknown = enemy_lives == nil or own_lives == nil
		if unknown and not PVP.is_practice_mode() and not (warned_unknown_lives.done and warned_unknown_lives.run_id == run_id) then
			warned_unknown_lives = { done = true, run_id = run_id }
			sendWarnMessage("[pvp] Defensive Joker: the lives are unknown, no bonus", "MULTIPLAYER")
		end
		card.ability.t_chips = PVP.defensive_bonus(enemy_lives, own_lives, chips)
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
