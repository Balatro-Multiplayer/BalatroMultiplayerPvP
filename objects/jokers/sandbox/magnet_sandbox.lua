SMODS.Atlas({
	key = "magnet",
	path = "j_magnet.png",
	px = 71,
	py = 95,
})

MPAPI.Joker({
	key = "magnet_sandbox",
	atlas = "magnet",
	rarity = 3,
	cost = 7,
	unlocked = true,
	discovered = true,
	no_collection = PVP.sandbox_no_collection,
	blueprint_compat = false,
	eternal_compat = false,
	perishable_compat = true,
	config = { extra = { rounds = 2, current_rounds = 0, max_rounds = 5 } },
	loc_vars = function(self, info_queue, card)
		PVP.UTILS.add_nemesis_info(info_queue)
		return {
			vars = {
				card.ability.extra.rounds,
				card.ability.extra.current_rounds,
				card.ability.extra.max_rounds,
			},
		}
	end,
	-- Shows a display-only copy on the opponent's board (framework wires add/remove_from_deck).
	phantom = true,
	-- Magnet steal: on sell, request a joker from the opponent. A "request" arriving in receive
	-- picks the opponent's highest-sell joker and replies with a "response"; a "response"
	-- arriving in receive rebuilds it into our own jokers. Was action_magnet / action_magnet_response.
	receive = function(self, context)
		local d = context.data
		if d.type == "request" then
			PVP.RLOG.record(MPAPI.OPCODE.NET_MAGNET, nil, "action:netMagnet")
			local best = nil
			for _, v in pairs(G.jokers.cards) do
				if not best or v.sell_cost > best.sell_cost then best = v end
			end
			if not best then return nil end
			local candidates = {}
			for _, v in pairs(G.jokers.cards) do
				if v.sell_cost == best.sell_cost then table.insert(candidates, v) end
			end
			local random_index = math.floor(pseudorandom("j_mp_magnet") * #candidates) + 1
			local chosen_card = candidates[random_index]
			return { send = { type = "response", card = MPAPI.serialize_card(chosen_card) } }
		elseif d.type == "response" then
			if d.card then MPAPI.rebuild_card(d.card, G.jokers) end
		end
	end,
	calculate = function(self, card, context)
		if
			context.end_of_round
			and not context.other_card
			and not context.blueprint
			and not context.debuffed
			and not PVP.is_phantom(card)
		then
			local removed = false
			card.ability.extra.current_rounds = card.ability.extra.current_rounds + 1
			if card.ability.extra.current_rounds > card.ability.extra.max_rounds then
				removed = true
				G.E_MANAGER:add_event(Event({
					func = function()
						play_sound("tarot1")
						card.T.r = -0.2
						card:juice_up(0.3, 0.4)
						card.states.drag.is = false
						card.children.center.pinch.x = true
						G.E_MANAGER:add_event(Event({
							trigger = "after",
							delay = 0.3,
							blockable = false,
							func = function()
								G.jokers:remove_card(card)
								card:remove()
								card = nil
								return true
							end,
						}))
						return true
					end,
				}))
				card_eval_status_text(card, "extra", nil, nil, nil, { message = localize("k_no_reward") })
			end
			if card.ability.extra.current_rounds == card.ability.extra.rounds then
				local eval = function(card)
					return not card.REMOVED
				end
				juice_card_until(card, eval, true)
			end
			if not removed then
				return {
					message = (card.ability.extra.current_rounds < card.ability.extra.rounds)
							and (card.ability.extra.current_rounds .. "/" .. card.ability.extra.rounds)
						or localize("k_active_ex"),
					colour = G.C.FILTER,
				}
			end
		end
		if
			context.selling_self
			and (card.ability.extra.current_rounds >= card.ability.extra.rounds)
			and not context.blueprint
		then
			return { send = { type = "request" } }
		end
	end,

	mp_credits = {
		idea = { "Zilver" },
		art = { "Ganpan140" },
		code = { "Virtualized" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key) and PVP.multiplayer_content_enabled()
	end,
})
