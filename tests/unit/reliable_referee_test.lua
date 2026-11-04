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
			"pvp_api/reliable_events.lua", "pvp_api/round_sync.lua", "pvp_api/actions/_helpers.lua", "pvp_api/actions/reliable.lua" }) do e.dofile(file) end
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
		for id in pairs(n.peers) do equal(n:effects(id, "pvp_end_pvp"), 1) end
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

print(("all %d reliable referee tests passed"):format(passed))
