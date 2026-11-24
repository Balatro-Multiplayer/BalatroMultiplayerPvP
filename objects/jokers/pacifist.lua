SMODS.Atlas({
	key = "pacifist",
	path = "j_pacifist.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "pacifist",
	atlas = "pacifist",
	rarity = 1,
	cost = 4,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = true,
	config = { extra = { x_mult = 10 } },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.x_mult } }
	end,
	calculate = function(self, card, context)
		if context.cardarea == G.jokers and context.joker_main and not PVP.UTILS.is_pvp_blind() then
			return {
				x_mult = card.ability.extra.x_mult,
			}
		end
	end,
	mp_credits = {
		idea = { "Zilver" },
		art = { "zeathemays" },
		code = { "Virtualized" },
	},
})
