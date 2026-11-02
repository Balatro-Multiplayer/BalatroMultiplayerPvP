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
	local function record(from, params)
		local enemy = PVP.GAME and PVP.GAME.enemy
		-- Our own broadcast loops back to us; it is not the opponent's action.
		if not enemy or from == PVP.self_player_id() then
			return
		end
		local context = { from = from }
		for k, v in pairs(params or {}) do
			context[k] = v
		end
		local ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or 0
		local result = PVP.OPPONENT_RECORD.apply({
			sells = enemy.sells,
			sells_per_ante = enemy.sells_per_ante,
			spent_in_shop = enemy.spent_in_shop,
		}, context, ante, PVP.current_target_id(), PVP.is_byed())
		enemy.sells = result.sells
		enemy.sells_per_ante = result.sells_per_ante
		enemy.spent_in_shop = result.spent_in_shop
	end

	at.on_receive = function(action_type, from, params)
		-- The action type belongs to the API, so another mod's lobby reaches it too.
		local lobby = MPAPI.get_current_lobby()
		if lobby and lobby.mod_id == PVP.id then
			-- A failed recording must not stop the original handler from reaching the jokers.
			local ok, err = pcall(record, from, params)
			if not ok then
				MPAPI.sendWarnMessage("could not record the opponent context: " .. tostring(err))
			end
		end
		return original(action_type, from, params)
	end
end
