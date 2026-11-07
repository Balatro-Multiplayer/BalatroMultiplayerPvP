SMODS.Atlas({
	key = "ouija_2",
	path = "c_ouija_2.png",
	px = 71,
	py = 95,
})

SMODS.Consumable({
	key = "ouija_standard",
	set = "Spectral",
	atlas = "ouija_2",
	cost = 4,
	pos = { x = 0, y = 0 },
	unlocked = true,
	discovered = true,
	config = { extra = { destroy = 3 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.destroy } }
	end,
	use = function(self, card, area, copier)
		local used_tarot = copier or card
		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = 0.4,
			func = function()
				play_sound("tarot1")
				used_tarot:juice_up(0.3, 0.5)
				return true
			end,
		}))

		local cards_to_destroy = {}
		local temp_hand = {}
		for k, v in ipairs(G.hand.cards) do
			temp_hand[#temp_hand + 1] = v
		end
		table.sort(temp_hand, function(a, b)
			return not a.playing_card or not b.playing_card or a.playing_card < b.playing_card
		end)
		pseudoshuffle(temp_hand, pseudoseed("ouija_destroy"))

		for i = 1, card.ability.extra.destroy do
			cards_to_destroy[#cards_to_destroy + 1] = temp_hand[i]
			temp_hand[i].ouija_queue_destroy = true
		end
		for i = 1, #G.hand.cards do
			local _card = G.hand.cards[i]
			local percent = 1.15 - (i - 0.999) / (#G.hand.cards - 0.998) * 0.3
			G.E_MANAGER:add_event(Event({
				trigger = "after",
				delay = 0.15,
				func = function()
					_card:flip()
					play_sound("card1", percent)
					_card:juice_up(0.3, 0.3)
					return true
				end,
			}))
		end
		delay(0.2)
		SMODS.destroy_cards(cards_to_destroy)
		delay(0.3)
		local _rank = pseudorandom_element(SMODS.Ranks, "ouija")
		for i = 1, #G.hand.cards do
			local _card = G.hand.cards[i]
			if not _card.ouija_queue_destroy then
				G.E_MANAGER:add_event(Event({
					func = function()
						if _card and not _card.destroyed then assert(SMODS.change_base(_card, nil, _rank.key)) end
						return true
					end,
				}))
			end
		end
		for i = 1, #G.hand.cards do
			local _card = G.hand.cards[i]
			if not _card.ouija_queue_destroy then
				local percent = 0.85 + (i - 0.999) / (#G.hand.cards - 0.998) * 0.3
				G.E_MANAGER:add_event(Event({
					trigger = "after",
					delay = 0.15,
					func = function()
						_card:flip()
						play_sound("tarot2", percent, 0.6)
						_card:juice_up(0.3, 0.3)
						return true
					end,
				}))
			end
		end
		delay(0.5)
	end,
	can_use = function(self, card)
		return G.hand and #G.hand.cards >= card.ability.extra.destroy
	end,
	mp_credits = {
		art = { "aura!" },
		code = { "steph" },
	},
})

-- Ouija variant: vanilla's convert-everything effect, but the -1 hand size only lasts
-- for 3 blinds. Each use queues its own countdown in G.GAME (so it survives save/load
-- and stacks); a blind that is in progress when the card is used counts as the first.
SMODS.Consumable({
	key = "ouija_temporary",
	set = "Spectral",
	cost = 4,
	pos = { x = 7, y = 4 },
	unlocked = true,
	discovered = true,
	config = { extra = { h_size = 1, blinds = 3 }, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.h_size, card.ability.extra.blinds } }
	end,
	use = function(self, card, area, copier)
		local used_tarot = copier or card
		local h_size = card.ability.extra.h_size
		G.GAME.mp_ouija_temp_hand = G.GAME.mp_ouija_temp_hand or {}
		table.insert(G.GAME.mp_ouija_temp_hand, { h_size = h_size, blinds = card.ability.extra.blinds })
		G.hand:change_size(-h_size)

		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = 0.4,
			func = function()
				play_sound("tarot1")
				used_tarot:juice_up(0.3, 0.5)
				return true
			end,
		}))
		for i = 1, #G.hand.cards do
			local _card = G.hand.cards[i]
			local percent = 1.15 - (i - 0.999) / (#G.hand.cards - 0.998) * 0.3
			G.E_MANAGER:add_event(Event({
				trigger = "after",
				delay = 0.15,
				func = function()
					_card:flip()
					play_sound("card1", percent)
					_card:juice_up(0.3, 0.3)
					return true
				end,
			}))
		end
		delay(0.2)
		local _rank = pseudorandom_element(SMODS.Ranks, "ouija")
		for i = 1, #G.hand.cards do
			local _card = G.hand.cards[i]
			G.E_MANAGER:add_event(Event({
				func = function()
					assert(SMODS.change_base(_card, nil, _rank.key))
					return true
				end,
			}))
		end
		for i = 1, #G.hand.cards do
			local _card = G.hand.cards[i]
			local percent = 0.85 + (i - 0.999) / (#G.hand.cards - 0.998) * 0.3
			G.E_MANAGER:add_event(Event({
				trigger = "after",
				delay = 0.15,
				func = function()
					_card:flip()
					play_sound("tarot2", percent, 0.6)
					_card:juice_up(0.3, 0.3)
					return true
				end,
			}))
		end
		delay(0.5)
	end,
	can_use = function(self, card)
		return G.hand and #G.hand.cards > 1
	end,
	mp_credits = {
		code = { "steph" },
	},
})

-- end_round runs once per blind (PvP blinds included, via update_new_round), so each
-- call ticks every pending Ouija countdown and gives the hand size back when one hits 0.
local end_round_ref = end_round
function end_round()
	local pending = G.GAME and G.GAME.mp_ouija_temp_hand
	if pending then
		for i = #pending, 1, -1 do
			local entry = pending[i]
			entry.blinds = entry.blinds - 1
			if entry.blinds <= 0 then
				G.hand:change_size(entry.h_size)
				table.remove(pending, i)
			end
		end
		if #pending == 0 then G.GAME.mp_ouija_temp_hand = nil end
	end
	return end_round_ref()
end
