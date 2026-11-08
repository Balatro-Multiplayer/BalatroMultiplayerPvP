local A = PVP._pvp_action_helpers.A
local A_host = PVP._pvp_action_helpers.A_host

-- Blind handshake (host-authoritative).
A("pvp_ready_blind", function(_at, from, params)
	PVP.referee_on_ready_blind(from, params and params.starting_hands, params and params.round_protocol)
end)

A("pvp_unready_blind", function(_at, from, _params)
	PVP.referee_on_unready_blind(from)
end)

-- The host asks everyone who looks ready whether they are ready right now before it
-- starts the blind (see PVP.ReadyCheck). Yes only from the blind-select screen with
-- Ready pressed: a stored Ready can outlive its blind, and a player still inside the
-- previous blind must not be pulled out of it.
A_host("pvp_ready_check", function(_at, _from, params)
	local lobby = MPAPI.get_current_lobby()
	local asked = false
	for _, id in ipairs(params.players or {}) do
		asked = asked or (lobby and id == lobby.player_id)
	end
	if not asked then return end
	local ready = PVP.GAME.ready_blind == true and not PVP.GAME.eliminated and G.STATE == G.STATES.BLIND_SELECT
	lobby
		:action(MPAPI.ActionTypes["pvp_ready_ack"])
		:broadcast({ nonce = params.nonce, ready = ready and true or false })
end)

A("pvp_ready_ack", function(_at, from, params)
	PVP.referee_on_ready_ack(from, params and params.nonce, params and params.ready)
end)

A_host("pvp_start_blind", function(_at, _from, params)
	local lobby = MPAPI.get_current_lobby()
	-- An eliminated player sits out the blinds the others still play.
	if not lobby or PVP.GAME.eliminated then return end
	if params.shared_rules then
		local R = PVP.SHARED_RULES
		local result = params.shared_rules
		if type(result) ~= "table" or type(result.ante) ~= "number" then return end
		local previous = G.GAME.pvp_shared_rules
		if previous and previous.retired and previous.retired[result.id] then return end
		if R.starting_id == result.id then return end
		if previous and previous.id == result.id and (previous.active or previous.finished) then return end
		if G.GAME.round_resets.ante > result.ante then return end
		-- Rejoin may still be replaying a shop/hand. Keep the complete target
		-- start envelope, including its round ID and starting-hand counts.
		if not R.can_start(result) then
			R.pending_start = { from = _from, params = copy_table(params) }
			R.offer = nil
			return
		end
		if not R.prepare(result) then return end
	end
	if PVP.begin_round_sync(params.round_id, _from) == false then return end
	if params.shared_rules then
		local R = PVP.SHARED_RULES
		R.starting_id = params.shared_rules.id
		PVP.GAME.next_blind_context = PVP.GAME.next_blind_context or { UIBox = G.blind_select }
		R.offer = nil
		if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
		R.show_result(params.shared_rules)
		if PVP.RLOG then
			PVP.RLOG.record("shared_rules", {
				params.shared_rules.id,
				params.shared_rules.ante,
				params.shared_rules.rules[1],
				params.shared_rules.rules[2],
			})
		end
	end
	-- action_start_blind compares firstPlayer to (is_host and "host" or "guest");
	-- translate the authoritative first-player id into this client's frame.
	local me = lobby.is_host and "host" or "guest"
	local other = lobby.is_host and "guest" or "host"
	local fp = (params.first_player == lobby.player_id) and me or other
	local target_id = PVP.current_target_id()
	local starting_hands = target_id and params.starting_hands and params.starting_hands[target_id]
	PVP.dispatch_action("startBlind", { firstPlayer = fp, startingHands = starting_hands })
end)
