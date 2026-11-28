-- Pizza's discard for the other players counts for the ante after the PvP blind (the message
-- carries it). One for a later ante waits in PVP.GAME.pizza_pending until ease_ante reaches it,
-- so the receiver's own ante-up no longer takes it off. The rule matches the server PvP inbox.
PVP.PIZZA = {}

-- "hold" until item_ante, "apply" in it, "drop" once it is over.
function PVP.PIZZA.rule(item_ante, my_ante)
	if my_ante < item_ante then return "hold" end
	if my_ante == item_ante then return "apply" end
	return "drop"
end

-- Whether an ante-up takes Pizza discards off (the same check as ease_ante in ui/game/round.lua).
function PVP.PIZZA.ante_up_clears()
	return PVP.is_mp_or_practice() and not PVP.LOBBY.config.disable_live_and_timer_hud
end

-- ease_ante raises round_resets.ante in an event; until then PVP.GAME.pizza_ante has the new ante.
function PVP.PIZZA.my_ante()
	return PVP.GAME.pizza_ante or G.GAME.round_resets.ante
end

-- Discards that last until the next ante-up.
function PVP.PIZZA.add_discards(amount)
	PVP.GAME.pizza_discards = PVP.GAME.pizza_discards + amount
	G.GAME.round_resets.discards = G.GAME.round_resets.discards + amount
	ease_discard(amount)
end

-- Without an ante (an older message) it is added at once, as before.
function PVP.PIZZA.receive(amount, ante)
	if ante == nil or not PVP.PIZZA.ante_up_clears() then
		return PVP.PIZZA.add_discards(amount)
	end
	local what = PVP.PIZZA.rule(ante, PVP.PIZZA.my_ante())
	if what == "apply" then
		PVP.PIZZA.add_discards(amount)
	elseif what == "hold" then
		local key = tostring(ante)
		PVP.GAME.pizza_pending[key] = (PVP.GAME.pizza_pending[key] or 0) + amount
	end
end

-- Called by ease_ante right after it takes the Pizza discards off.
function PVP.PIZZA.ante_reached(new_ante)
	PVP.GAME.pizza_ante = new_ante
	local pending = PVP.GAME.pizza_pending
	for key, amount in pairs(pending) do
		local what = PVP.PIZZA.rule(tonumber(key), new_ante)
		if what ~= "hold" then pending[key] = nil end
		if what == "apply" then PVP.PIZZA.add_discards(amount) end
	end
end

-- Called once round_resets.ante has caught up.
function PVP.PIZZA.ante_settled()
	PVP.GAME.pizza_ante = nil
end
