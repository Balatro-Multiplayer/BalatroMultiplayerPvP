local H = {}

local api_root = assert(arg[1], "Pass the MultiplayerAPI checkout to test")
local function api(path)
	return dofile(api_root .. "/" .. path)
end

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

MPAPI = { sendDebugMessage = function() end, get_current_lobby = function() end }
api("api/layers/registry.lua")
api("api/layers/fields.lua")
api("api/layers/modifiers.lua")
api("api/layers/chain.lua")
api("api/layers/pool_gating.lua")
api("api/ruleset/active.lua")
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

H.RUN_KINDS = { "lobby", "practice" }

function H.start_run(ruleset, kind)
	session, practice = kind ~= "normal", kind == "practice"
	PVP.SP.ruleset = practice and "ruleset_mp_" .. ruleset or nil
	PVP.LOBBY.code = kind == "lobby" and "TEST" or nil
	PVP.LOBBY.config = { ruleset = not practice and "ruleset_mp_" .. ruleset or nil }
	MPAPI.MODIFIERS = {}
	-- Lobbies, Practice and playback all run in an MPAPI lobby carrying the ruleset.
	local meta = session and { ruleset = "ruleset_mp_" .. ruleset } or nil
	MPAPI.get_current_lobby = function()
		return meta and {
			get_metadata = function()
				return meta
			end,
		}
	end
end

local failures, sections = 0, 0

function H.check(condition, message)
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
	if failures == 0 then
		print(("All %d sections passed"):format(sections))
	else
		print(("%d of %d sections failed"):format(failures, sections))
		os.exit(1)
	end
end

return H
