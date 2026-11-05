-- texlua tests/unit/reliable_referee_test.lua
-- Separate live Lua environments, real referee/queues/checkpoint barrier and JSON.
-- Nakama routing/metadata acceptance are simulated. No process restart is modeled.
local API = os.getenv("MPAPI_DIR") or "../BalatroMultiplayerAPI/"
local json = dofile(API .. "lib/nakama/util/json.lua")
local function copy(value) return json.decode(json.encode(value)) end
local passed = 0
local function equal(a, b) assert(a == b, ("got %s, wanted %s"):format(tostring(a), tostring(b))) end
local function test(name, fn) fn(); passed = passed + 1; print("ok   " .. name) end
local function network(count, drop_legacy_lives)
	local n = { host = "a", peers = {}, queue = {}, metadata = {}, down = {}, serial = 0 }
	for i = 1, count or 3 do
		local id = string.char(96 + i)
		local e = setmetatable({}, { __index = _G })
		e._G = e
		e.dofile = function(path) return assert(loadfile(path, "t", e))() end
		e.PVP = { id = "pvp", GAME = {}, LOBBY = { config = { starting_lives = 8, death_on_round_loss = true }, roster = {} },
			match_log = function() end,
			UTILS = { string_split = function(s) local out = {}; for part in s:gmatch("[^e]+") do out[#out + 1] = part end; return out end },
			current_target_id = function() return id == "a" and "b" or "a" end,
		}
		e.events = {}
		e.G = { STAGE = "run", STAGES = { RUN = "run" }, STATES = { GAME_OVER = "over", HAND_PLAYED = "hand" }, STATE = "hand",
			E_MANAGER = { add_event = function(_, event) e.events[#e.events + 1] = event end }, GAME = { round_resets = { ante = 1 }, skips = 0 } }
		e.Game, e.Event = { update = function() end }, function(value) return value end
		e.effects, e.warnings = {}, {}
		e.sendDebugMessage = function() end
		e.sendWarnMessage = function(value) e.warnings[#e.warnings + 1] = value end
		e.localize, e.number_format = function(value) return value end, tostring
		e.attention_text = function() end
		e.love = { timer = { getTime = function() return 0 end } }
		math.pow = math.pow or function(a, b) return a ^ b end
		local lobby = { _nakama = true, mod_id = "pvp", player_id = id, host_id = "a", is_host = id == "a", metadata = {},
			_game = { started = { run_id = "run-1" } }, handlers = {}, players = {} }
		for j = 1, count or 3 do lobby.players[j] = { id = string.char(96 + j) } end
		function lobby:get_players() return self.players end
		function lobby:get_metadata() return self.metadata end
		function lobby:get_gamemode_instance() return {} end
		function lobby:on(event, fn) self.handlers[event] = self.handlers[event] or {}; table.insert(self.handlers[event], fn) end
		function lobby:fire(event, value)
			local handlers = {}; for _, fn in ipairs(self.handlers[event] or {}) do handlers[#handlers + 1] = fn end
			for _, fn in ipairs(handlers) do fn(value) end
		end
		function lobby:set_metadata(metadata)
			if n.down[id] then return false end
			n.queue[#n.queue + 1] = { kind = "write", from = id, value = json.encode(metadata) }
		end
		function lobby:action(kind)
			local function send(_, target, params)
				if n.down[id] then return false end
				n.queue[#n.queue + 1] = { kind = "action", from = id, to = target, key = kind.key, value = json.encode(params) }
				return true
			end
			return { send = send, broadcast = function(self, params) return send(self, "*", params) end }
		end
		e.lobby = lobby
		e.MPAPI = { get_current_lobby = function() return lobby end,
			generate_id = function() n.serial = n.serial + 1; return "id-" .. n.serial end,
			json_encode = json.encode, sendWarnMessage = e.sendWarnMessage,
			LobbyEvent = { METADATA_CHANGED = "metadata", HOST_CHANGED = "host", DISCONNECTED = "disconnected" },
			ActionTypes = setmetatable({}, { __index = function(t, key)
				local action = { key = key, on_receive = function(_, _, params)
					e.effects[key] = e.effects[key] or {}; table.insert(e.effects[key], copy(params))
				end }; rawset(t, key, action); return action
			end }),
			ReadyTracker = function() return { set = function(self, k, v) self[k] = v end,
				is_ready = function(self, k) return self[k] == true end,
				reset = function(self) for k, v in pairs(self) do if type(v) ~= "function" then self[k] = nil end end end } end,
		}
		e.MPAPI.ActionType = function(spec) e.MPAPI.ActionTypes[spec.key] = spec end
		for _, file in ipairs({ API .. "lib/big_score.lua", "lib/score.lua", "lib/pending_death.lua", "lib/ready_check.lua",
			"lib/reliable_messages.lua", "lib/referee_checkpoint.lua", "pvp_api/server_hold.lua", "pvp_api/referee.lua",
			"pvp_api/reliable_events.lua", "pvp_api/round_sync.lua", "pvp_api/timer_sync.lua", "pvp_api/actions/_helpers.lua", "pvp_api/actions/reliable.lua" }) do e.dofile(file) end
		lobby:on("metadata", function() e.PVP.reconcile_reliable_events() end)
		n.peers[id] = e
	end
	function n:deliver(index)
		local packet = assert(table.remove(self.queue, index or 1), "empty queue")
		local value = json.decode(packet.value)
		if packet.kind == "write" then
			if packet.from ~= self.host then return end -- Current-host authorization.
			for key, item in pairs(value) do self.metadata[key] = item end
			local full = json.encode(self.metadata)
			for id in pairs(self.peers) do self.queue[#self.queue + 1] = { kind = "echo", to = id, value = full } end
		elseif packet.kind == "echo" then
			if self.down[packet.to] then return end
			local peer = self.peers[packet.to]
			peer.lobby.metadata = copy(value)
			peer.lobby:fire("metadata", peer.lobby.metadata)
		else
			if drop_legacy_lives and packet.key == "pvp_player_lives" then return end
			local recipients = packet.to == "*" and self.peers or { [packet.to] = self.peers[packet.to] }
			for id, peer in pairs(recipients) do
				if not self.down[id] then peer.MPAPI.ActionTypes[packet.key]:on_receive(packet.from, copy(value)) end
			end
		end
	end
	function n:flush()
		local steps = 0
		while #self.queue > 0 do self:deliver(); steps = steps + 1; assert(steps < 5000, "network did not settle") end
	end
	function n:update(dt)
		for id, peer in pairs(self.peers) do if not self.down[id] then peer.Game:update(dt) end end
	end
	function n:send(peer, key, params) assert(self.peers[peer].PVP.send_referee_event(key, params or {}), "protocol was not negotiated") end
	function n:change_host(id)
		self.host = id
		for _, peer in pairs(self.peers) do
			peer.lobby.host_id, peer.lobby.is_host = id, peer.lobby.player_id == id
			peer.lobby:fire("host", id)
		end
		self.peers[id].PVP.referee_take_over()
		for _, peer in pairs(self.peers) do peer.PVP.reconcile_round(id) end
	end
	function n:effects(peer, key) return #(self.peers[peer].effects[key] or {}) end
	n.peers.a.PVP.referee_reset(8); n:flush(); n:update(0); n:flush()
	return n
end

local function input_head(n, id)
	local session = n.peers[id].lobby._pvp_reliable_events
	return session.input:head(session.host)
end
local function find(n, predicate)
	for index, packet in ipairs(n.queue) do if predicate(packet) then return index end end
	error("packet not found")
end
local function is_action(key) return function(packet) return packet.kind == "action" and packet.key == key end end

test("all live clients negotiate without polling or leaking pending work", function()
	local n = network()
	for id in pairs(n.peers) do equal(input_head(n, id), nil); equal(n.metadata._pvp_ref.reliable_peers[id], true) end
	equal(#n.queue, 0)
end)

test("critical input effect and cursor are stored together before its ACK or result", function()
	local n = network()
	n:send("b", "pvp_fail_round")
	n:deliver(find(n, is_action("pvp_reliable_event")))
	equal(n.peers.a.PVP.REF.players.b.lives, 7)
	equal(input_head(n, "b") ~= nil, true)
	equal(n.metadata._pvp_ref.players.b.lives, 8)
	for _, packet in ipairs(n.queue) do assert(packet.key ~= "pvp_reliable_ack", "ACK preceded metadata echo") end
	n:flush()
	equal(n.metadata._pvp_ref.players.b.lives, 7)
	equal(input_head(n, "b"), nil)
end)

test("lost requests and ACKs recover without another caller send", function()
	local n = network()
	n:send("b", "pvp_fail_round"); n.queue = {}
	n:update(2); n:flush()
	equal(n.peers.a.PVP.REF.players.b.lives, 7)
	n:send("b", "pvp_new_round")
	-- Deliver through checkpoint confirmation but lose input ACK packets.
	local steps = 0
	while #n.queue > 0 do
		local p = n.queue[1]; steps = steps + 1; assert(steps < 5000)
		if p.key == "pvp_reliable_ack" then table.remove(n.queue, 1) else n:deliver() end
	end
	equal(input_head(n, "b") ~= nil, true)
	n:update(2); n:flush(); equal(input_head(n, "b"), nil)
	equal(n.peers.a.PVP.REF.players.b.lives, 7)
end)

test("fail/reset/fail inputs retain their FIFO order under duplicates", function()
	local n = network()
	n:send("b", "pvp_fail_round"); n:send("b", "pvp_new_round"); n:send("b", "pvp_fail_round")
	local duplicate = copy(n.queue[1]); n.queue[#n.queue + 1] = duplicate
	n:flush()
	equal(n.peers.a.PVP.REF.players.b.lives, 6)
	equal(input_head(n, "b"), nil)
end)

test("disconnect pauses retained input and reconciliation resumes it", function()
	local n = network()
	n.down.b = true; n:send("b", "pvp_fail_round"); n:update(100)
	equal(input_head(n, "b") ~= nil, true)
	n.down.b = false; n.peers.b.PVP.reconcile_round(); n:flush()
	equal(input_head(n, "b"), nil)
	equal(n.peers.a.PVP.REF.players.b.lives, 7)
end)

for _, recovery in ipairs({ "checkpoint", "forced rejoin", "host change" }) do
	test(recovery .. " unpauses an empty input before the next Ready request", function()
		local n = network(2)
		local b = n.peers.b
		local session = b.lobby._pvp_reliable_events
		equal(input_head(n, "b"), nil)
		if recovery == "host change" then
			n.down.a = true; n:change_host("b"); n:flush()
		else
			-- The local authority view can be unsupported while no input is pending.
			b.lobby.metadata = {}; b.lobby:fire("metadata", {})
			equal(session.input._channels.a.paused, true)
			b.lobby.metadata = copy(n.metadata)
			if recovery == "forced rejoin" then b.PVP.reconcile_round()
			else b.lobby:fire("metadata", b.lobby.metadata) end
		end
		local channel = session.input._channels[session.host]
		local seq = channel.next_seq
		equal(input_head(n, "b"), nil)
		n:send("b", "pvp_ready_blind", { starting_hands = 4, round_protocol = 1 })
		n:flush()
		equal(input_head(n, "b"), nil)
		equal(n.metadata._pvp_ref.reliable_received.b.seq, seq)
		equal(n.metadata._pvp_ref.players.b.ready, 1)
		equal(channel.next_seq, seq + 1)
		equal(channel.paused, false)
	end)
end

test("unsupported authority retains Ready until a valid checkpoint returns", function()
	local n = network(2)
	local b = n.peers.b
	b.lobby.metadata = {}; b.lobby:fire("metadata", {})
	n:send("b", "pvp_ready_blind", { starting_hands = 4, round_protocol = 1 })
	local seq = input_head(n, "b")
	local channel = b.lobby._pvp_reliable_events.input._channels.a
	n:update(60)
	equal(#n.queue, 0)
	equal(input_head(n, "b"), seq)
	equal(channel.paused, true)
	equal(channel.queue[channel.first].elapsed, 0)
	b.lobby.metadata = copy(n.metadata); b.lobby:fire("metadata", b.lobby.metadata)
	n:flush()
	equal(input_head(n, "b"), nil)
	equal(n.metadata._pvp_ref.reliable_received.b.seq, seq)
	equal(n.metadata._pvp_ref.players.b.ready, 1)
end)

test("ordinary metadata echoes do not re-arm a timed-out input", function()
	local n = network(2)
	n:send("b", "pvp_ready_blind", { starting_hands = 4, round_protocol = 1 })
	n.queue = {}; n:update(30)
	local b = n.peers.b
	local channel = b.lobby._pvp_reliable_events.input._channels.a
	equal(channel.stalled, true)
	b.lobby:fire("metadata", b.lobby.metadata)
	equal(channel.stalled, true)
	equal(#n.queue, 0)
end)

test("host change before server storage rolls back uncommitted memory then retries", function()
	local n = network()
	n:send("b", "pvp_fail_round"); n:deliver(find(n, is_action("pvp_reliable_event")))
	equal(n.peers.a.PVP.REF.players.b.lives, 7)
	n.down.a = true; n:change_host("c"); n:flush()
	equal(n.peers.c.PVP.REF.players.b.lives, 7)
	equal(input_head(n, "b"), nil)
	equal(n.metadata._pvp_ref.players.b.lives, 7)
end)

test("host change after server storage but before echo never repeats the effect", function()
	local n = network()
	n:send("b", "pvp_fail_round"); n:deliver(find(n, is_action("pvp_reliable_event")))
	n:deliver(find(n, function(p) return p.kind == "write" end))
	equal(n.metadata._pvp_ref.players.b.lives, 7)
	n.down.a = true; n:change_host("c"); n:flush()
	equal(n.peers.c.PVP.REF.players.b.lives, 7)
	equal(input_head(n, "b"), nil)
end)

test("lost client output ACK followed by takeover does not replay timer-hand effects", function()
	local n = network()
	local before = n:effects("b", "pvp_timer_hand_lost")
	n:send("b", "pvp_fail_pvp_timer")
	local steps = 0
	while #n.queue > 0 do
		local p = n.queue[1]; steps = steps + 1; assert(steps < 5000)
		if p.key == "pvp_reliable_output_ack" and p.from == "b" then table.remove(n.queue, 1) else n:deliver() end
	end
	equal(n:effects("b", "pvp_timer_hand_lost"), before + 1)
	n.down.a = true; n:change_host("c"); n:flush()
	equal(n:effects("b", "pvp_timer_hand_lost"), before + 1)
end)

test("takeover accepts cumulative output ACKs for several already-applied committed heads", function()
	local n = network()
	local before = n:effects("b", "pvp_timer_hand_lost")
	n.peers.a.PVP.referee_transaction(function()
		for i = 1, 3 do n.peers.a.PVP.referee_send("pvp_timer_hand_lost", "b", { marker = i }) end
	end)
	n:deliver(find(n, function(p) return p.kind == "write" end))
	local saved = copy(n.metadata._pvp_ref.reliable_outgoing.b)
	equal(#saved.queue, 3)
	-- Retire outputs in the old host's memory, but lose all ACK-progress writes.
	local steps = 0
	while #n.queue > 0 do
		steps = steps + 1; assert(steps < 5000)
		if n.queue[1].kind == "write" then table.remove(n.queue, 1) else n:deliver() end
	end
	equal(n:effects("b", "pvp_timer_hand_lost"), before + 3)
	equal(n.peers.a.lobby._pvp_reliable_events.outgoing:head("b"), nil)
	equal(#n.metadata._pvp_ref.reliable_outgoing.b.queue, 3)
	n.down.a = true; n:change_host("c"); n:flush()
	equal(n:effects("b", "pvp_timer_hand_lost"), before + 3)
	equal(n.peers.c.lobby._pvp_reliable_events.outgoing:head("b"), nil)
end)

test("future and unknown output ACKs cannot skip unconfirmed work", function()
	local n = network()
	local pvp = n.peers.a.PVP
	pvp.referee_send("pvp_timer_hand_lost", "b", {})
	local session = n.peers.a.lobby._pvp_reliable_events
	local head = assert(session.outgoing:head("b"))
	pvp.receive_reliable_output_ack("b", { kind = "ack", scope = "run-1/referee-output-v1", seq = head })
	equal(session.outgoing:head("b"), head)
	pvp.receive_reliable_output_ack("unknown", { kind = "ack", scope = "run-1/referee-output-v1", seq = 0 })
	equal(session.outgoing:head("unknown"), nil)
	n:flush(); equal(session.outgoing:head("b"), nil)
end)

test("outputs queued after an in-flight checkpoint wait for their own confirmation", function()
	local n = network()
	local before = n:effects("b", "pvp_player_lives")
	n.peers.a.PVP.referee_on_fail_round("b")
	n.peers.a.PVP.referee_on_new_round("b")
	n.peers.a.PVP.referee_on_fail_round("b")
	local first_write = find(n, function(p) return p.kind == "write" end)
	n:deliver(first_write)
	-- Confirm only the first checkpoint on the host, not the next queued state.
	n:deliver(find(n, function(p) return p.kind == "echo" and p.to == "a" end))
	for _, p in ipairs(n.queue) do
		if p.key == "pvp_reliable_output" then assert(json.decode(p.value).payload.params.lives ~= 6, "uncommitted output escaped") end
	end
	n:flush()
	equal(n.peers.a.PVP.REF.players.b.lives, 6)
	assert(n:effects("b", "pvp_player_lives") >= before + 2)
end)

test("takeover with a missing/mismatched checkpoint stalls instead of guessing", function()
	local n = network()
	n.metadata = {}; n.down.a = true; n:change_host("c")
	equal(n.peers.c.PVP.REF_RECOVERY_BLOCKED, true)
	n:send("b", "pvp_fail_round"); n:update(2)
	equal(input_head(n, "b") ~= nil, true)
end)

test("old-host ACKs and old-run packets cannot retire the current input", function()
	local n = network()
	n:send("b", "pvp_fail_round")
	local session = n.peers.b.lobby._pvp_reliable_events
	local seq = input_head(n, "b")
	n:change_host("c")
	n.peers.b.PVP.receive_reliable_ack("a", { kind = "ack", scope = "run-1/referee-input-v1", seq = seq })
	equal(input_head(n, "b"), seq)
	n.peers.b.PVP.receive_reliable_ack("c", { kind = "ack", scope = "old-run/referee-input-v1", seq = seq })
	equal(input_head(n, "b"), seq)
	assert(session == n.peers.b.lobby._pvp_reliable_events)
	n:flush(); equal(input_head(n, "b"), nil)
end)

local function scoring_round(n)
	local referee = n.peers[n.host].PVP
	for id in pairs(n.peers) do referee.referee_on_ready_blind(id, 4, 1) end
	local check = referee.REF.ready_check
	assert(check)
	for _, id in ipairs(check.ids) do referee.referee_on_ready_ack(id, check.nonce, true) end
	n:flush()
	local round = referee.REF.round
	for _, peer in pairs(n.peers) do
		peer.PVP.begin_round_sync(round.id, n.host)
		peer.MPAPI.ActionTypes.pvp_play_hand.on_receive = function(_, from, params) peer.PVP.referee_on_play_hand(from, params) end
		peer.MPAPI.ActionTypes.pvp_round_state.on_receive = function(_, from, params) peer.PVP.receive_round_state(from, params) end
	end
end

test("hand scoring uses confirmed checkpoints and reliable state outputs end to end", function()
	local n = network(2); scoring_round(n)
	n.peers.b.PVP.commit_round_report({ score = "200", handsLeft = 0 })
	n.peers.a.PVP.commit_round_report({ score = "100", handsLeft = 0 })
	n:flush()
	equal(n.peers.a.PVP.REF.players.a.lives, 7)
	for id, peer in pairs(n.peers) do
		equal(peer.PVP.GAME.round_sync.applied, true)
		equal(peer.PVP.GAME.round_result.scores.a, "100")
		equal(peer.PVP.GAME.round_result.scores.b, "200")
		equal(peer.PVP.GAME.round_result.enemy_score, id == "a" and "200" or "100")
		equal(n:effects(id, "pvp_end_pvp"), 1)
	end
	n:update(4); n:flush()
	for id in pairs(n.peers) do equal(n:effects(id, "pvp_end_pvp"), 1) end
end)

for _, stored in ipairs({ false, true }) do
	test("resolved hand recovery with host loss " .. (stored and "after" or "before") .. " server storage", function()
		local n = network(2); scoring_round(n)
		n.peers.b.PVP.commit_round_report({ score = "200", handsLeft = 0 }); n:flush()
		n.peers.a.PVP.commit_round_report({ score = "100", handsLeft = 0 })
		n:deliver(find(n, is_action("pvp_play_hand")))
		if stored then n:deliver(find(n, function(p) return p.kind == "write" end)) end
		n.down.a = true; n:change_host("b"); n:flush()
		n.down.a = false
		n.peers.a.PVP.reconcile_round("b"); n.peers.b.PVP.reconcile_round("b"); n:flush()
		n:update(2); n:flush()
		equal(n.peers.b.PVP.REF.players.a.lives, 7)
		for id, peer in pairs(n.peers) do
			equal(n:effects(id, "pvp_end_pvp"), 1)
			equal(peer.PVP.GAME.round_result.scores.a, "100")
			equal(peer.PVP.GAME.round_result.scores.b, "200")
			equal(peer.PVP.GAME.round_result.enemy_score, id == "a" and "200" or "100")
		end
	end)
end

test("new run replaces queues while an end screen preserves output duplicate cursors", function()
	local n = network()
	local peer = n.peers.b
	local original = peer.lobby._pvp_reliable_events
	peer.PVP.GAME = {} -- Normal local state reset must not erase the live protocol.
	peer.PVP.update_reliable_events(0)
	equal(peer.lobby._pvp_reliable_events, original)
	peer.lobby._game.started = { run_id = "run-2" }
	peer.PVP.update_reliable_events(0)
	assert(peer.lobby._pvp_reliable_events ~= original)
	equal(original.input:send("a", {}), nil)
end)

test("legacy host does not enable generic retries or silently accept critical input", function()
	local n = network()
	local peer = n.peers.b
	peer.lobby._game.started = { run_id = "legacy-run" }
	peer.lobby.metadata = {}
	equal(peer.PVP.send_referee_event("pvp_fail_round", {}), false)
	local before = #n.queue
	peer.PVP.update_reliable_events(100)
	equal(#n.queue, before)
end)

test("takeover reads the server instead of trusting a stale local checkpoint", function()
	local n = network()
	local stale = copy(n.peers.c.lobby.metadata)
	n:send("b", "pvp_fail_round"); n:flush()
	n.peers.c.lobby.metadata = stale
	n.down.a = true; n:change_host("c")
	equal(n.peers.c.PVP.REF_RECOVERY_BLOCKED, true)
	n:flush()
	equal(n.peers.c.PVP.REF.players.b.lives, 7)
	equal(n.metadata._pvp_ref.players.b.lives, 7)
end)

test("lost takeover probes retry the same identity, stall, then reconcile", function()
	local n = network()
	n.down.a = true; n:change_host("c")
	local first = json.decode(n.queue[find(n, function(p) return p.kind == "write" and p.from == "c" end)].value)._pvp_ref_probe.id
	n.queue = {}; n:update(2)
	equal(json.decode(n.queue[1].value)._pvp_ref_probe.id, first)
	n.queue = {}; n:update(30)
	local warnings = #n.peers.c.warnings
	n:update(100); equal(#n.peers.c.warnings, warnings); equal(#n.queue, 0)
	n.peers.c.PVP.reconcile_round("c"); n:flush()
	equal(n.peers.c.PVP.REF_RECOVERY_BLOCKED, nil)
	equal(n.metadata._pvp_ref._delivery.writer, "c")
end)

test("rapid host changes fence old probes and let the returning host recover", function()
	local n = network()
	n.down.a = true; n:change_host("c")
	n:send("b", "pvp_fail_round")
	n:change_host("b"); n:flush()
	equal(n.metadata._pvp_ref._delivery.writer, "b")
	equal(n.peers.b.PVP.REF.players.b.lives, 7)
	equal(input_head(n, "b"), nil)
	n.down.a = false; n:change_host("a"); n:flush()
	equal(n.metadata._pvp_ref._delivery.writer, "a")
	equal(n.peers.a.PVP.REF.players.b.lives, 7)
end)

test("missing checkpoint blocks until an explicit reconciliation reads valid state", function()
	local n = network()
	local valid = copy(n.metadata)
	n.metadata = {}; n.down.a = true; n:change_host("c"); n:flush()
	equal(n.peers.c.PVP.REF_RECOVERY_BLOCKED, true)
	n.metadata = valid
	n.peers.c.PVP.reconcile_round("c"); n:flush()
	equal(n.peers.c.PVP.REF_RECOVERY_BLOCKED, nil)
	equal(n.peers.c.PVP.REF.players.b.lives, 8)
end)

test("invalid reliability state blocks takeover without acknowledging pending input", function()
	local n = network()
	n.metadata._pvp_ref.reliable_received.b.seq = -1
	n.down.a = true; n:change_host("c"); n:flush()
	equal(n.peers.c.PVP.REF_RECOVERY_BLOCKED, true)
	n:send("b", "pvp_fail_round"); n:update(2); n:flush()
	assert(input_head(n, "b"))
end)

test("a new run discards an unfinished takeover probe immediately", function()
	local n = network()
	n.down.a = true; n:change_host("c"); n.queue = {}
	local peer = n.peers.c
	peer.lobby._game.started.run_id = "run-2"
	peer.PVP.referee_reset(8); n:flush(); n:update(2)
	equal(peer.PVP.REF_RECOVERY_BLOCKED, nil)
	equal(n.metadata._pvp_ref.tag, "run-2")
	for _, packet in ipairs(n.queue) do
		if packet.kind == "write" then equal(json.decode(packet.value)._pvp_ref_probe, nil) end
	end
end)

test("ready timeout checkpoints the complete transition and old-host callbacks do nothing", function()
	local n = network(2)
	local a = n.peers.a
	a.PVP.referee_on_ready_blind("a", 4, 1); a.PVP.referee_on_ready_blind("b", 4, 1); n:flush()
	local timeout = assert(a.events[#a.events])
	timeout.func()
	equal(n:effects("b", "pvp_start_blind"), 0)
	n:flush()
	equal(n:effects("b", "pvp_start_blind"), 1)
	equal(n.metadata._pvp_ref.round.id, a.PVP.REF.round.id)
	-- A different still-open check must not fire after this client loses authority.
	a.PVP.referee_on_ready_blind("a", 4, 1); a.PVP.referee_on_ready_blind("b", 4, 1); n:flush()
	local old_check = a.PVP.REF.ready_check
	local old_timeout = a.events[#a.events]
	n.down.a = true; n:change_host("b"); n:flush()
	old_timeout.func(); equal(a.PVP.REF.ready_check, old_check)
end)

test("late server-hold callbacks cannot mutate a former host", function()
	local n = network(2)
	local a, callback = n.peers.a, nil
	a.PVP.hold_server_result = function(_, cb) callback = cb end
	a.PVP.REF.players.b.lives = 1
	a.PVP.referee_on_blind_result("b", { ante = 1, blind = "Small", beaten = false })
	a.PVP.referee_on_fail_round("b")
	assert(callback, "pending death must request a server hold")
	local pending = a.PVP.REF.pending_death
	n.down.a = true; n:change_host("b"); n:flush()
	callback(true)
	equal(pending.held, 0); equal(a.PVP.GAME.result_held, nil)
end)

test("oversize inputs fail before sequence allocation and oversize checkpoints retain work", function()
	local n = network()
	local b = n.peers.b
	local next_seq = b.lobby._pvp_reliable_events.input:export_channels().a.next_seq
	equal(pcall(function() b.PVP.send_referee_event("pvp_set_ante", { ante = string.rep("x", 17000) }) end), false)
	equal(b.lobby._pvp_reliable_events.input:export_channels().a.next_seq, next_seq)
	local a = n.peers.a
	a.PVP.referee_transaction(function()
		for i = 1, 10 do a.PVP.referee_send("pvp_timer_hand_lost", "b", { marker = string.rep("x", 7000) }) end
	end)
	equal(a.PVP.REF_RECOVERY_BLOCKED, true)
	assert(a.lobby._pvp_reliable_events.outgoing:head("b"))
	equal(n:effects("b", "pvp_timer_hand_lost"), 0)
	for _, packet in ipairs(n.queue) do assert(packet.kind ~= "write", "oversize checkpoint reached the server") end
	n:update(100); equal(n:effects("b", "pvp_timer_hand_lost"), 0)
end)

for _, mode in ipairs({ "royale", "nemesis_pairing", "team_based", "manhunt" }) do
	test(mode .. " life state and reliable outboxes survive live host takeover", function()
		local n = network(4)
		for _, peer in pairs(n.peers) do peer.PVP.LOBBY.config[mode] = true end
		n.peers.a.PVP.referee_reset(8); n:flush()
		local before = n.peers.a.PVP.REF.players.b.lives
		n:send("b", "pvp_fail_round")
		n:deliver(find(n, is_action("pvp_reliable_event")))
		n:deliver(find(n, function(p) return p.kind == "write" end))
		n.down.a = true; n:change_host("d"); n:flush()
		equal(n.peers.d.PVP.REF.players.b.lives, before - 1)
		equal(input_head(n, "b"), nil)
		if mode == "team_based" then
			local team = n.peers.d.PVP.REF.players.b.team_id
			equal(n.peers.d.PVP.REF.team_lives[team], 7)
		end
	end)
end

test("the legacy caller routes critical messages once through the negotiated FIFO", function()
	local n = network()
	local b = n.peers.b
	b.Client = {}; b.dofile("pvp_api/net.lua")
	b.Client.send({ action = "failRound" }); b.Client.send({ action = "newRound" }); b.Client.send({ action = "failRound" })
	for _, packet in ipairs(n.queue) do equal(packet.key, "pvp_reliable_event") end
	n:flush(); equal(n.peers.a.PVP.REF.players.b.lives, 6)
end)

test("direct ready answers use reliable inputs without a parallel legacy broadcast", function()
	local n = network(2)
	for _, peer in pairs(n.peers) do
		peer.dofile("pvp_api/actions/blind_handshake.lua")
		peer.G.STATES.BLIND_SELECT, peer.G.STATE = "select", "select"
		peer.PVP.GAME.ready_blind = true
		peer.MPAPI.ActionTypes.pvp_start_blind.on_receive = function() peer.started = (peer.started or 0) + 1 end
	end
	n:send("a", "pvp_ready_blind", { starting_hands = 4, round_protocol = 1 })
	n:send("b", "pvp_ready_blind", { starting_hands = 4, round_protocol = 1 })
	while #n.queue > 0 do
		assert(n.queue[1].key ~= "pvp_ready_ack", "parallel legacy ready ACK")
		n:deliver()
	end
	equal(n.peers.a.started, 1); equal(n.peers.b.started, 1)
end)

test("direct voucher sends survive a lost input ACK without awarding twice", function()
	local n = network(3)
	for _, peer in pairs(n.peers) do
		peer.PVP.LOBBY.config.manhunt = true
		peer.dofile("pvp_api/actions/team_manhunt.lua")
	end
	n.peers.a.PVP.referee_reset(8); n:flush()
	local before = n.peers.a.PVP.REF.players.b.lives
	n.peers.a.PVP.pvp_redeem_ante_voucher()
	while #n.queue > 0 do
		assert(n.queue[1].key ~= "pvp_redeem_ante_voucher", "parallel legacy voucher broadcast")
		if n.queue[1].key == "pvp_reliable_ack" then table.remove(n.queue, 1) else n:deliver() end
	end
	n:update(2); n:flush()
	equal(n.peers.a.PVP.REF.players.b.lives, before + 1)
	equal(input_head(n, "a"), nil)
end)

test("mixed-version recipients retain legacy outputs without enabling unknown retries", function()
	local n = network()
	local host, legacy = n.peers.a, n.peers.b
	host.lobby._pvp_reliable_events.peers.b = nil
	legacy.PVP.receive_reliable_output = function() error("legacy client received a generic output") end
	n:send("c", "pvp_fail_round"); n:flush()
	equal(n.peers.a.PVP.REF.players.c.lives, 7)
	assert(n:effects("b", "pvp_player_lives") > 0)
end)

test("an outstanding server hold is re-requested by the replacement host", function()
	local n = network(2)
	local a, callback, resumed = n.peers.a, nil, nil
	a.PVP.hold_server_result = function(_, cb) callback = cb end
	n.peers.b.PVP.hold_server_result = function(_, cb) resumed = cb end
	a.PVP.REF.players.b.lives = 1
	a.PVP.referee_on_blind_result("b", { ante = 1, blind = "Small", beaten = false })
	a.PVP.referee_on_fail_round("b"); n:flush()
	assert(callback)
	n.down.a = true; n:change_host("b"); n:flush()
	assert(resumed, "replacement host did not restore the outstanding hold")
	resumed(true); n:flush()
	equal(n.peers.b.PVP.REF.pending_death.held, 1)
	equal(n.metadata._pvp_ref.pending_death.held, 1)
end)

test("terminal takeover drains its outbox without opening a new blind", function()
	local n = network(2)
	local a = n.peers.a
	-- Ready flags can outlive a final match result in the stored referee.
	a.PVP.REF.players.a.is_ready, a.PVP.REF.players.b.is_ready = true, true
	a.PVP.REF.last_outcome = { winner_id = "b" }
	a.PVP.referee_send("pvp_win", "b", { winner_id = "b" })
	n:deliver(find(n, function(p) return p.kind == "write" end))
	n.down.a = true
	n.peers.b.G.STAGE = "menu"
	n:change_host("b"); n:flush()
	equal(n:effects("b", "pvp_win"), 1)
	equal(n:effects("b", "pvp_ready_check"), 0)
	equal(n.peers.b.PVP.REF.ready_check, nil)
end)

test("negotiation recovers bootstrap lives even when every legacy life packet was lost", function()
	local n = network(3, true)
	for id in pairs(n.peers) do
		local seen = {}
		for _, effect in ipairs(n.peers[id].effects.pvp_player_lives or {}) do seen[effect.player_id] = effect.lives end
		for player in pairs(n.peers) do equal(seen[player], 8) end
	end
end)

test("the real timer-hand handler consumes one hand and credits one bonus across takeover", function()
	local n = network()
	local b, bonus = n.peers.b, 0
	b.G.GAME.current_round = { hands_left = 4 }
	b.PVP.GAME.timer_started, b.PVP.GAME.nemesis_timer_started = true, true
	b.PVP.LOBBY.config.pvp_timer_hand_played_increment_seconds = 5
	b.PVP.UI = { restore_timer = function(seconds) bonus = bonus + seconds end }
	b.dofile("pvp_api/actions/score_resolution.lua")
	n:send("b", "pvp_fail_pvp_timer")
	while #n.queue > 0 do
		if n.queue[1].key == "pvp_reliable_output_ack" and n.queue[1].from == "b" then
			table.remove(n.queue, 1)
		else n:deliver() end
	end
	equal(b.G.GAME.current_round.hands_left, 3); equal(bonus, 5)
	equal(b.PVP.GAME.timer_started, false)
	n.down.a = true; n:change_host("c"); n:flush()
	equal(b.G.GAME.current_round.hands_left, 3); equal(bonus, 5)
	equal(n.peers.c.PVP.REF.players.b.hands_left, 3)
end)

-- Add real timer ticking/handlers to the existing referee integration fixture.
-- Game rendering is stubbed; monotonic clocks, socket outages, host changes and
-- the order of delivery versus the first resumed frame are explicitly controlled.
local function with_timers(n)
	local file = assert(io.open("networking/action_handlers.lua", "r"))
	local source = file:read("*a"); file:close()
	local chunks = {}
	for _, header in ipairs({
		"local function action_start_ante_timer(p)", "local function action_restart_ante_timer(p)",
		"local function action_pause_ante_timer(p)", "function PVP.ACTIONS.announce_ante_timer(time)",
		"function PVP.ACTIONS.start_ante_timer()", "function PVP.ACTIONS.pause_ante_timer()",
		"function PVP.ACTIONS.announce_ante_timer_restart(time, rejoined)",
		"function PVP.ACTIONS.blind_result(beaten, blind)", "function PVP.ACTIONS.fail_timer()",
	}) do
		local first = assert(source:find(header, 1, true))
		local _, last = assert(source:find("\nend\r?\n", first))
		chunks[#chunks + 1] = source:sub(first, last)
	end
	chunks[#chunks + 1] = "return { startAnteTimer = action_start_ante_timer, "
		.. "restartAnteTimer = action_restart_ante_timer, pauseAnteTimer = action_pause_ante_timer }"
	for _, peer in pairs(n.peers) do
		peer.clock = 0
		peer.love.timer.getTime = function() return peer.clock end
		peer.G.FUNCS, peer.G.C = {}, { WHITE = {}, IMPORTANT = {} }
		peer.G.SETTINGS = { GAMESPEED = 1 }
		peer.G.GAME.blind_on_deck = "Small"
		peer.G.GAME.current_round = { hands_left = 4 }
		peer.G.STATES.BLIND_SELECT = "select"
		peer.SMODS = { Gradient = function() end }
		peer.mix_colours = function() return {} end
		peer.Client = {}
		local pvp = peer.PVP
		pvp.config, pvp.UI, pvp.ACTIONS = { timersfx = 3 }, {}, {}
		pvp.LOBBY.code, pvp.LOBBY.config.timer = "TEST", true
		pvp.LOBBY.config.timer_forgiveness = 0
		pvp.GAME.lives, pvp.GAME.timers_forgiven = 8, 0
		pvp.timer_is_local, pvp.is_pvp_boss, pvp.is_layer_active = function() return false end,
			function() return false end, function() return false end
		pvp.current_ruleset = function() return {} end
		pvp.UTILS.timer_start_held_back = function() return false end
		pvp.UTILS.timer_base = function() return 90 end
		local handlers = assert(load(table.concat(chunks, "\n"), "timer-actions", "t", peer))()
		pvp.dispatch_action = function(key, params)
			if key == "startBlind" then peer.started = (peer.started or 0) + 1
			elseif key == "enemyLocation" then peer.opponent_location = params.location
			else assert(handlers[key], "unexpected dispatch: " .. key)(params) end
		end
		peer.dofile("lib/ante_timer.lua")
		peer.dofile("pvp_api/net.lua")
		peer.dofile("pvp_api/actions/timers.lua")
		peer.dofile("pvp_api/actions/score_resolution.lua")
		peer.dofile("pvp_api/actions/blind_handshake.lua")
		peer.dofile("ui/game/timer.lua")
	end
	function n:elapse(seconds)
		for _ = 1, seconds do
			-- A frozen process misses updates, but monotonic wall time still advances.
			for _, peer in pairs(self.peers) do peer.clock = peer.clock + 1 end
			self:update(1); self:flush()
		end
	end
	function n:reset_timers(seconds)
		-- A fresh timer context, as at an actual PvP boundary; do not reuse a
		-- paused previous cycle merely because the fixture resets the UI fields.
		local referee = self.peers[self.host].PVP
		referee.referee_transaction(function() referee.TimerSync.retire(referee.REF.players) end)
		self:flush()
		for _, peer in pairs(self.peers) do
			local game = peer.PVP.GAME
			game.timer, game.timer_consumed = seconds, false
			game.timer_started, game.nemesis_timer_started = false, false
		end
	end
	n:reset_timers(90); n:update(0)
	return n
end

test("10s expiry then opposite 45s outages still reach the next PvP blind", function()
	local n = with_timers(network(2))
	local a, b = n.peers.a, n.peers.b
	-- A is already being timered with 4.6s remaining when its process freezes.
	n:reset_timers(4.6)
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	n.down.a = true; n:elapse(10)
	equal(n.metadata._pvp_ref.players.a.lives, 8)
	n.down.a = false; n:update(0); n:flush()
	equal(n.metadata._pvp_ref.players.a.lives, 7)
	equal(n.metadata._pvp_ref.players.b.lives, 8)
	equal(a.PVP.GAME.timer, 90)
	b.PVP.ACTIONS.pause_ante_timer(); n:flush()
	n:elapse(1); equal(n.metadata._pvp_ref.players.a.lives, 7)

	-- These are simulated transport disconnects/host transfers, not a claim
	-- that every native 45s SIGSTOP causes disconnect detection at this instant.
	local function long_pause(frozen, starter, start_before_resumed_frame)
		n:reset_timers(90)
		n.down[frozen] = true; n:change_host(starter); n:flush()
		n:elapse(1)
		n.peers[starter].PVP.ACTIONS.start_ante_timer()
		-- The frozen client misses the first critical output. Its retained head
		-- times out and is replayed by explicit reconnect reconciliation.
		n:flush(); n:elapse(44)
		n.down[frozen] = false
		local peer = n.peers[frozen]
		peer.lobby.metadata = copy(n.metadata) -- Rejoin's authoritative snapshot.
		peer.lobby:fire("metadata", peer.lobby.metadata)
		if not start_before_resumed_frame then n:update(0) end
		for _, online in pairs(n.peers) do online.PVP.reconcile_round(n.host) end
		n:flush()
		-- The old Start may still be stale, but a fresh same-cycle reconnect
		-- sample now lowers it instead of being rejected as already running.
		n.peers[starter].PVP.AnteTimer.on_opponent_back(); n:flush()
		n:update(0); n:flush()
		local offset = math.abs(a.PVP.GAME.timer - b.PVP.GAME.timer)
		assert(offset <= 1, "reconnect correction must align both delivery orders")
		n.peers[starter].PVP.ACTIONS.pause_ante_timer(); n:flush()
		equal(a.PVP.GAME.timer, b.PVP.GAME.timer)
		for _, online in pairs(n.peers) do
			equal(online.PVP.GAME.timer_started, false)
			equal(online.PVP.GAME.nemesis_timer_started, false)
		end
	end
	long_pause("a", "b", true)
	equal(n.host, "b")
	long_pause("b", "a", false)
	equal(n.host, "a")
	equal(n.metadata._pvp_ref.players.a.lives, 7)
	equal(n.metadata._pvp_ref.players.b.lives, 8)
	-- Display labels and critical Ready are separate routes, as in the report.
	for _, peer in pairs(n.peers) do
		peer.G.STATE, peer.PVP.GAME.ready_blind = "select", true
		peer.Client.send({ action = "setLocation", location = "loc_ready" })
	end
	n:flush()
	equal(a.opponent_location, "loc_ready"); equal(b.opponent_location, "loc_ready")
	for _, peer in pairs(n.peers) do peer.Client.send({ action = "readyBlind", startingHands = 4 }) end
	n:flush()
	equal(a.started, 1); equal(b.started, 1)
	for id, peer in pairs(n.peers) do
		equal(input_head(n, id), nil)
		equal(peer.PVP.GAME.round_sync.id, n.metadata._pvp_ref.round.id)
		equal(n.metadata._pvp_ref.players[id].ready, 0)
	end
	n:elapse(5)
	equal(a.started, 1); equal(b.started, 1)
end)

local function timer_state(n, target)
	return copy(assert(n.metadata._pvp_ref.timers[target]))
end
local function timer_request(state, kind, time)
	return { kind = kind, time = time, id = state.id, cycle = state.cycle,
		generation = state.generation, target = state.target, starter = state.starter, isPvP = state.isPvP, phase = state.phase }
end

test("timer Start state, input cursor and outbox precede every visible start", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer()
	equal(b.PVP.GAME.timer_started, false)
	n:deliver(find(n, is_action("pvp_reliable_event")))
	equal(a.PVP.REF.timers.a.running, true)
	equal(n.metadata._pvp_ref.timers.a, nil)
	equal(a.PVP.GAME.nemesis_timer_started, false)
	equal(b.PVP.GAME.timer_started, false)
	for _, packet in ipairs(n.queue) do
		assert(packet.key ~= "pvp_reliable_ack" and packet.key ~= "pvp_ante_timer")
	end
	n:flush()
	equal(a.PVP.GAME.nemesis_timer_started, true); equal(b.PVP.GAME.timer_started, true)
	equal(timer_state(n, "a").cycle, 1); equal(input_head(n, "b"), nil)
end)

test("lost timer input and ACK retry without duplicate starts or sounds", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	a.PVP.config.timersfx, b.PVP.config.timersfx = 1, 1
	b.PVP.ACTIONS.start_ante_timer(); n.queue = {}; n:update(2)
	while #n.queue > 0 do
		if n.queue[1].key == "pvp_reliable_ack" then table.remove(n.queue, 1) else n:deliver() end
	end
	equal(#a.events, 3); equal(#b.events, 3)
	local state = timer_state(n, "a")
	equal(input_head(n, "b") ~= nil, true)
	n:update(2); n:flush()
	equal(input_head(n, "b"), nil); equal(timer_state(n, "a").revision, state.revision)
	equal(#a.events, 3); equal(#b.events, 3)
end)

test("same-cycle corrections lower time, never raise it or replay start effects", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	a.PVP.config.timersfx, b.PVP.config.timersfx = 1, 1
	b.PVP.ACTIONS.start_ante_timer(); n:flush(); n:elapse(5)
	local state = timer_state(n, "a")
	n:send("b", "pvp_timer_transition", timer_request(state, "sync", 40)); n:flush()
	equal(a.PVP.GAME.timer, 40); equal(b.PVP.GAME.timer, 40)
	n:send("b", "pvp_timer_transition", timer_request(state, "sync", 80)); n:flush()
	equal(a.PVP.GAME.timer, 40); equal(b.PVP.GAME.timer, 40)
	equal(#a.events, 3); equal(#b.events, 3)
	b.PVP.ACTIONS.pause_ante_timer(); n:flush()
	equal(a.PVP.GAME.nemesis_timer_started, false); equal(b.PVP.GAME.timer_started, false)
	n:send("a", "pvp_timer_transition", timer_request(state, "sync", 30)); n:flush()
	equal(a.PVP.GAME.timer, 30); equal(b.PVP.GAME.timer, 30)
	equal(a.PVP.GAME.nemesis_timer_started, false); equal(b.PVP.GAME.timer_started, false)
end)

test("a lost pause is retained and delivered on explicit reconnect", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	n:change_host("b"); n:flush()
	n.down.a = true; b.PVP.ACTIONS.pause_ante_timer(); n:flush(); n:elapse(35)
	equal(timer_state(n, "a").running, false)
	equal(b.PVP.GAME.timer_started, false); equal(a.PVP.GAME.nemesis_timer_started, true)
	n.down.a = false
	a.lobby.metadata = copy(n.metadata)
	for _, peer in pairs(n.peers) do peer.PVP.reconcile_round(n.host) end
	n:flush()
	equal(a.PVP.GAME.nemesis_timer_started, false)
end)

test("expiry remains consumed until its new critical cycle is confirmed", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	n:reset_timers(1); b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local before = timer_state(n, "a")
	for _, peer in pairs(n.peers) do peer.clock = peer.clock + 1 end
	n:update(1)
	equal(a.PVP.GAME.timer, 0); equal(a.PVP.GAME.timer_consumed, true)
	equal(n.metadata._pvp_ref.players.a.lives, 8)
	n:flush()
	equal(n.metadata._pvp_ref.players.a.lives, 7)
	equal(timer_state(n, "a").cycle, before.cycle + 1)
	equal(a.PVP.GAME.timer, 90); equal(b.PVP.GAME.timer, 90)
	equal(a.PVP.GAME.timer_consumed, false)
	-- An old-cycle correction must not cut 90 seconds back to 2.
	n:send("b", "pvp_timer_transition", timer_request(before, "sync", 2)); n:flush()
	equal(a.PVP.GAME.timer, 90); equal(b.PVP.GAME.timer, 90)
	before.time, before.revision = 2, 10000
	a.PVP.TimerSync.receive(before)
	equal(a.PVP.GAME.timer, 90)
end)

test("forgiven expiry advances the cycle without depending on a life decrement", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	a.PVP.LOBBY.config.timer_forgiveness = 1
	n:reset_timers(1); b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local before = timer_state(n, "a")
	n:elapse(1)
	equal(a.PVP.GAME.timers_forgiven, 1); equal(n.metadata._pvp_ref.players.a.lives, 8)
	equal(timer_state(n, "a").cycle, before.cycle + 1)
	n:send("b", "pvp_timer_transition", timer_request(before, "sync", 0)); n:flush()
	equal(a.PVP.GAME.timer, 90); equal(b.PVP.GAME.timer, 90)
end)

test("the waiting player cannot forge an expiry restart", function()
	local n = with_timers(network(2)); local b = n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush(); n:elapse(10)
	local before = timer_state(n, "a")
	n:send("b", "pvp_timer_transition", timer_request(before, "expire", 150)); n:flush()
	equal(timer_state(n, "a").cycle, before.cycle)
	equal(n.peers.a.PVP.GAME.timer, 80); equal(b.PVP.GAME.timer, 80)
end)

test("duplicate output delivery does not reset the timer or repeat sounds", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	a.PVP.config.timersfx = 1
	b.PVP.ACTIONS.start_ante_timer()
	local output
	while #n.queue > 0 do
		local packet = n.queue[1]
		if packet.key == "pvp_reliable_output" and packet.to == "a"
			and json.decode(packet.value).payload.key == "pvp_timer_state" then output = copy(packet) end
		n:deliver()
	end
	assert(output); n:elapse(5)
	n.queue[#n.queue + 1] = output; n:flush()
	equal(a.PVP.GAME.timer, 85); equal(#a.events, 3)
end)

test("confirmed timer state and cycle survive host takeover", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush(); n:elapse(5)
	local before = timer_state(n, "a")
	n:change_host("b"); n:flush()
	equal(b.PVP.REF.timers.a.id, before.id); equal(b.PVP.REF.timers.a.cycle, before.cycle)
	b.PVP.AnteTimer.on_opponent_back(); n:flush()
	equal(a.PVP.GAME.timer, 85); equal(b.PVP.GAME.timer, 85)
	equal(timer_state(n, "a").time, 85)
end)

test("unconfirmed pause rolls back on takeover then retries through the checkpoint", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	b.PVP.ACTIONS.pause_ante_timer(); n:deliver(find(n, is_action("pvp_reliable_event")))
	equal(a.PVP.REF.timers.a.running, false); equal(timer_state(n, "a").running, true)
	equal(b.PVP.GAME.timer_started, true)
	n.down.a = true; n:change_host("b"); n:flush()
	equal(timer_state(n, "a").running, false); equal(b.PVP.GAME.timer_started, false)
	equal(input_head(n, "b"), nil)
end)

test("the timered player's fresh reconnect sample corrects the returning waiting player", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	n.down.b = true; n:elapse(10); n.down.b = false
	b.lobby.metadata = copy(n.metadata); b.PVP.reconcile_round(n.host)
	a.PVP.AnteTimer.on_opponent_back(); n:flush()
	equal(a.PVP.GAME.timer, 80); equal(b.PVP.GAME.timer, 80)
end)

test("retired timer requests and outputs cannot restart a later blind's countdown", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local old = timer_state(n, "a")
	n:reset_timers(150)
	n:send("b", "pvp_timer_transition", timer_request(old, "start", 2)); n:flush()
	equal(n.metadata._pvp_ref.timers.a, nil)
	equal(a.PVP.GAME.nemesis_timer_started, false)
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local fresh = timer_state(n, "a"); assert(fresh.id ~= old.id)
	old.revision = 10000; a.PVP.TimerSync.receive(old)
	equal(a.PVP.GAME.timer, 150); equal(timer_state(n, "a").id, fresh.id)
end)

test("local animation timer corrections do not overwrite the local countdown", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	a.PVP.timer_is_local = function() return true end
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local state = timer_state(n, "a")
	n:send("b", "pvp_timer_transition", timer_request(state, "sync", 20)); n:flush()
	equal(a.PVP.GAME.timer, 90); equal(b.PVP.GAME.timer, 20)
end)

test("mixed-version timers retain their old one-shot wire format", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	n:send("a", "hello", {}); n:flush() -- Old reliable client, no timer capability.
	b.PVP.ACTIONS.start_ante_timer()
	local packet = n.queue[find(n, is_action("pvp_ante_timer"))]
	equal(json.decode(packet.value).time, 90); equal(b.PVP.GAME.timer_started, true)
	n:flush(); equal(a.PVP.GAME.nemesis_timer_started, true)
	equal(n.metadata._pvp_ref.timers.a, nil)
end)

test("negotiated timer transitions retain their queue through missing authority metadata", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	b.lobby.metadata = {}; b.lobby:fire("metadata", {})
	b.PVP.ACTIONS.pause_ante_timer()
	equal(#n.queue, 0); equal(input_head(n, "b") ~= nil, true)
	equal(a.PVP.GAME.nemesis_timer_started, true)
	b.lobby.metadata = copy(n.metadata); b.lobby:fire("metadata", b.lobby.metadata); n:flush()
	equal(a.PVP.GAME.nemesis_timer_started, false); equal(input_head(n, "b"), nil)
end)

test("Pause survives Start in flight before either client receives its identity", function()
	local n = with_timers(network(2)); local b = n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); b.PVP.ACTIONS.pause_ante_timer(); n:flush()
	equal(timer_state(n, "a").running, false)
	equal(b.PVP.GAME.timer_started, false); equal(n.peers.a.PVP.GAME.nemesis_timer_started, false)
	equal(input_head(n, "b"), nil)
end)

test("a threshold-held local timer can pause before its first announcement", function()
	local n = with_timers(network(2)); local b = n.peers.b
	b.PVP.UTILS.timer_start_held_back = function() return true end
	b.PVP.ACTIONS.start_ante_timer(); equal(b.PVP.GAME.timer_started, true)
	equal(n.metadata._pvp_ref.timers.a, nil)
	b.PVP.ACTIONS.pause_ante_timer(); n:flush()
	equal(b.PVP.GAME.timer_started, false); equal(timer_state(n, "a").running, false)
end)

test("Pause naming the preceding cycle stops a just-accepted expiry without shortening it", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	n:reset_timers(1); b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local before = timer_state(n, "a")
	a.PVP.AnteTimer.on_run_out()
	n:deliver(find(n, is_action("pvp_reliable_event")))
	equal(a.PVP.REF.timers.a.cycle, before.cycle + 1)
	b.PVP.ACTIONS.pause_ante_timer(); n:flush()
	equal(timer_state(n, "a").running, false); equal(timer_state(n, "a").time, 90)
	equal(a.PVP.GAME.timer, 90); equal(b.PVP.GAME.timer, 90)
	equal(n.metadata._pvp_ref.players.a.lives, 7)
end)

test("an expiry arriving after authoritative Pause cannot charge a life or restart", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local before = timer_state(n, "a")
	b.PVP.ACTIONS.pause_ante_timer(); n:flush()
	a.PVP.AnteTimer.on_run_out(); n:flush()
	equal(n.metadata._pvp_ref.players.a.lives, 8)
	equal(timer_state(n, "a").cycle, before.cycle); equal(timer_state(n, "a").running, false)
end)

test("Resume keeps legitimate time added while paused and retires preceding samples", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush(); n:elapse(10)
	b.PVP.ACTIONS.pause_ante_timer(); n:flush()
	local before = timer_state(n, "a")
	b.PVP.GAME.timer = b.PVP.GAME.timer + 20
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	equal(timer_state(n, "a").cycle, before.cycle + 1)
	equal(a.PVP.GAME.timer, 100); equal(b.PVP.GAME.timer, 100)
	n:send("a", "pvp_timer_transition", timer_request(before, "sync", 2)); n:flush()
	equal(a.PVP.GAME.timer, 100)
end)

test("boundary output generation can precede the metadata used by the next Start", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush(); b.PVP.ACTIONS.pause_ante_timer(); n:flush()
	local stale = copy(b.lobby.metadata)
	a.PVP.referee_transaction(function()
		a.PVP.TimerSync.retire({ a = true, b = true })
		a.PVP.referee_send("pvp_round_state", "b", { round_id = "boundary" })
	end)
	n:flush()
	-- Keep the authenticated boundary already delivered, but delay metadata.
	b.lobby.metadata = stale
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	equal(timer_state(n, "a").generation, n.metadata._pvp_ref.players.a.timer_generation)
	equal(timer_state(n, "a").running, true)
end)

test("an older third potential host prevents initial timer negotiation", function()
	local n = with_timers(network(3))
	n:send("c", "hello", {}); n:flush()
	n.peers.b.PVP.ACTIONS.start_ante_timer()
	find(n, is_action("pvp_ante_timer")); n:flush()
	equal(n.metadata._pvp_ref.timers.a, nil)
end)

test("negotiated capability downgrade retains Pause until capability returns", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	n:send("a", "hello", {}); n:flush()
	b.PVP.ACTIONS.pause_ante_timer(); equal(#n.queue, 0)
	equal(input_head(n, "b") ~= nil, true)
	n:update(60); n:flush(); equal(timer_state(n, "a").running, true)
	n:send("a", "hello", { timer_protocol = 1 }); n:flush()
	equal(timer_state(n, "a").running, false); equal(input_head(n, "b"), nil)
end)

test("a replacement host without timer capability never receives an unknown critical key", function()
	local n = with_timers(network(2)); local b = n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local snap = copy(b.lobby.metadata)
	snap._pvp_ref.timer_protocol = nil
	b.lobby.metadata = snap; b.lobby:fire("metadata", snap)
	b.PVP.ACTIONS.pause_ante_timer(); b.PVP.reconcile_reliable_events(true)
	equal(#n.queue, 0); equal(input_head(n, "b") ~= nil, true)
	b.lobby.metadata = copy(n.metadata); b.lobby:fire("metadata", b.lobby.metadata); n:flush()
	equal(timer_state(n, "a").running, false)
end)

test("expiry life, cycle, cursor and result commit together and retry once across takeover", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local before = timer_state(n, "a")
	a.PVP.AnteTimer.on_run_out()
	n:deliver(find(n, is_action("pvp_reliable_event")))
	equal(a.PVP.REF.players.a.lives, 7); equal(a.PVP.REF.timers.a.cycle, before.cycle + 1)
	equal(n.metadata._pvp_ref.players.a.lives, 8); equal(timer_state(n, "a").cycle, before.cycle)
	equal(a.PVP.GAME.own_blind_results, nil)
	-- Lose the unconfirmed transaction, transfer authority, retry its input.
	n.queue = {}; n:change_host("b"); n:flush()
	equal(n.metadata._pvp_ref.players.a.lives, 7)
	equal(timer_state(n, "a").cycle, before.cycle + 1)
	equal(input_head(n, "a"), nil)
	local key = a.PVP.PendingDeath.blind_key(1, "Small")
	equal(a.PVP.GAME.own_blind_results[a.PVP.PendingDeath.SELF][key], a.PVP.PendingDeath.BlindResult.FAILED)
	n:elapse(3); equal(n.metadata._pvp_ref.players.a.lives, 7)
end)

test("forgiveness remains checkpointed across takeover and does not reset each countdown", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	for _, peer in pairs(n.peers) do peer.PVP.LOBBY.config.timer_forgiveness = 1 end
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	a.PVP.AnteTimer.on_run_out(); n:flush()
	equal(n.metadata._pvp_ref.players.a.timer_forgiven, 1)
	equal(b.PVP.GAME.timers_forgiven, 0)
	n:change_host("b"); n:flush()
	a.PVP.AnteTimer.on_run_out(); n:flush()
	equal(n.metadata._pvp_ref.players.a.lives, 7)
	equal(a.PVP.GAME.timers_forgiven, 1)
end)

local function pvp_timers()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	for _, peer in pairs(n.peers) do
		peer.G.STATE, peer.PVP.GAME.ready_blind = "select", true
		peer.Client.send({ action = "readyBlind", startingHands = 4 })
	end
	n:flush()
	for _, peer in pairs(n.peers) do
		peer.PVP.is_pvp_boss, peer.PVP.is_layer_active = function() return true end, function() return true end
		peer.G.GAME.blind, peer.G.STATE = { in_blind = true }, "hand"
		peer.PVP.GAME.enemy = { score = "0", hands = 4 }
		peer.PVP.GAME.score = "0"
		peer.PVP.UI.restore_timer = function(amount) peer.PVP.GAME.timer = peer.PVP.GAME.timer + amount end
	end
	b.PVP.GAME.score, b.G.GAME.current_round.hands_left = "10", 3
	a.PVP.GAME.enemy.score, a.PVP.GAME.enemy.hands = "10", 3
	b.PVP.commit_round_report({ score = "10", handsLeft = 3 }); n:flush()
	return n
end

test("a delayed PvP running state cannot rearm the timer after a hand flips the lead", function()
	local n = pvp_timers(); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	equal(a.PVP.GAME.nemesis_timer_started, true)
	local stale = timer_state(n, "a"); stale.revision = stale.revision + 1
	-- Same local stop/score change as ACTIONS.play_hand, before its report arrives.
	a.PVP.GAME.score, a.G.GAME.current_round.hands_left, a.PVP.GAME.nemesis_timer_started = "20", 3, false
	a.PVP.TimerSync.receive(stale); a.PVP.TimerSync.update()
	equal(a.PVP.GAME.nemesis_timer_started, false)
	equal(a.lobby._pvp_timer_sync.pending_states.a, nil)
end)

test("PvP Start waits for the corresponding hand report checkpoint", function()
	local n = pvp_timers(); local a, b = n.peers.a, n.peers.b
	b.PVP.GAME.score, b.G.GAME.current_round.hands_left = "20", 2
	a.PVP.GAME.enemy.score, a.PVP.GAME.enemy.hands = "20", 2
	b.PVP.ACTIONS.start_ante_timer(); equal(#n.queue, 0)
	assert(b.lobby._pvp_timer_sync.pending_start)
	b.PVP.commit_round_report({ score = "20", handsLeft = 2 }); n:flush()
	b.PVP.TimerSync.update(); n:flush()
	equal(timer_state(n, "a").phase.starter_hands, 2)
	equal(b.lobby._pvp_timer_sync.pending_start, nil)
	equal(a.PVP.GAME.nemesis_timer_started, true)
end)

test("Pause cancels a deferred PvP Start before the hand report commits", function()
	local n = pvp_timers(); local b = n.peers.b
	b.PVP.GAME.score, b.G.GAME.current_round.hands_left = "20", 2
	b.PVP.ACTIONS.start_ante_timer(); assert(b.lobby._pvp_timer_sync.pending_start)
	b.PVP.ACTIONS.pause_ante_timer(); n:flush()
	b.PVP.commit_round_report({ score = "20", handsLeft = 2 }); n:flush()
	b.PVP.TimerSync.update(); n:flush()
	equal(b.lobby._pvp_timer_sync.pending_start, nil)
	equal(n.metadata._pvp_ref.timers.a, nil)
end)

test("accepted PvP state waits for the enemy relay and does not refund the wait", function()
	local n = pvp_timers(); local a, b = n.peers.a, n.peers.b
	a.PVP.GAME.enemy.score, a.PVP.GAME.enemy.hands = "0", 4
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	equal(a.PVP.GAME.nemesis_timer_started, false)
	assert(a.lobby._pvp_timer_sync.pending_states.a)
	a.clock = a.clock + 5
	a.PVP.GAME.enemy.score, a.PVP.GAME.enemy.hands = "10", 3
	a.PVP.TimerSync.update()
	equal(a.PVP.GAME.nemesis_timer_started, true); equal(a.PVP.GAME.timer, 85)
	equal(a.lobby._pvp_timer_sync.pending_states.a, nil)
end)

test("PvP expiry carries its cycle and old output cannot rearm a lost hand", function()
	local n = pvp_timers(); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local old = timer_state(n, "a")
	a.Client.send({ action = "failPvPTimer" }); n:flush()
	equal(n.metadata._pvp_ref.players.a.hands, 3)
	equal(a.G.GAME.current_round.hands_left, 3)
	equal(a.PVP.GAME.nemesis_timer_started, false)
	equal(b.PVP.GAME.timer_started, false)
	old.revision = old.revision + 10; a.PVP.TimerSync.receive(old)
	equal(a.PVP.GAME.nemesis_timer_started, false)
	n:send("a", "pvp_timer_transition", timer_request(old, "expire", 0)); n:flush()
	equal(n.metadata._pvp_ref.players.a.hands, 3)
end)

test("PvP expiry after Pause is rejected without a hand loss", function()
	local n = pvp_timers(); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	b.PVP.ACTIONS.pause_ante_timer(); n:flush()
	a.Client.send({ action = "failPvPTimer" }); n:flush()
	equal(n.metadata._pvp_ref.players.a.hands, 4)
end)

test("a still-losing hand keeps its countdown and current-phase expiry can consume a hand", function()
	local n = pvp_timers(); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local before = timer_state(n, "a")
	a.PVP.GAME.score, a.G.GAME.current_round.hands_left = "5", 3
	b.PVP.GAME.enemy.score, b.PVP.GAME.enemy.hands = "5", 3
	a.PVP.commit_round_report({ score = "5", handsLeft = 3 }); n:flush()
	equal(a.PVP.GAME.nemesis_timer_started, true)
	a.PVP.AnteTimer.on_opponent_back(); n:flush()
	equal(timer_state(n, "a").cycle, before.cycle)
	equal(timer_state(n, "a").phase.target_hands, 3)
	a.Client.send({ action = "failPvPTimer" }); n:flush()
	equal(a.G.GAME.current_round.hands_left, 2)
	equal(n.metadata._pvp_ref.players.a.hands, 2)
end)

test("PvP expiry waits for an in-flight hand report instead of being acknowledged and lost", function()
	local n = pvp_timers(); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	a.PVP.GAME.score, a.G.GAME.current_round.hands_left = "5", 3
	b.PVP.GAME.enemy.score, b.PVP.GAME.enemy.hands = "5", 3
	a.Client.send({ action = "failPvPTimer" }); equal(#n.queue, 0)
	assert(a.lobby._pvp_timer_sync.pending_expire)
	a.PVP.commit_round_report({ score = "5", handsLeft = 3 }); n:flush()
	a.PVP.TimerSync.update(); n:flush()
	equal(a.lobby._pvp_timer_sync.pending_expire, nil)
	equal(n.metadata._pvp_ref.players.a.hands, 2)
end)

test("a new PvP score phase replaces the old identity and can be started again", function()
	local n = pvp_timers(); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local old = timer_state(n, "a")
	-- Opponent takes the lead, so the real score callbacks stop this timer.
	a.PVP.GAME.score, a.G.GAME.current_round.hands_left = "20", 3
	b.PVP.GAME.enemy.score, b.PVP.GAME.enemy.hands = "20", 3
	a.PVP.GAME.nemesis_timer_started, b.PVP.GAME.timer_started = false, false
	a.PVP.commit_round_report({ score = "20", handsLeft = 3 }); n:flush()
	-- B regains the lead on its next hand and explicitly starts a new timer.
	b.PVP.GAME.score, b.G.GAME.current_round.hands_left = "30", 2
	a.PVP.GAME.enemy.score, a.PVP.GAME.enemy.hands = "30", 2
	b.PVP.commit_round_report({ score = "30", handsLeft = 2 }); n:flush()
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local fresh = timer_state(n, "a")
	assert(fresh.id ~= old.id); assert(fresh.generation > old.generation)
	equal(a.PVP.GAME.nemesis_timer_started, true)
	old.revision = 999; a.PVP.TimerSync.receive(old)
	equal(a.lobby._pvp_timer_sync.states.a.id, fresh.id)
end)

test("the last-life expiry stops both copies instead of allocating a restart cycle", function()
	local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
	a.PVP.hold_server_result = function(_, callback) callback(true) end
	a.PVP.referee_transaction(function() a.PVP.REF.players.a.lives = 1 end); n:flush()
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	local before = timer_state(n, "a")
	a.PVP.AnteTimer.on_run_out(); n:flush()
	equal(n.metadata._pvp_ref.players.a.lives, 0)
	equal(timer_state(n, "a").cycle, before.cycle)
	equal(timer_state(n, "a").running, false)
	equal(a.PVP.GAME.nemesis_timer_started, false); equal(b.PVP.GAME.timer_started, false)
end)

test("an already-running timer handles either first-resumed-frame ordering without double catch-up", function()
	for _, correction_first in ipairs({ true, false }) do
		local n = with_timers(network(2)); local a, b = n.peers.a, n.peers.b
		b.PVP.ACTIONS.start_ante_timer(); n:flush(); n:change_host("b"); n:flush()
		n.down.a = true; n:elapse(10); n.down.a = false
		if not correction_first then a.Game:update(0) end
		b.PVP.AnteTimer.on_opponent_back(); n:flush()
		if correction_first then a.Game:update(0) end
		equal(a.PVP.GAME.timer, 80); equal(b.PVP.GAME.timer, 80)
		equal(n.metadata._pvp_ref.players.a.lives, 8)
	end
end)

test("PvP phase identity uses the committed enemy score, not the HUD count-up", function()
	local n = pvp_timers(); local a, b = n.peers.a, n.peers.b
	a.PVP.GAME.enemy.real_score, a.PVP.GAME.enemy.score = "10", "2"
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	equal(a.PVP.GAME.nemesis_timer_started, true)
	equal(a.lobby._pvp_timer_sync.pending_states.a, nil)
end)

test("an opponent hand racing PvP expiry cannot erase an expiry of the still-losing player", function()
	local n = pvp_timers(); local a, b = n.peers.a, n.peers.b
	b.PVP.ACTIONS.start_ante_timer(); n:flush()
	-- The opponent reports another hand, but its display relay has not arrived.
	b.PVP.GAME.score, b.G.GAME.current_round.hands_left = "20", 2
	b.PVP.commit_round_report({ score = "20", handsLeft = 2 }); n:flush()
	equal(a.PVP.GAME.enemy.score, "10")
	a.Client.send({ action = "failPvPTimer" }); n:flush()
	equal(a.G.GAME.current_round.hands_left, 3)
	equal(n.metadata._pvp_ref.players.a.hands, 3)
	equal(a.lobby._pvp_timer_sync.pending_expire, nil)
end)

print(("all %d reliable referee tests passed"):format(passed))
