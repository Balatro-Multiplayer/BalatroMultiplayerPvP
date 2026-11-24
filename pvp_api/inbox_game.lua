-- The game calls an inbox item makes (pvp_api/inbox_handlers.lua). Each one makes its change at
-- once or queues it as an event, so match_net's last-item-done event runs after it.
local game = {}
PVP.inbox_game = game

function game.warn(message)
	sendWarnMessage("[inbox] " .. message, "MULTIPLAYER")
end

function game.ante()
	return G.GAME.round_resets.ante
end

function game.add_money(amount, at_once)
	ease_dollars(amount, at_once)
end

function game.add_discards(amount)
	PVP.GAME.pizza_discards = PVP.GAME.pizza_discards + amount
	G.GAME.round_resets.discards = G.GAME.round_resets.discards + amount
	ease_discard(amount)
end

-- Let's Go Gambling misfire: the server's amount (main's copy amount, always $10). The copy only juices up.
function game.gambling_payout(card_key, amount)
	local copy = PVP.UTILS.get_phantom_joker(card_key)
	if copy then copy:juice_up() end
	game.add_money(amount)
end

function game.lower_best_hand(levels)
	for _ = 1, levels do
		PVP.UI.show_asteroid_hand_level_up()
	end
end

function game.add_comeback_bonus(amount)
	PVP.GAME.comeback_payout = "pending"
	PVP.GAME.comeback_bonus = PVP.GAME.comeback_bonus + amount
end

function game.show_life_gained(amount)
	PVP.UI.ease_lives(amount)
end

function game.show_trap_fired(trap_key)
	PVP.UI.show_trap_fired_animation(localize({ type = "name_text", set = "Trap", key = trap_key }))
end

function game.add_free_rerolls(amount)
	PVP.TRAP.grant_free_rerolls(amount)
end

-- The copy keeps the original's poker hand; a tag that acts at once is run here because vanilla does
-- that only on a skip.
function game.add_tag(tag_key, orbital_hand, at_once)
	G.orbital_hand = orbital_hand
	local tag = Tag(tag_key)
	G.orbital_hand = nil
	add_tag(tag)
	if at_once then tag:apply_to_run({ type = "immediate" }) end
end

-- A card that does not fit is lost; a negative card needs no room.
function game.add_consumable(card_key, negative, set)
	if not G.P_CENTERS[card_key] then return game.warn("no consumable " .. card_key) end
	local has_room = #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit
	if has_room or negative then
		SMODS.add_card({ key = card_key, set = set, area = G.consumeables, edition = negative and "e_negative" or nil })
	end
end

-- The Magic Mouth's stolen card, as the Nemesis's game saved it; it is lost when there is no room.
function game.add_stolen_card(saved_card)
	local has_room = #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit
	if has_room then MPAPI.rebuild_card(saved_card, G.consumeables) end
end

-- Built directly: SMODS.add_card would poll shared random streams.
function game.add_wheels(amount)
	for _ = 1, amount do
		if #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit then
			G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
			G.E_MANAGER:add_event(Event({
				trigger = "before",
				delay = 0.0,
				func = function()
					local wheel = Card(G.consumeables.T.x, G.consumeables.T.y, G.CARD_W, G.CARD_H, nil, G.P_CENTERS.c_wheel_of_fortune)
					wheel:add_to_deck()
					G.consumeables:emplace(wheel)
					G.GAME.consumeable_buffer = math.max(0, G.GAME.consumeable_buffer - 1)
					return true
				end,
			}))
		end
	end
end

function game.add_joker(card_key)
	if #G.jokers.cards + G.GAME.joker_buffer < G.jokers.config.card_limit then
		SMODS.add_card({ key = card_key, set = "Joker", area = G.jokers })
	end
end

function game.level_up_hand(hand, levels)
	level_up_hand(nil, hand, true, levels)
end

return game
