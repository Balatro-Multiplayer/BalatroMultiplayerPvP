-- Run from the repo root: luajit tests/unit/lobby_publish_test.lua
-- What every writer of the lobby's shared options publishes (server contract D1c/D1b):
-- a non-ranked lobby always carries the full key set the server reads (a missing key is a
-- `bad_rules` refusal there), never the removed death_on_round_loss; a ranked lobby leaves out the keys
-- the server pins (nakama/src/lobby/pvp/ranked_pin.ts) and still writes deck, stake and kind.
-- The "called directly" rows test pvp_lobby_metadata only: ui/lobby/lobby_options.lua and
-- overrides/run_start.lua call it but are not loaded here.
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

-- The keys the server reads from a non-ranked lobby's metadata.
local REQUIRED = {
	"ruleset",
	"gamemode",
	"queue_mode",
	"kind",
	"deck",
	"stake",
	"starting_lives",
	"pvp_start_round",
	"manhunt_hunter_lives",
	"trap_cards",
	"timer_base_seconds",
	"timer_forgiveness",
	"timer_increment_seconds",
}

-- The keys the server pins in a ranked lobby (rankedPinOf): the client must not write them.
local PINNED = {
	"ruleset",
	"queue_mode",
	"starting_lives",
	"pvp_start_round",
	"manhunt_hunter_lives",
	"timer_base_seconds",
	"timer_forgiveness",
	"timer_increment_seconds",
}

local captured -- every set_metadata patch, in order

local function fake_lobby(is_host)
	local handlers = {}
	local lobby = { is_host = is_host, code = "ABCD", handlers = handlers }
	function lobby:on(name, fn)
		handlers[name] = fn
	end
	function lobby:set_metadata(patch)
		captured[#captured + 1] = patch
	end
	return lobby
end

local function fake_handle()
	local handle = { handlers = {} }
	function handle:on(name, fn)
		self.handlers[name] = fn
	end
	return handle
end

local created_handle
local created_lobby

-- The real defaults of core.lua's reset_lobby_config, so the test follows them.
local function load_defaults()
	local f = assert(io.open("core.lua", "rb"))
	local src = f:read("*a"):gsub("\r", "")
	f:close()
	local body = assert(src:match("function PVP%.reset_lobby_config%b()(.-)\nend\n"), "reset_lobby_config not found")
	local chunk = assert(loadstring("return function(persist_ruleset_and_gamemode)" .. body .. "\nend"))
	PVP.reset_lobby_config = chunk()
end

local function load_all()
	captured = {}
	created_handle = fake_handle()
	created_lobby = fake_lobby(true)
	function localize(key)
		return key
	end
	sendWarnMessage = function() end
	G = { FUNCS = {} }
	MPAPI = {
		Party = { KIND = "party" },
		GameModes = {},
		LobbyEvent = { CONNECTED = "connected" },
		matchmaking = {
			queue = function()
				return created_handle
			end,
			guard_queued = function()
				return false
			end,
		},
		create_lobby = function()
			return created_lobby
		end,
		refresh_current_view = function() end,
		networking = {
			nakama_lobby = {
				rpc = function(_id, _body, cb)
					cb(nil, { protocol = 1 })
				end,
			},
		},
	}
	PVP = {
		id = "MultiplayerPvP",
		LOBBY = { config = {} },
		GamemodeKey = { PVP_NEMESIS = "pvp_nemesis" },
		PVP_GAMEMODES = {
			pvp_nemesis = { gamemode = "gamemode_mp_attrition", ruleset = "ruleset_mp_expanded" },
			pvp_royale = { gamemode = "gamemode_mp_royale", ruleset = "ruleset_mp_expanded" },
		},
		MatchmakingPolicy = {
			cocktail_recipe = function()
				return nil
			end,
		},
		match_log = function() end,
		config = {},
		UI = { UTILS = { overlay_message = function() end } },
		_show_searching = function() end,
		setup_lobby_mirror = function() end,
		signal_ready = function() end,
		start_ready_resync = function() end,
		stop_ready_resync = function() end,
		PVP_KIND = nil,
	}
	load_defaults()
	PVP.reset_lobby_config()
	dofile("lib/protocol_gate.lua")
	dofile("pvp_api/protocol_check.lua")
	dofile("pvp_api/flow.lua")
	dofile("pvp_api/queue.lua")
	dofile("pvp_api/group_queue.lua")
end

local function has(patch, key)
	return patch[key] ~= nil
end

local function assert_full(patch)
	for _, key in ipairs(REQUIRED) do
		assert(has(patch, key), "missing key " .. key)
	end
	assert(patch.death_on_round_loss == nil, "death_on_round_loss is no longer part of the contract")
end

-- One writer per entry: how the host's publish is reached.
local writers = {
	{
		"private lobby create",
		function()
			PVP.pvp_create_private_lobby("pvp_nemesis")
			created_lobby.handlers.connected()
		end,
	},
	{
		"casual queue lobby_ready",
		function()
			PVP._join_queue(PVP.LobbyAccess.CASUAL, "pvp_nemesis")
			created_handle.handlers.lobby_ready(created_lobby)
		end,
	},
	{
		"casual royale queue lobby_ready",
		function()
			PVP._join_queue(PVP.LobbyAccess.CASUAL, "pvp_royale")
			created_handle.handlers.lobby_ready(created_lobby)
		end,
	},
	{
		"group queue lobby_ready",
		function()
			PVP._wire_group_handle(created_handle, "pvp_nemesis")
			created_handle.handlers.lobby_ready(created_lobby)
		end,
	},
	{
		"pvp_lobby_metadata called directly, private",
		function()
			PVP._pvp_gamemode = "pvp_nemesis"
			PVP._pvp_kind = PVP.LobbyAccess.PRIVATE
			created_lobby:set_metadata(PVP.pvp_lobby_metadata(PVP._pvp_gamemode, PVP._pvp_kind))
		end,
	},
}

for _, w in ipairs(writers) do
	test(w[1] .. " publishes the full key set", function()
		load_all()
		w[2]()
		equal(#captured, 1)
		assert_full(captured[1])
	end)
end

test("a league ruleset's forced timer reaches the publish", function()
	load_all()
	PVP.LOBBY.config.timer_base_seconds = 180
	PVP.LOBBY.config.timer_forgiveness = 0
	local patch = PVP.pvp_lobby_metadata("pvp_nemesis", PVP.LobbyAccess.PRIVATE)
	assert_full(patch)
	equal(patch.timer_base_seconds, 180)
end)

-- Ranked: the server pins ruleset, queue_mode, lives, ante and the timer keys.
local ranked_writers = {
	{
		"ranked queue lobby_ready",
		function()
			PVP._join_ranked_ruleset("ruleset_mp_balanced")
			created_handle.handlers.lobby_ready(created_lobby)
		end,
	},
	{
		"pvp_lobby_metadata called directly, ranked",
		function()
			PVP._pvp_gamemode = "pvp_nemesis"
			PVP._pvp_kind = PVP.LobbyAccess.RANKED
			created_lobby:set_metadata(PVP.pvp_lobby_metadata(PVP._pvp_gamemode, PVP._pvp_kind))
		end,
	},
}

for _, w in ipairs(ranked_writers) do
	test(w[1] .. " leaves out every pinned key", function()
		load_all()
		w[2]()
		equal(#captured, 1)
		for _, key in ipairs(PINNED) do
			assert(captured[1][key] == nil, "a ranked lobby must not write " .. key)
		end
		assert(captured[1].death_on_round_loss == nil, "death_on_round_loss is no longer part of the contract")
	end)
	test(w[1] .. " still writes deck, stake and kind", function()
		load_all()
		PVP.LOBBY.config.back = "Blue Deck"
		PVP.LOBBY.config.stake = 3
		w[2]()
		local patch = captured[1]
		equal(patch.deck, "Blue Deck")
		equal(patch.stake, "3")
		equal(patch.kind, PVP.LobbyAccess.RANKED)
		assert(patch.gamemode ~= nil, "gamemode is not pinned and stays")
	end)
end

test("a ranked guest writes nothing", function()
	load_all()
	created_lobby = fake_lobby(false)
	PVP._join_ranked_ruleset("ruleset_mp_balanced")
	created_handle.handlers.lobby_ready(created_lobby)
	equal(#captured, 0)
end)

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
