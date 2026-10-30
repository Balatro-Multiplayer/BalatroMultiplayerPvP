SMODS.Atlas({
	key = "conjoined_joker",
	path = "j_conjoined_joker.png",
	px = 71,
	py = 95,
})

MPAPI.Joker({
	key = "conjoined_joker",
	atlas = "conjoined_joker",
	rarity = 2,
	cost = 6,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = true,
	config = { extra = { x_mult_gain = 0.5, max_x_mult = 3, x_mult = 1 } },
	-- Shows a display-only copy on the opponent's board (framework wires add/remove_from_deck).
	phantom = true,
	loc_vars = function(self, info_queue, card)
		PVP.UTILS.add_nemesis_info(info_queue)
		return { vars = { card.ability.extra.x_mult_gain, card.ability.extra.max_x_mult, card.ability.extra.x_mult } }
	end,
	mp_include = function(self)
		return MPAPI.mod_isolation_active(PVP.id) and not PVP.is_layer_active(PVP.LayerKey.SANDBOX)
	end,
	update = function(self, card, dt)
		if PVP.LOBBY.code then
			if G.STAGE == G.STAGES.RUN then
				card.ability.extra.x_mult = math.max(
					math.min(1 + (PVP.GAME.enemy.hands * card.ability.extra.x_mult_gain), card.ability.extra.max_x_mult),
					1
				)
			end
		else
			card.ability.extra.x_mult = 1
		end
	end,
	calculate = function(self, card, context)
		if
			context.cardarea == G.jokers
			and context.joker_main
			and PVP.is_pvp_boss()
			and not PVP.is_phantom(card)
		then
			return {
				x_mult = card.ability.extra.x_mult,
			}
		end
	end,
	mp_credits = {
		idea = { "Zilver" },
		art = { "Nas4xou" },
		code = { "Virtualized" },
	},
})
