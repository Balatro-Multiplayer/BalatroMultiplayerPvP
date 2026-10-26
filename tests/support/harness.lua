-- Loads the real MPAPI layer/ruleset/pool code and PvP's content, rulesets,
-- lobby flow and replay bootstrap, with the game, SMODS and networking stubbed.
-- Returns the helpers the contract tests are written against.
--
-- TODO(mpapi): the SMODS/registration stubs below duplicate the ones in MPAPI's
-- tests/test_layer_content.lua. MPAPI could ship them as a test-support module
-- that consumer mods dofile, so both suites stub registration the same way.
local H = {}

local api_root = assert(arg[1], "Pass the MultiplayerAPI checkout to test")
local function api(path)
	return dofile(api_root .. "/" .. path)
end

-- ----------------------------------------------------------------------------
-- Game and SMODS
-- ----------------------------------------------------------------------------
G = {
	P_CENTERS = {},
	P_CENTER_POOLS = {},
	GAME = { banned_keys = {} },
	FUNCS = {},
	UIT = { R = "row" },
	STAGES = { RUN = "run" },
}
SMODS = { Mods = {}, Atlas = function() end, GameObject = {} }
function SMODS.GameObject:extend(prototype)
	return setmetatable(prototype, {
		__call = function(class, init)
			setmetatable(init, { __index = class })
			class.obj_table[init.key] = init
			return init
		end,
	})
end
for _, kind in ipairs({ "Joker", "Consumable", "Tag", "Voucher", "Enhancement", "Blind" }) do
	SMODS[kind] = {
		register = function(self)
			G.P_CENTERS[self.key] = self
		end,
	}
end
localize = function(key)
	return key
end
create_UIBox_generic_options = function(options)
	return options
end
sendWarnMessage = function() end

-- ----------------------------------------------------------------------------
-- MPAPI: real layer/ruleset/pool code, stubbed lobby and replay services
-- ----------------------------------------------------------------------------
MPAPI = { sendDebugMessage = function() end, get_current_lobby = function() end }
api("api/layers/registry.lua")
api("api/layers/fields.lua")
api("api/layers/modifiers.lua")
api("api/layers/chain.lua")
api("api/layers/pool_gating.lua")
api("api/ruleset/constructor.lua")
api("api/ruleset/current.lua")

MPAPI.disableable_option_cycle = function(options)
	return { node = options }
end
MPAPI.refresh_current_view = function() end
MPAPI.LobbyEvent = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
MPAPI.GameModes = {}
MPAPI.matchmaking = {
	queue = function() end,
}
MPAPI.get_replay_player_id = function()
	return "host"
end
MPAPI.playback = {
	register_rejoin = function() end,
	register_launcher = function() end,
	build_timeline = function(logs)
		return logs
	end,
}
MPAPI.replay = {
	is_schema_compatible = function()
		return true
	end,
}

-- ----------------------------------------------------------------------------
-- PvP
-- ----------------------------------------------------------------------------
local session, practice = false, false
PVP = {
	id = "MultiplayerPvP",
	EXPERIMENTAL = {},
	LOBBY = { config = {}, deck = {} },
	SP = {},
	GAME = {},
	GamemodeKey = { PVP_NEMESIS = "pvp_nemesis" },
	PVP_GAMEMODES = { pvp_nemesis = { ruleset = "ruleset_mp_balanced", gamemode = "gamemode_mp_attrition" } },
	REF_CHECKPOINT_KEY = "_ref",
	reset_game_states = function() end,
	in_session = function()
		return session
	end,
	is_practice_mode = function()
		return practice
	end,
}

dofile("layers/_layers.lua")
dofile("rulesets/_rulesets.lua")
for _, name in ipairs({ "multiplayer_content", "standard", "classic", "badlatro", "sandbox", "experimental" }) do
	dofile("layers/" .. name .. ".lua")
end
-- These layers' gameplay hooks are outside the content-membership contract.
for _, name in ipairs({ "ranked", "pvp_timer", "smallworld", "speedlatro_timer", "wsob" }) do
	MPAPI.Layer(name, {})
end

H.RULESETS = {
	"badlatro",
	"balanced",
	"expanded",
	"chaos",
	"sandbox",
	"smallworld",
	"speedlatro",
	"traditional",
	"legacy_ranked",
	"vanilla",
	"majorleague",
	"minorleague",
	"wsob",
	"experimental/experimental",
	"experimental/experimental_legacy",
}
for _, path in ipairs(H.RULESETS) do
	dofile("rulesets/" .. path .. ".lua")
end

local function register(kind, prefix, init)
	init.key = prefix .. "_mp_" .. init.key
	init.mod = { id = PVP.id }
	SMODS[kind].register(init)
	return init
end
MPAPI.Joker = function(init)
	return register("Joker", "j", init)
end
MPAPI.Consumable = function(init)
	return register("Consumable", "c", init)
end
SMODS.Joker = setmetatable(SMODS.Joker, {
	__call = function(_, init)
		return register("Joker", "j", init)
	end,
})
SMODS.Voucher = setmetatable(SMODS.Voucher, {
	__call = function(_, init)
		return register("Voucher", "v", init)
	end,
})
for _, name in ipairs({
	"speedrun",
	"conjoined_joker",
	"defensive_joker",
	"pizza",
	"penny_pincher",
	"pacifist",
	"lets_go_gambling",
	"taxes",
	"skip_off",
}) do
	dofile("objects/jokers/" .. name .. ".lua")
end
dofile("objects/consumables/asteroid.lua")
dofile("objects/vouchers/manhunt_vouchers.lua")
dofile("objects/jokers/sandbox/magnet_sandbox.lua")

dofile("pvp_api/flow.lua")
dofile("pvp_api/lobby_bridge.lua")
dofile("pvp_api/queue.lua")
dofile("ui/lobby/lobby_options.lua")
dofile("lib/rejoin.lua")
dofile("ui/replay/replay_browser.lua")

-- ----------------------------------------------------------------------------
-- Run contexts
-- ----------------------------------------------------------------------------
-- "live" is a lobby run, "practice" a local Practice run, "vanilla" no PvP session.
H.CONTEXTS = { "live", "practice" }

function H.enter(short, run)
	session, practice = run ~= "vanilla", run == "practice"
	PVP.SP.ruleset = practice and "ruleset_mp_" .. short or nil
	PVP.LOBBY.code = run == "live" and "TEST" or nil
	PVP.LOBBY.config = { ruleset = not practice and "ruleset_mp_" .. short or nil }
	MPAPI.MODIFIERS = {}
end

function H.excluded(key)
	return MPAPI.should_exclude_from_pool(G.P_CENTERS[key] or key)
end

-- ----------------------------------------------------------------------------
-- Stub lobby: set_metadata merges and fires METADATA_CHANGED synchronously,
-- standing in for the server's echo.
-- ----------------------------------------------------------------------------
local handlers = {}
H.lobby = {
	is_host = true,
	player_id = "host",
	code = "TEST",
	started = false,
	meta = {},
	get_players = function()
		return { { id = "host", displayName = "Host" } }
	end,
	get_metadata = function(self)
		return self.meta
	end,
	is_game_started = function(self)
		return self.started
	end,
	on = function(_, event, callback)
		handlers[event] = callback
	end,
	set_metadata = function(self, update)
		for key, value in pairs(update) do
			self.meta[key] = value
		end
		if handlers.METADATA_CHANGED then handlers.METADATA_CHANGED(update) end
	end,
}
MPAPI.get_current_lobby = function()
	return H.lobby
end

function H.open_private_lobby(meta)
	H.enter("vanilla", "live")
	H.lobby.is_host, H.lobby.started, H.lobby.meta = true, false, meta
	PVP._pvp_kind = PVP.LobbyAccess.PRIVATE
	PVP._pvp_gamemode = "pvp_nemesis"
	PVP.setup_lobby_mirror(H.lobby)
end

-- Delivers new host metadata, as the server would to every client.
function H.receive_metadata(meta)
	H.lobby.meta = meta
	handlers.METADATA_CHANGED(meta)
end

function H.picker(id)
	for _, row in ipairs(PVP.build_lobby_options().contents) do
		local node = row.nodes[1]
		if node.id == id then return node end
	end
end

-- ----------------------------------------------------------------------------
-- Replay and rejoin: a recorded timeline whose lobby_info carries `options`.
-- Returns the bootstrap each path would hand to playback.
-- ----------------------------------------------------------------------------
local bootstrap
PVP._start_playback = function(b)
	bootstrap = b
end

local function timeline(options)
	local events = {
		{ opcode = "match_manifest", args = { schema_version = 1 } },
		{
			opcode = "lobby_info",
			args = { gamemode = "pvp_nemesis", ruleset = "ruleset_mp_expanded", options = options },
		},
		{ opcode = "run_info", args = { seed = "LAYER", deck = "Red Deck", stake = 1 } },
	}
	for _, event in ipairs(events) do
		event.player_id = "host"
	end
	return events
end

function H.replay_bootstrap(options)
	MPAPI.replay.get = function(_, callback)
		callback(nil, { logs = timeline(options) })
	end
	PVP._launch_replay("test")
	return bootstrap
end

function H.rejoin_bootstrap(options)
	PVP._launch_rejoin({ events = timeline(options) })
	return bootstrap
end

-- ----------------------------------------------------------------------------
-- Sections: each prints one line; a failed check ends its section and the run
-- continues with the next one.
-- ----------------------------------------------------------------------------
local failures, sections, checks = 0, 0, 0

function H.check(condition, message)
	checks = checks + 1
	if not condition then error({ message = message }, 0) end
end

function H.section(name, fn)
	sections = sections + 1
	local ok, result = pcall(fn)
	if ok then
		print(("  ✓ %s%s"):format(name, result and ("   " .. result) or ""))
	else
		failures = failures + 1
		print(("  ✗ %s\n      %s"):format(name, type(result) == "table" and result.message or tostring(result)))
	end
end

function H.finish()
	print(("%d sections, %d checks, %d failures"):format(sections, checks, failures))
	if failures > 0 then os.exit(1) end
end

return H
