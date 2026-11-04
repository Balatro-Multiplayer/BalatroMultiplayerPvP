-- Live-process protocol. Input FIFO is per player -> logical referee. Output
-- FIFO is per logical referee -> player and moves with the referee checkpoint.
-- No disk state or replay/relaunch recovery. The authenticated host is resolved
-- outside the core, so its logical identity survives a host change.
local handlers = {
	pvp_ready_blind = function(from, p) PVP.referee_on_ready_blind(from, p.starting_hands, p.round_protocol) end,
	pvp_unready_blind = function(from) PVP.referee_on_unready_blind(from) end,
	pvp_fail_round = function(from) PVP.referee_on_fail_round(from) end,
	pvp_fail_timer = function(from) PVP.referee_on_fail_timer(from) end,
	pvp_fail_pvp_timer = function(from) PVP.referee_on_fail_pvp_timer(from) end,
	pvp_blind_result = function(from, p) PVP.referee_on_blind_result(from, p) end,
	pvp_set_ante = function(from, p) PVP.referee_on_set_ante(from, p) end,
	pvp_new_round = function(from) PVP.referee_on_new_round(from) end,
	pvp_set_furthest_blind = function(from, p) PVP.referee_on_set_furthest_blind(from, p) end,
	pvp_skip = function(from, p) PVP.referee_on_skip(from, p) end,
	pvp_ready_ack = function(from, p) PVP.referee_on_ready_ack(from, p.nonce, p.ready) end,
	pvp_redeem_ante_voucher = function(from) PVP.referee_on_redeem_ante_voucher(from) end,
	hello = function() end,
}
local output_keys = {
	pvp_death_pending = true, pvp_eliminated = true, pvp_end_pvp = true,
	pvp_manhunt_target = true, pvp_nemesis_pairing = true, pvp_player_lives = true,
	pvp_ready_check = true, pvp_royale_target = true, pvp_start_blind = true,
	pvp_team_card_target = true, pvp_team_lives = true, pvp_team_roster = true,
	pvp_team_score_board = true, pvp_timer_hand_lost = true, pvp_win = true,
	pvp_round_state = true,
}

local function current()
	local lobby = MPAPI.get_current_lobby()
	local started = lobby and lobby._game and lobby._game.started
	if lobby and lobby.mod_id == PVP.id then
		if started and started.run_id then return lobby, tostring(started.run_id) end
		-- Keep terminal outboxes and duplicate cursors alive through the result
		-- screen. A new run ID replaces them; leaving destroys the lobby object.
		local session = lobby._pvp_reliable_events
		if session then return lobby, session.run end
	end
end
local function host(lobby)
	return lobby.host_id or (lobby.is_host and lobby.player_id)
end
local function send(lobby, key, target, envelope)
	return lobby:action(MPAPI.ActionTypes[key]):send(target, envelope)
end
local function validate_payload(session, channel, payload)
	-- Reserve the longest exact sequence before allocating an identity. The
	-- server rejects action params over 16 KiB, including our generic envelope.
	local encoded = MPAPI.json_encode({ kind = "message", scope = session.run .. channel,
		seq = 9007199254740991, payload = payload })
	assert(#encoded <= 16 * 1024, "reliable referee message exceeds server action capacity")
end
local function warning()
	sendWarnMessage("[pvp] reliable event unacknowledged; retaining queue until reconciliation", "MULTIPLAYER")
end
local function receiver(session)
	return PVP.ReliableMessages.new({
		scope = session.run .. "/referee-input-v1",
		transmit = function(peer, envelope) PVP.referee_send("pvp_reliable_ack", peer, envelope) end,
		on_message = function(from, payload)
			if type(payload) ~= "table" or not handlers[payload.key] or type(payload.params) ~= "table" then return false end
			local newly_supported = not session.peers[from]
			session.peers[from] = true
			if newly_supported then PVP.referee_sync_state() end
			handlers[payload.key](from, payload.params)
			return true
		end,
		on_timeout = warning,
	})
end
local function outgoing(session)
	return PVP.ReliableMessages.new({
		scope = session.run .. "/referee-output-v1", max_pending = 4096,
		transmit = function(peer, envelope)
			-- An ACK can drain the FIFO synchronously. Never let it publish a tail
			-- that was enqueued after the confirmed checkpoint.
			if envelope.seq > (session.limits[peer] or 0) then session.outgoing:pause(peer); return false end
			local lobby, run = current()
			if lobby ~= session.lobby or run ~= session.run or not lobby.is_host then
				session.outgoing:pause(peer); return false
			end
			local sent = send(lobby, "pvp_reliable_output", peer, envelope)
			if sent == false then session.outgoing:pause(peer) end
			return sent
		end,
		on_message = function() return false end, on_timeout = warning,
	})
end
local function get()
	local lobby, run = current()
	if not lobby then return nil end
	local session = lobby._pvp_reliable_events
	if session and session.lobby == lobby and session.run == run then return session end
	if session then session.input:close(); session.receiver:close(); session.outgoing:close(); session.output_receiver:close() end
	session = { lobby = lobby, run = run, host = host(lobby), peers = {}, limits = {} }
	session.input = PVP.ReliableMessages.new({
		scope = run .. "/referee-input-v1",
		transmit = function(peer, envelope)
			local active, active_run = current()
			if active ~= lobby or active_run ~= run or host(lobby) ~= peer then session.input:pause(peer); return false end
			local sent = send(lobby, "pvp_reliable_event", peer, envelope)
			if sent == false then session.input:pause(peer) end
			return sent
		end,
		on_message = function() return false end, on_timeout = warning,
	})
	session.receiver, session.outgoing = receiver(session), outgoing(session)
	session.output_receiver = PVP.ReliableMessages.new({
		scope = run .. "/referee-output-v1",
		transmit = function(_, envelope) send(lobby, "pvp_reliable_output_ack", host(lobby), envelope) end,
		on_message = function(_, payload)
			if type(payload) ~= "table" or not output_keys[payload.key] or type(payload.params) ~= "table" then return false end
			MPAPI.ActionTypes[payload.key]:on_receive(host(lobby), payload.params)
			return true
		end,
		on_timeout = warning,
	})
	lobby._pvp_reliable_events = session
	return session
end
local function supported(session)
	local snap = (session.lobby:get_metadata() or {})[PVP.REF_CHECKPOINT_KEY]
	return snap and snap.tag == session.run and snap.reliable_protocol == 1
		and snap._delivery and snap._delivery.writer == host(session.lobby)
end

-- Returns false ONLY for a legacy host/no active run. Once negotiated, a full
-- queue is an explicit fault, never a fallback one-shot duplicate or silent drop.
function PVP.send_referee_event(key, params)
	local session = get()
	if not session or not handlers[key] then return false end
	if not supported(session) and not session.negotiated then return false end
	session.negotiated = true
	local peer = host(session.lobby)
	if peer ~= session.host then PVP.reconcile_reliable_events(); peer = session.host end
	if not supported(session) then session.input:pause(peer) end
	local payload = { key = key, params = params or {} }
	validate_payload(session, "/referee-input-v1", payload)
	assert(session.input:send(peer, payload), "reliable referee input queue is full")
	return true
end

function PVP.receive_reliable_event(from, envelope)
	local session = get()
	if not session or not session.lobby.is_host or PVP.REF_RECOVERY_BLOCKED then return end
	local known = false
	for _, player in ipairs(session.lobby:get_players()) do if player.id == from then known = true end end
	if known then
		PVP.referee_transaction(function() session.receiver:receive(from, envelope) end)
	end
end
function PVP.receive_reliable_ack(from, envelope)
	local session = get()
	if session and from == host(session.lobby) then session.input:receive(from, envelope) end
end
function PVP.receive_reliable_output(from, envelope)
	local session = get()
	if session and from == host(session.lobby) then session.output_receiver:receive("referee", envelope) end
end
function PVP.receive_reliable_output_ack(from, envelope)
	local session = get()
	if session and session.lobby.is_host and type(envelope) == "table" and envelope.kind == "ack"
		and envelope.scope == session.run .. "/referee-output-v1" and type(envelope.seq) == "number"
		and envelope.seq > 0 and envelope.seq % 1 == 0 and session.limits[from]
		and envelope.seq <= session.limits[from] then
		PVP.referee_transaction(function()
			-- A replacement host can restore an older ACK cursor than the client's
			-- live receiver. Its cumulative ACK covers only already-COMMITTED output
			-- identities, never a tail reserved after the confirmed checkpoint.
			session.outgoing:pause(from)
			local head = session.outgoing:head(from)
			while head and head <= envelope.seq do
				if not session.outgoing:acknowledge(from, head) then break end
				head = session.outgoing:head(from)
			end
			session.outgoing:resume(from)
		end)
	end
end

function PVP.reliable_referee_cursors()
	local session = get()
	return session and session.receiver:export_received() or {}
end
function PVP.reliable_referee_outputs()
	local session = get()
	return session and session.outgoing:export_channels() or {}
end
function PVP.reliable_referee_peers()
	local session = get()
	return session and session.peers or {}
end
function PVP.restore_reliable_referee(snapshot)
	local session = get()
	if not session then return true end
	local received, outputs = receiver(session), outgoing(session)
	local ok, err = pcall(function()
		if snapshot.reliable_protocol == 1 then
			assert(type(snapshot.reliable_received) == "table" and type(snapshot.reliable_outgoing) == "table"
				and type(snapshot.reliable_peers) == "table", "checkpoint is missing reliability state")
		else
			assert(not session.negotiated, "checkpoint cannot account for negotiated reliable inputs")
		end
		received:restore_received(snapshot.reliable_received or {})
		outputs:restore_channels(snapshot.reliable_outgoing or {})
	end)
	if not ok then
		received:close(); outputs:close()
		sendWarnMessage("[pvp] invalid reliable referee checkpoint: " .. tostring(err), "MULTIPLAYER")
		return false
	end
	session.receiver:close(); session.outgoing:close()
	session.receiver, session.outgoing = received, outputs
	session.peers, session.limits = snapshot.reliable_peers or {}, {}
	return true
end

-- Enqueue without sending. The queue itself is part of the next checkpoint.
function PVP.stage_reliable_referee_output(key, target, params)
	local session = get()
	if not session or not output_keys[key] then return { target } end
	local legacy = {}
	local payload = { key = key, params = params or {} }
	validate_payload(session, "/referee-output-v1", payload)
	local players = target == "*" and session.lobby:get_players() or { { id = target } }
	for _, player in ipairs(players) do
		if session.peers[player.id] then
			session.outgoing:pause(player.id)
			assert(session.outgoing:send(player.id, payload), "reliable referee output queue is full")
		else
			legacy[#legacy + 1] = player.id
		end
	end
	return legacy
end
function PVP.confirm_reliable_referee_outputs(snapshot)
	local session = get()
	if not session then return end
	for peer, channel in pairs(snapshot.reliable_outgoing or {}) do
		session.limits[peer] = math.max(session.limits[peer] or 0, channel.next_seq - 1)
		session.outgoing:resume(peer)
	end
end

function PVP.reconcile_reliable_events(force)
	local session = get()
	if not session then return end
	local peer = host(session.lobby)
	if not peer then return end
	local changed = session.host ~= peer
	if changed then
		session.input:retarget(session.host, peer)
		session.host = peer
	end
	if supported(session) then
		local newly_supported = not session.was_supported
		session.was_supported = true
		if not session.hello then
			session.hello = true
			PVP.send_referee_event("hello", {})
		end
		if (force or changed or newly_supported) and session.input:head(peer) then session.input:resume(peer) end
		if force and session.lobby.is_host then
			for recipient in pairs(session.limits) do session.outgoing:resume(recipient) end
		end
	else
		session.was_supported = false
		session.input:pause(peer)
	end
end
function PVP.update_reliable_events(dt)
	local session = get()
	if not session then return end
	if not session.hello then PVP.reconcile_reliable_events() end
	session.input:update(dt)
	if session.lobby.is_host and not PVP.REF_RECOVERY_BLOCKED then session.outgoing:update(dt) end
end
