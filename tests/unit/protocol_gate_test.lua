-- Run from the repo root: luajit tests/unit/protocol_gate_test.lua
-- lib/protocol_gate.lua (the pure decision) and pvp_api/protocol_check.lua + the queue and create
-- entry points (nothing is queued or created unless the server's pvp_protocol answers >= the floor).
local failures = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

-- What the server's RPC answered, per scenario: { err, data }.
local rpc_answer
local rpc_calls
local rpc_pending -- when set, the RPC answers only when a test fires its callback
local messages
local queued
local created
local group_joined
local party_created

local function load_all()
	rpc_calls, messages, queued, created, group_joined, party_created = 0, {}, 0, 0, 0, 0
	function localize(key)
		return "L:" .. tostring(key)
	end
	MPAPI = {
		Party = {
			KIND = "party",
			create = function()
				party_created = party_created + 1
			end,
		},
		GameModes = {},
		matchmaking = {
			queue = function()
				queued = queued + 1
				return nil
			end,
			guard_queued = function()
				return false
			end,
		},
		create_lobby = function()
			created = created + 1
			return nil
		end,
		networking = {
			nakama_lobby = {
				rpc = function(id, _body, cb)
					rpc_calls = rpc_calls + 1
					assert(id == "pvp_protocol", "wrong rpc " .. tostring(id))
					if rpc_pending then
						rpc_pending[#rpc_pending + 1] = cb
					else
						cb(rpc_answer[1], rpc_answer[2])
					end
				end,
			},
		},
		pages = { show_deferred = function() end },
	}
	G = { FUNCS = {} }
	sendWarnMessage = function() end
	PVP = {
		id = "MultiplayerPvP",
		LOBBY = { config = {} },
		PVP_GAMEMODES = { pvp_nemesis = { gamemode = "g", ruleset = "r" } },
		GamemodeKey = { PVP_NEMESIS = "pvp_nemesis" },
		MatchmakingPolicy = {
			cocktail_recipe = function()
				return nil
			end,
		},
		match_log = function() end,
		config = {},
		UI = {
			UTILS = {
				overlay_message = function(m)
					messages[#messages + 1] = m
				end,
			},
		},
		_show_searching = function() end,
	}
	dofile("lib/protocol_gate.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/protocol_check.lua")
	dofile("pvp_api/flow.lua")
	dofile("pvp_api/queue.lua")
	dofile("pvp_api/group_queue.lua")
	dofile("pvp_api/party_lobby.lua")
	PVP._join_group_queue = function()
		group_joined = group_joined + 1
		return {}
	end
end

-- The pure decision: a table of answers.
load_all()
local G_ = PVP.ProtocolGate
local cases = {
	-- { name, response, err, ok, reason }
	{ "protocol at the floor", { protocol = 1 }, nil, true, nil },
	{ "protocol above the floor", { protocol = 7 }, nil, true, nil },
	{ "protocol below the floor", { protocol = 0 }, nil, false, "too_old" },
	{ "negative protocol", { protocol = -3 }, nil, false, "too_old" },
	{ "protocol absent", {}, nil, false, "no_protocol" },
	{ "protocol a string", { protocol = "1" }, nil, false, "no_protocol" },
	{ "protocol null (decoded as absent)", { protocol = nil, other = 1 }, nil, false, "no_protocol" },
	{ "RPC not registered (Nakama's not found)", nil, "RPC function not found", false, "not_updated" },
	{ "not found, any case", nil, "rpc Function Not Found", false, "not_updated" },
	{ "not connected", nil, "Not connected", false, "unreachable" },
	{ "session refresh failed", nil, "Session refresh failed", false, "unreachable" },
	{ "deleted account", nil, "Nakama session refresh failed: User account not found.", false, "unreachable" },
	{ "a timeout", nil, "Request timed out", false, "unreachable" },
	{ "the RPC itself failed", nil, "RPC pvp_protocol failed", false, "unreachable" },
	{ "bad JSON", nil, "RPC pvp_protocol returned bad JSON", false, "unreachable" },
	{ "neither answer nor error", nil, nil, false, "unreachable" },
	{ "answer not a table", "ok", nil, false, "unreachable" },
	{ "an error wins over a stale answer", { protocol = 1 }, "Not connected", false, "unreachable" },
}
for _, c in ipairs(cases) do
	test("protocol_ok: " .. c[1], function()
		local ok, reason = G_.protocol_ok(c[2], c[3])
		equal(ok, c[4])
		equal(reason, c[5])
	end)
end

local MESSAGE_OF = {
	not_updated = "k_server_not_updated",
	too_old = "k_server_not_updated",
	no_protocol = "k_server_not_updated",
	unreachable = "k_server_unreachable",
}
for reason, key in pairs(MESSAGE_OF) do
	test("message for " .. reason, function()
		equal(G_.message(reason), "L:" .. key)
	end)
end

test("the floor is one named constant", function()
	equal(G_.FLOOR, 1)
end)

local entries = {
	{
		"ranked queue",
		function()
			PVP._join_ranked_ruleset("ruleset_mp_balanced")
		end,
		function()
			return queued
		end,
	},
	{
		"casual queue",
		function()
			PVP._join_queue("casual", "pvp_nemesis")
		end,
		function()
			return queued
		end,
	},
	{
		"private lobby create",
		function()
			PVP.pvp_create_private_lobby("pvp_nemesis")
		end,
		function()
			return created
		end,
	},
	{
		"party lobby create",
		function()
			PVP.pvp_create_party_lobby()
		end,
		function()
			return party_created
		end,
	},
	{
		"group queue",
		function()
			G.FUNCS.mp_pvp_group_queue_mode({ config = { ref_table = { gamemode_key = "pvp_nemesis" } } })
		end,
		function()
			return group_joined
		end,
	},
}

local refusals = {
	{ "RPC missing", { "RPC function not found", nil }, "k_server_not_updated" },
	{ "protocol below the floor", { nil, { protocol = 0 } }, "k_server_not_updated" },
	{ "no protocol in the answer", { nil, {} }, "k_server_not_updated" },
	{ "the player is offline", { "Not connected", nil }, "k_server_unreachable" },
}
for _, entry in ipairs(entries) do
	for _, r in ipairs(refusals) do
		test(entry[1] .. " is not started when " .. r[1], function()
			rpc_answer = r[2]
			load_all()
			rpc_answer = r[2]
			entry[2]()
			equal(rpc_calls, 1)
			equal(entry[3](), 0)
			equal(#messages, 1)
			equal(messages[1], "L:" .. r[3])
		end)
	end
	test(entry[1] .. " goes ahead on a current server", function()
		load_all()
		rpc_answer = { nil, { protocol = 1 } }
		entry[2]()
		equal(rpc_calls, 1)
		assert(entry[3]() >= 1, "the call was not made")
		equal(#messages, 0)
	end)
end

test("the backstop leaves the lobby and shows the same line, once", function()
	load_all()
	local left = 0
	PVP.pvp_leave_lobby = function()
		left = left + 1
	end
	PVP.NetBasics.log_refusal("pvp.ready", { reason = "not_supported" })
	PVP.NetBasics.log_refusal("pvp.unready", { reason = "not_supported" })
	equal(left, 1)
	equal(#messages, 1)
	equal(messages[1], "L:k_server_not_updated")
end)

test("the backstop fires again in the next lobby", function()
	load_all()
	local left = 0
	PVP.pvp_leave_lobby = function()
		left = left + 1
	end
	PVP.NetBasics.log_refusal("pvp.ready", { reason = "not_supported" })
	PVP.NetBasics.log_refusal("pvp.ready", { reason = "not_supported" })
	equal(left, 1)
	-- A join by code never runs a protocol check: a new lobby alone re-arms it.
	PVP.ProtocolCheck.lobby_started()
	PVP.NetBasics.log_refusal("pvp.ready", { reason = "not_supported" })
	equal(left, 2)
	equal(#messages, 2)
end)

test("setting up a lobby re-arms the backstop", function()
	load_all()
	local left = 0
	PVP.pvp_leave_lobby = function()
		left = left + 1
	end
	local noop = function() end
	MPAPI.apply_default_modifiers = noop
	MPAPI.modifiers_serialize = noop
	G.E_MANAGER = { add_event = noop }
	PVP.LOBBY = { config = {}, deck = {} }
	PVP.CURRENT_LOBBY = nil
	local ok = pcall(dofile, "pvp_api/lobby_bridge.lua")
	assert(ok, "lobby_bridge.lua did not load")
	PVP.NetBasics.log_refusal("pvp.ready", { reason = "not_supported" })
	equal(left, 1)
	local lobby = { code = "AAAA", is_host = false, on = noop, get_players = function() return {} end, get_metadata = function() return {} end }
	pcall(PVP.setup_lobby_mirror, lobby)
	PVP.NetBasics.log_refusal("pvp.ready", { reason = "not_supported" })
	equal(left, 2)
end)

-- The in-flight guard, against an RPC that answers when the test says so.
local function deferred()
	load_all()
	rpc_pending = {}
	local now = 1000
	PVP.ProtocolCheck.clock = function()
		return now
	end
	return function(seconds)
		now = now + seconds
	end
end
local function click()
	PVP._join_ranked_ruleset("ruleset_mp_balanced")
end

test("a double click makes one RPC and one queue", function()
	deferred()
	click()
	click()
	equal(rpc_calls, 1)
	equal(queued, 0)
	rpc_pending[1](nil, { protocol = 1 })
	equal(queued, 1)
	equal(rpc_calls, 1)
end)

test("a click after a pass makes a new RPC", function()
	deferred()
	click()
	rpc_pending[1](nil, { protocol = 1 })
	click()
	equal(rpc_calls, 2)
	rpc_pending[2](nil, { protocol = 1 })
	equal(queued, 2)
end)

test("a click after a refusal makes a new RPC", function()
	deferred()
	click()
	rpc_pending[1]("Not connected")
	equal(queued, 0)
	equal(#messages, 1)
	click()
	equal(rpc_calls, 2)
	rpc_pending[2](nil, { protocol = 1 })
	equal(queued, 1)
end)

test("a check whose callback never fires is stale after 15 s", function()
	local advance = deferred()
	click()
	advance(14)
	click()
	equal(rpc_calls, 1)
	advance(1)
	click()
	equal(rpc_calls, 2)
	rpc_pending[2](nil, { protocol = 1 })
	equal(queued, 1)
end)

test("a stale check's late answer starts nothing", function()
	local advance = deferred()
	click()
	advance(15)
	click()
	rpc_pending[1](nil, { protocol = 1 })
	equal(queued, 0)
	rpc_pending[2](nil, { protocol = 1 })
	equal(queued, 1)
end)

test("a dropped click is logged", function()
	deferred()
	local logged = {}
	PVP.match_log = function(_level, text)
		logged[#logged + 1] = text
	end
	click()
	click()
	local found = false
	for _, text in ipairs(logged) do
		if text:find("dropped", 1, true) then
			found = true
		end
	end
	assert(found, "no log line for the dropped click")
end)
rpc_pending = nil

test("another refusal does not leave", function()
	load_all()
	local left = 0
	PVP.pvp_leave_lobby = function()
		left = left + 1
	end
	PVP.NetBasics.log_refusal("pvp.ready", { reason = "round_over" })
	equal(left, 0)
	equal(#messages, 0)
end)

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
