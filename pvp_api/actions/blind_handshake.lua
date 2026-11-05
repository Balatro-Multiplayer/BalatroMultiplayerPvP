local A = PVP._pvp_action_helpers.A
local A_host = PVP._pvp_action_helpers.A_host

-- Blind handshake (host-authoritative).
A("pvp_ready_blind", function(_at, from, _params)
	PVP.referee_on_ready_blind(from)
end)

A("pvp_unready_blind", function(_at, from, _params)
	PVP.referee_on_unready_blind(from)
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
		if R.starting_id == result.id then return end
		if previous and previous.id == result.id and (previous.active or previous.finished) then return end
		if G.GAME.round_resets.ante > result.ante then return end
		-- A reconnect may still be replaying its previous shop/hand. Keep the
		-- server's result until the real blind-selection UI is ready.
		if not R.can_start(params.shared_rules) then
			R.pending_start = { from = _from, params = copy_table(params) }
			R.offer = nil
			return
		end
		if not R.prepare(params.shared_rules) then return end
		R.starting_id = params.shared_rules.id
		-- ready_blind replay restores a flag, not the old process's UIElement.
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
	PVP.dispatch_action("startBlind", { firstPlayer = fp })
end)
