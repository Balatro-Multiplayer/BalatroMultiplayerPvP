local D = PVP.ALMANAC_DRAFT
local H = PVP._pvp_action_helpers

function D.networked()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.code ~= nil
end

function D.request(key, params)
	local lobby = MPAPI.get_current_lobby()
	if lobby then lobby:action(MPAPI.ActionTypes[key]):broadcast(params) end
end

for _, key in ipairs({ "pvp_almanac_open", "pvp_almanac_pick" }) do
	H.A(key, function() end) -- Server consumes requests; never execute a peer's request.
end

H.A_host("pvp_almanac_offer", function(_, _, params)
	local state = G.GAME and G.GAME.almanac_draft
	if not state or type(params) ~= "table" or type(params.id) ~= "string" then return end
	local lobby = MPAPI.get_current_lobby()
	local started = lobby and lobby._game and lobby._game.started
	if not started or params.id ~= started.run_id .. ":decks:" .. tostring(params.ante) then return end
	if not D.milestones[params.ante] or params.ante <= state.last_ante then return end
	if params.ante ~= G.GAME.round_resets.ante or type(params.choices) ~= "table" or #params.choices ~= 3 then
		return
	end
	local seen = {}
	for _, key in ipairs(params.choices) do
		if not D.definitions[key] or not G.P_CENTERS[key] or seen[key] then return end
		seen[key] = true
	end
	if params.picked and not seen[params.picked] then return end
	D.network_reply = { state = state, params = copy_table(params) }
end)

-- Requests are idempotent. Polling also recovers a lost offer/ack after a network
-- drop without trusting client-owned acquisitions or rerolling a pending offer.
function D.network_gate(state)
	local ante = G.GAME.round_resets.ante
	if ante <= state.last_ante then return false end
	if not D.milestones[ante] then
		state.last_ante = ante
		return false
	end
	local reply = D.network_reply
	if reply and reply.state == state and reply.params.ante == ante then
		D.network_reply = nil
		local params = reply.params
		if not state.pending or state.pending.id ~= params.id then
			state.pending = { id = params.id, ante = ante, choices = params.choices }
			if D.waiting_state == state then
				G.FUNCS.exit_overlay_menu()
				D.waiting_state = nil
			end
		end
		if params.picked then
			-- The prior checkpoint may precede the server's commitment. Apply only
			-- at the normal draft gate; D.commit + the save barrier remain the
			-- exactly-once boundary for vouchers and queued destruction effects.
			D.accept(state, params.picked)
			return true
		end
	end
	local lobby = MPAPI.get_current_lobby()
	local now = love.timer.getTime()
	if lobby.server_features and lobby.server_features.almanac_draft == 1 then
		if D.poll_state ~= state or not D.poll_at or now >= D.poll_at then
			D.poll_state, D.poll_at = state, now + 2
			local pending = state.pending
			if pending and pending.submitted then
				D.request("pvp_almanac_pick", { id = pending.id, ante = ante, deck = pending.selected })
			else
				D.request("pvp_almanac_open", { ante = ante })
			end
		end
	end
	if state.pending and not G.OVERLAY_MENU then
		save_run()
		D.show()
	elseif not state.pending and not G.OVERLAY_MENU and D.show_waiting then
		D.show_waiting(lobby.server_features and lobby.server_features.almanac_draft == 1)
	end
	return true
end
