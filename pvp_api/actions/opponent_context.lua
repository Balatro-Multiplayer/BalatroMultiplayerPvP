-- Records what the opponent did (sold a card, left their shop) the moment the
-- API's mpapi_opponent_context action arrives, before the API hands the event
-- to the cards. Recording here, not inside Taxes / Penny Pincher, means it
-- happens exactly once per event no matter how many copies are held, whether
-- Blueprint copies them, whether one is debuffed, or whether any is held yet.
-- The jokers only read PVP.GAME.enemy.

local at = MPAPI.ActionTypes and MPAPI.ActionTypes["mpapi_opponent_context"]
if not at then
	MPAPI.sendWarnMessage("mpapi_opponent_context is missing: Taxes and Penny Pincher will not see the opponent")
elseif not at._pvp_records_opponent then
	local original = at.on_receive
	at._pvp_records_opponent = true
	at.on_receive = function(action_type, from, params)
		local enemy = PVP.GAME and PVP.GAME.enemy
		-- Our own broadcast loops back to us; it is not the opponent's action.
		if enemy and from ~= PVP.self_player_id() then
			local context = { from = from }
			for k, v in pairs(params or {}) do
				context[k] = v
			end
			local ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or 0
			local record = PVP.OPPONENT_RECORD.apply({
				sells = enemy.sells,
				sells_per_ante = enemy.sells_per_ante,
				spent_in_shop = enemy.spent_in_shop,
			}, context, ante, PVP.current_target_id(), PVP.is_byed())
			enemy.sells = record.sells
			enemy.sells_per_ante = record.sells_per_ante
			enemy.spent_in_shop = record.spent_in_shop
		end
		return original(action_type, from, params)
	end
end
