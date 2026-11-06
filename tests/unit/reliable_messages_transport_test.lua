-- Run from the repo root: texlua tests/unit/reliable_messages_transport_test.lua
-- Real MPAPI outbound/inbound action code + JSON, simulated two-hop server relay.
-- No Nakama server, socket, game, or restart recovery is exercised here.
local API = os.getenv("MPAPI_DIR") or "../BalatroMultiplayerAPI/"
local json = dofile(API .. "lib/nakama/util/json.lua")
PVP = {}
dofile("lib/reliable_messages.lua")
local RM = PVP.ReliableMessages
local passed = 0
local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end
local function test(name, fn)
	fn()
	passed = passed + 1
	print("ok   " .. name)
end

-- Avoid math.random's runtime-dependent sequence; seeds reproduce every schedule.
local function random(seed)
	return function(limit)
		seed = (seed * 48271) % 2147483647
		return seed % limit + 1
	end
end

local function network()
	local n = { peers = {}, queue = {}, effects = {}, progress = {}, down = {}, warnings = {}, attempts = {} }
	local active, serial = nil, 0
	local function as(peer, fn)
		local previous = active
		active = peer
		local ok, result = pcall(fn)
		active = previous
		if not ok then error(result, 0) end
		return result
	end
	MPAPI = {
		_internal = { lobby = {} },
		networking = { nakama_lobby = { ClientOp = { ACTION = 1 } } },
		generate_id = function()
			serial = serial + 1
			return "transport-" .. serial
		end,
		sendWarnMessage = function(warning) n.warnings[#n.warnings + 1] = warning end,
		sendDebugMessage = function() end,
	}
	MPAPI.networking.nakama_lobby.send = function(op, data)
		equal(op, 1)
		assert(active, "outgoing action needs an authenticated connection")
		n.attempts[#n.attempts + 1] = { from = active, cid = data.cid, seq = data.params.seq }
		if n.down[active] then return false end
		n.queue[#n.queue + 1] = { hop = "server", from = active, wire = json.encode(data) }
		return true
	end
	dofile(API .. "api/action/validation.lua")
	dofile(API .. "api/action/instance.lua")
	dofile(API .. "api/action/dispatch.lua")

	function n:add(peer)
		local action = {
			key = "pvp_reliable_test",
			parameters = {
				{ key = "kind", type = "string", required = true },
				{ key = "scope", type = "string", required = true },
				{ key = "seq", type = "number", required = true },
			},
		}
		local lobby = { player_id = peer, mod_id = "pvp", _action_types = {}, _pending_actions = {} }
		lobby._action_types[action.key] = action
		local manager = RM.new({
			scope = "lobby/run-1",
			timeout = 300,
			transmit = function(to, envelope)
				return as(peer, function()
					return MPAPI._internal.create_action_instance(lobby, action):send(to, envelope)
				end)
			end,
			on_message = function(from, payload, seq)
				local channel = peer .. "/" .. from
				equal(seq, (n.progress[channel] or 0) + 1)
				n.progress[channel] = seq
				-- Payload is application data; only the handler reads its structure.
				local key = peer .. "/" .. from .. "/" .. payload.event
				n.effects[key] = (n.effects[key] or 0) + 1
				equal(n.effects[key], 1)
				equal(payload.nested.score, "1e100")
				equal(payload.nested.text, "quotes: \" and newline\n")
				equal(payload.nested.flag, false)
				return true
			end,
			on_timeout = function() error("unexpected timeout in bounded test") end,
		})
		action.on_receive = function(_, from, envelope) manager:receive(from, envelope) end
		self.peers[peer] = { manager = manager, lobby = lobby }
	end
	function n:deliver(index)
		local packet = table.remove(self.queue, index or 1)
		assert(packet, "no packet")
		local data = json.decode(packet.wire)
		if packet.hop == "server" then
			-- Simulate server routing/stamping, NOT its actual implementation.
			assert(self.peers[data.to], "test requires an existing concrete recipient")
			self.queue[#self.queue + 1] = {
				hop = "client", to = data.to,
				wire = json.encode({
					cid = data.cid, action = data.action, from = packet.from,
					to = data.to, params = data.params,
				}),
			}
		else
			if self.down[packet.to] then return end
			as(packet.to, function() MPAPI._internal.lobby.deliver_action(self.peers[packet.to].lobby, data) end)
		end
	end
	function n:flush()
		local count = 0
		while #self.queue > 0 do
			self:deliver()
			count = count + 1
			assert(count < 10000, "relay did not drain")
		end
	end
	function n:update(dt)
		for _, peer in pairs(self.peers) do peer.manager:update(dt) end
	end
	function n:send(from, to, event)
		return self.peers[from].manager:send(to, {
			event = event,
			nested = { score = "1e100", text = "quotes: \" and newline\n", flag = false },
		})
	end
	for _, peer in ipairs({ "a", "b", "c" }) do n:add(peer) end
	return n
end

test("real MPAPI actions carry request and ACK over two serialized relay hops", function()
	local n = network()
	local id = n:send("a", "b", "first")
	n:deliver() -- Server received request, not the referee.
	equal(next(n.effects), nil)
	equal(n.peers.a.manager:is_pending("b", id), true)
	n:deliver() -- Referee accepts, ACK is on its way to the server.
	equal(n.effects["b/a/first"], 1)
	equal(n.peers.a.manager:is_pending("b", id), true)
	n:deliver() -- Server received ACK, sender has not.
	equal(n.peers.a.manager:is_pending("b", id), true)
	n:deliver()
	equal(n.peers.a.manager:is_pending("b", id), false)
	equal(#n.warnings, 0)
	equal(next(n.peers.a.lobby._pending_actions), nil) -- No per-attempt callback leak.
end)

test("MPAPI retries use fresh transport CIDs but the same reliable event ID", function()
	local n = network()
	local id = n:send("a", "b", "first")
	n.queue = {} -- Accepted socket write, but request never reached receiver.
	n:update(2)
	equal(n.attempts[1].seq, id)
	equal(n.attempts[2].seq, id)
	assert(n.attempts[1].cid ~= n.attempts[2].cid)
	n:flush()
	equal(n.effects["b/a/first"], 1)
	equal(n.peers.a.manager:is_pending("b", id), false)
end)

test("loss of serialized ACK after server relay does not repeat effects", function()
	local n = network()
	local id = n:send("a", "b", "first")
	n:deliver()
	n:deliver()
	n:deliver()
	equal(n.queue[1].hop, "client")
	n.queue = {} -- Lose server -> sender ACK.
	n:update(2)
	n:flush()
	equal(n.effects["b/a/first"], 1)
	equal(n.peers.a.manager:is_pending("b", id), false)
end)

test("sender equals referee still works through server loopback", function()
	local n = network()
	local id = n:send("b", "b", "local-host-event")
	n:flush()
	equal(n.effects["b/b/local-host-event"], 1)
	equal(n.peers.b.manager:is_pending("b", id), false)
end)

for seed = 1, 32 do
	test("seed " .. seed .. ": losses, duplicates, reorder and temporary disconnect converge", function()
		local n, rand, pending, expected = network(), random(seed), {}, {}
		for _, route in ipairs({ { "a", "b" }, { "b", "a" }, { "c", "b" }, { "a", "c" } }) do
			for i = 1, 12 do
				local from, to = route[1], route[2]
				local event = from .. "-" .. to .. "-" .. i
				pending[#pending + 1] = { from = from, to = to, id = n:send(from, to, event) }
				expected[to .. "/" .. from .. "/" .. event] = true
			end
		end
		for step = 1, 240 do
			n.down.a = step >= 40 and step < 100
			n.down.b = step >= 120 and step < 160
			n:update(0.05)
			for _ = 1, 3 do
				if #n.queue == 0 then break end
				local index = rand(#n.queue)
				if rand(100) <= 30 then
					table.remove(n.queue, index) -- Drop either request or ACK on either hop.
				else
					if rand(100) <= 20 then
						local packet = n.queue[index]
						n.queue[#n.queue + 1] = { hop = packet.hop, from = packet.from, to = packet.to, wire = packet.wire }
					end
					n:deliver(index)
				end
			end
		end
		n.down = {}
		-- Heal the network. Delivery should converge without another caller send.
		for _ = 1, 3 do n:flush(); n:update(2) end
		n:flush()
		for key in pairs(expected) do equal(n.effects[key], 1) end
		for key in pairs(n.effects) do equal(expected[key], true) end
		for _, event in ipairs(pending) do equal(n.peers[event.from].manager:is_pending(event.to, event.id), false) end
		for _, peer in pairs(n.peers) do equal(next(peer.lobby._pending_actions), nil) end
	end)
end

print(("all %d reliable_messages transport tests passed"):format(passed))
