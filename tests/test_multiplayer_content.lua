-- Run from PvP's root: lua tests/test_multiplayer_content.lua /path/to/MultiplayerAPI
-- Uses the real layer/ruleset/pool code, with game and SMODS registration stubbed.
local api_root = assert(arg[1], "Pass the MultiplayerAPI checkout to test")
local function api(path)
	return dofile(api_root .. "/" .. path)
end
local checks = 0
local function check(condition, message)
	checks = checks + 1
	assert(condition, message)
end

G = { P_CENTERS = {}, P_CENTER_POOLS = {}, GAME = { banned_keys = {} } }
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
MPAPI = { sendDebugMessage = function() end, get_current_lobby = function() end }
api("api/layers/registry.lua")
api("api/layers/fields.lua")
api("api/layers/modifiers.lua")
api("api/layers/chain.lua")
api("api/layers/pool_gating.lua")
api("api/ruleset/constructor.lua")
api("api/ruleset/current.lua")

local session, practice = false, false
PVP = {
	id = "MultiplayerPvP",
	EXPERIMENTAL = {},
	LOBBY = { config = {} },
	SP = {},
	in_session = function()
		return session
	end,
	is_practice_mode = function()
		return practice
	end,
}
dofile("layers/_layers.lua")
dofile("rulesets/_rulesets.lua")
dofile("layers/multiplayer_content.lua")
dofile("layers/standard.lua")
dofile("layers/classic.lua")
dofile("layers/badlatro.lua")
dofile("layers/sandbox.lua")
dofile("layers/experimental.lua")
-- These layers' gameplay hooks are outside the content-membership contract.
for _, name in ipairs({ "ranked", "pvp_timer", "smallworld", "speedlatro_timer", "wsob" }) do
	MPAPI.Layer(name, {})
end
local rulesets = {
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
for _, short in ipairs(rulesets) do
	dofile("rulesets/" .. short .. ".lua")
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

local layer_key = PVP.LayerKey.MULTIPLAYER_CONTENT
local content = MPAPI.Layers[layer_key]
check(#content.included_jokers == 9, "nine original Jokers")
check(content.included_consumables[1] == "c_mp_asteroid", "Asteroid belongs to content layer")
check(content.reworked_jokers == nil, "originals are not reworks")
PVP.Ruleset({
	key = "content_only",
	multiplayer_content = true,
	layers = { layer_key },
}):inject()
for _, field in ipairs({ "included_jokers", "included_consumables", "included_vouchers" }) do
	for _, key in ipairs(content[field]) do
		check(G.P_CENTERS[key] and type(G.P_CENTERS[key].mp_include) == "function", key .. " registered and gated")
	end
end

local function context(short, mode)
	session, practice = mode ~= "vanilla", mode == "practice"
	PVP.SP.ruleset = practice and "ruleset_mp_" .. short or nil
	PVP.LOBBY.code = mode == "live" and "TEST" or nil
	PVP.LOBBY.config = {
		ruleset = not practice and "ruleset_mp_" .. short or nil,
	}
	MPAPI.MODIFIERS = {}
end

local enabled_rulesets = {
	"badlatro",
	"balanced",
	"expanded",
	"chaos",
	"sandbox",
	"smallworld",
	"speedlatro",
	"traditional",
	"experimental",
	"experimental_legacy",
	"content_only",
}
for _, short in ipairs(enabled_rulesets) do
	for _, mode in ipairs({ "live", "practice" }) do
		context(short, mode)
		check(PVP.is_layer_active(layer_key), short .. " explicitly composes content")
		check(PVP.multiplayer_content_enabled(), short .. " enables content in " .. mode)
		for _, key in ipairs(content.included_jokers) do
			check(not MPAPI.should_exclude_from_pool(G.P_CENTERS[key]), short .. ": " .. key .. " membership")
		end
		local conjoined_banned = false
		for _, key in ipairs(PVP.current_ruleset().banned_jokers) do
			if key == "j_mp_conjoined_joker" then conjoined_banned = true end
		end
		local expected_ban = short == "balanced"
			or short == "expanded"
			or short == "smallworld"
			or short == "speedlatro"
			or short == "traditional"
			or short == "sandbox"
			or short == "chaos"
		check(conjoined_banned == expected_ban, short .. ": layer composition controls Conjoined ban")
		check(not MPAPI.should_exclude_from_pool(G.P_CENTERS.c_mp_asteroid), short .. ": Asteroid included")
	end
end
for _, short in ipairs({ "vanilla", "legacy_ranked", "majorleague", "minorleague", "wsob" }) do
	context(short, "live")
	check(not PVP.is_layer_active(layer_key), short .. " does not compose content")
	check(MPAPI.should_exclude_from_pool(G.P_CENTERS.j_mp_pizza), short .. " excludes original content")
end

context("expanded", "practice")
check(#MPAPI.Rulesets.ruleset_mp_content_only.reworked_jokers == 0, "content can compose without balance reworks")
local expanded = MPAPI.Rulesets.ruleset_mp_expanded
local order = expanded._layer_order
expanded._layer_order = { "standard" }
check(PVP.current_ruleset().multiplayer_content == true, "standard retains its content flag")
check(MPAPI.should_exclude_from_pool(G.P_CENTERS.j_mp_pizza), "flag alone does not include content")
check(MPAPI.should_exclude_from_pool(G.P_CENTERS.j_mp_conjoined_joker), "Conjoined uses the generated layer gate")
expanded._layer_order = order
PVP.LOBBY.config.multiplayer_jokers = false
check(PVP.multiplayer_content_enabled(), "legacy boolean is no longer an independent pool veto")
PVP.set_multiplayer_content_mode(PVP.ContentMode.OFF)
for _, key in ipairs(content.included_jokers) do
	check(MPAPI.should_exclude_from_pool(G.P_CENTERS[key]), "Off layer excludes " .. key)
end
PVP.set_multiplayer_content_mode(PVP.ContentMode.DEFAULT)
MPAPI.Layer("content_off", { multiplayer_content = false })
MPAPI.add_modifier("content_off")
check(MPAPI.should_exclude_from_pool(G.P_CENTERS.j_mp_pizza), "resolved false flag still excludes content")
MPAPI.MODIFIERS = {}

local unlisted = { key = "j_mp_unlisted", mod = { id = PVP.id } }
SMODS.Joker.register(unlisted)
check(MPAPI.should_exclude_from_pool(unlisted), "mod ownership alone cannot admit unlisted content")
check(not G.P_CENTERS.v_mp_hieroglyph_manhunt:in_pool(), "Manhunt vouchers retain their format restriction")
PVP.LOBBY.config.manhunt = true
check(G.P_CENTERS.v_mp_hieroglyph_manhunt:in_pool(), "Manhunt voucher available in its format")
check(not MPAPI.should_exclude_from_pool(G.P_CENTERS.v_mp_hieroglyph_manhunt), "Manhunt voucher has explicit ownership")

context("experimental_legacy", "live")
check(not MPAPI.should_exclude_from_pool(G.P_CENTERS.j_mp_lets_go_gambling), "legacy LGG supplied by content layer")
check(#MPAPI.Rulesets.ruleset_mp_experimental_legacy.reworked_jokers == 1, "legacy only lists actual reworks")
context("sandbox", "live")
local magnet = G.P_CENTERS.j_mp_magnet_sandbox
local mapping
for _, candidate in ipairs(PVP.SANDBOX.joker_mappings) do
	if candidate.sandbox == magnet.key then mapping = candidate end
end
mapping.active = true
check(not MPAPI.should_exclude_from_pool(magnet), "Magnet still respects Sandbox membership")
PVP.set_multiplayer_content_mode(PVP.ContentMode.OFF)
check(MPAPI.should_exclude_from_pool(magnet), "Magnet retains the multiplayer-content restriction")
mapping.active = false
context("expanded", "vanilla")
check(MPAPI.should_exclude_from_pool(G.P_CENTERS.j_mp_pizza), "stale configuration does not leak into vanilla")
check(next(G.GAME.banned_keys) == nil, "membership decisions never create bans")

for _, short in ipairs({ "vanilla", "expanded" }) do
	for _, mode in pairs(PVP.ContentMode) do
		for _, run_context in ipairs({ "live", "practice" }) do
			context(short, run_context)
			PVP.set_multiplayer_content_mode(mode)
			local enabled = mode == PVP.ContentMode.ON or (mode == PVP.ContentMode.DEFAULT and short == "expanded")
			check(PVP.multiplayer_content_mode() == mode, short .. ": selection is derived from modifiers")
			check(PVP.multiplayer_content_enabled() == enabled, short .. ": " .. mode .. " in " .. run_context)
			for _, key in ipairs(content.included_jokers) do
				check(
					MPAPI.should_exclude_from_pool(G.P_CENTERS[key]) == not enabled,
					short .. ": " .. mode .. " " .. key
				)
			end
			local serialized = PVP.LOBBY.config.modifier_layers
			MPAPI.MODIFIERS = {}
			PVP.restore_modifier_layers(PVP.LOBBY.config.ruleset or PVP.SP.ruleset, serialized)
			check(PVP.multiplayer_content_enabled() == enabled, "native selection survives serialization")
		end
	end
end
context("vanilla", "live")
PVP.set_multiplayer_content_mode(PVP.ContentMode.ON)
check(MPAPI.Rulesets.ruleset_mp_vanilla.multiplayer_content == false, "On does not mutate the base ruleset")
PVP.set_multiplayer_content_mode(PVP.ContentMode.OFF)
check(not MPAPI.has_modifier(layer_key), "On and Off cannot remain selected together")
PVP.set_multiplayer_content_mode(PVP.ContentMode.DEFAULT)
check(#MPAPI.MODIFIERS == 0 and not PVP.multiplayer_content_enabled(), "Default restores Vanilla's empty pack")
PVP.restore_modifier_layers("ruleset_mp_experimental")
check(MPAPI.modifiers_serialize() == "pvp_timer,pressure_timer", "missing native metadata restores ruleset defaults")
PVP.restore_modifier_layers("ruleset_mp_expanded", nil, false)
check(PVP.multiplayer_content_mode() == PVP.ContentMode.OFF, "legacy false imports as an Off layer")
PVP.restore_modifier_layers("ruleset_mp_vanilla", nil, "true")
check(PVP.multiplayer_content_mode() == PVP.ContentMode.ON, "legacy true imports as an On layer")
PVP.restore_modifier_layers("ruleset_mp_vanilla", "", true)
check(PVP.multiplayer_content_mode() == PVP.ContentMode.DEFAULT, "native empty choice beats legacy boolean")
PVP.restore_modifier_layers("ruleset_mp_expanded", "pvp_timer,no_multiplayer_content", true)
check(MPAPI.modifiers_serialize() == "pvp_timer,no_multiplayer_content", "native order and Off beat legacy true")

-- Exercise actual option callbacks and metadata mirroring with a stub lobby.
-- These are contract tests, not assertions about the rendered in-game controls.
context("vanilla", "live")
G.FUNCS = {}
G.UIT = { R = "row" }
G.STAGES = { RUN = "run" }
localize = function(key)
	return key
end
create_UIBox_generic_options = function(options)
	return options
end
MPAPI.disableable_option_cycle = function(options)
	return { node = options }
end
MPAPI.refresh_current_view = function() end
MPAPI.LobbyEvent = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
PVP.reset_game_states = function() end
PVP.GAME = {}
PVP.PVP_GAMEMODES = { pvp_nemesis = { ruleset = "ruleset_mp_balanced", gamemode = "gamemode_mp_attrition" } }
PVP.LOBBY.deck = {}
PVP.REF_CHECKPOINT_KEY = "_ref"
dofile("pvp_api/flow.lua")
dofile("pvp_api/lobby_bridge.lua")
dofile("ui/lobby/lobby_options.lua")
PVP._pvp_kind = PVP.LobbyAccess.PRIVATE
PVP._pvp_gamemode = "pvp_nemesis"
local meta = { ruleset = "ruleset_mp_vanilla", modifier_layers = "" }
local handlers = {}
local started = false
local lobby = {
	is_host = true,
	player_id = "host",
	code = "TEST",
	get_players = function()
		return { { id = "host", displayName = "Host" } }
	end,
	get_metadata = function()
		return meta
	end,
	is_game_started = function()
		return started
	end,
	on = function(_, event, callback)
		handlers[event] = callback
	end,
	set_metadata = function(_, update)
		for key, value in pairs(update) do
			meta[key] = value
		end
		if handlers.METADATA_CHANGED then handlers.METADATA_CHANGED(update) end
	end,
}
MPAPI.get_current_lobby = function()
	return lobby
end
PVP.setup_lobby_mirror(lobby)
local picker = PVP.build_lobby_options().contents[2].nodes[1]
check(#picker.options == 3 and picker.current_option == 1, "private lobby exposes Default/On/Off")
G.FUNCS.mp_pvp_change_content({ to_key = 2 })
check(meta.modifier_layers == layer_key and PVP.multiplayer_content_enabled(), "host On updates shared native layers")
handlers.METADATA_CHANGED({ _ref = {} })
check(PVP.multiplayer_content_enabled(), "unrelated metadata updates do not reset the selection")
G.FUNCS.mp_pvp_change_ruleset({ to_key = 3 })
check(PVP.multiplayer_content_mode() == PVP.ContentMode.ON, "ruleset changes retain explicit On")
G.FUNCS.mp_pvp_change_content({ to_key = 3 })
check(not PVP.multiplayer_content_enabled(), "host Off suppresses inherited Expanded content")
G.FUNCS.mp_pvp_change_ruleset({ to_key = 1 })
check(PVP.multiplayer_content_mode() == PVP.ContentMode.OFF, "ruleset changes retain explicit Off")
G.FUNCS.mp_pvp_change_content({ to_key = 1 })
check(not PVP.multiplayer_content_enabled() and meta.modifier_layers == "", "Default follows Vanilla again")
lobby.is_host = false
G.FUNCS.mp_pvp_change_content({ to_key = 2 })
check(PVP.multiplayer_content_mode() == PVP.ContentMode.DEFAULT, "guest cannot change content")
lobby.is_host = true
started = true
G.FUNCS.mp_pvp_change_content({ to_key = 2 })
check(PVP.multiplayer_content_mode() == PVP.ContentMode.DEFAULT, "content cannot change during the run")
started = false
PVP._pvp_kind = PVP.LobbyAccess.RANKED
G.FUNCS.mp_pvp_change_content({ to_key = 2 })
check(PVP.multiplayer_content_mode() == PVP.ContentMode.DEFAULT, "ranked lobby cannot override content")
meta = { ruleset = "ruleset_mp_expanded", modifier_layers = "no_multiplayer_content" }
handlers.METADATA_CHANGED(meta)
check(not PVP.multiplayer_content_enabled(), "guest/rejoin metadata restores native Off")
meta = { ruleset = "ruleset_mp_vanilla" }
handlers.METADATA_CHANGED(meta)
check(PVP.multiplayer_content_mode() == PVP.ContentMode.DEFAULT, "older lobby without choices uses its base default")

-- A new ranked queue cannot inherit a private lobby's override.
PVP.GamemodeKey = { PVP_NEMESIS = "pvp_nemesis" }
MPAPI.GameModes = {}
MPAPI.matchmaking = {
	queue = function()
		return nil
	end,
}
sendWarnMessage = function() end
dofile("pvp_api/queue.lua")
PVP.set_multiplayer_content_mode(PVP.ContentMode.ON)
PVP._join_ranked_ruleset("ruleset_mp_vanilla")
check(PVP.multiplayer_content_mode() == PVP.ContentMode.DEFAULT, "ranked entry clears private On")
check(not PVP.multiplayer_content_enabled(), "ranked Vanilla retains its default pool")

-- Replay and rejoin framing must carry the recorded layer choice to bootstrap.
local captured
PVP._start_playback = function(bootstrap)
	captured = bootstrap
end
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
dofile("lib/rejoin.lua")
dofile("ui/replay/replay_browser.lua")
local events = {
	{ opcode = "match_manifest", args = { schema_version = 1 } },
	{
		opcode = "lobby_info",
		args = {
			gamemode = "pvp_nemesis",
			ruleset = "ruleset_mp_expanded",
			options = { modifier_layers = "no_multiplayer_content" },
		},
	},
	{ opcode = "run_info", args = { seed = "LAYER", deck = "Red Deck", stake = 1 } },
}
for _, event in ipairs(events) do
	event.player_id = "host"
end
MPAPI.replay.get = function(_, callback)
	callback(nil, { logs = events })
end
PVP._launch_replay("test")
check(captured.modifier_layers == "no_multiplayer_content", "replay bootstrap retains recorded Off")
PVP._launch_rejoin({ events = events })
check(captured.modifier_layers == "no_multiplayer_content", "rejoin bootstrap retains recorded Off")
events[2].args.options = { multiplayer_jokers = false }
PVP._launch_rejoin({ events = events })
check(captured.multiplayer_jokers == false, "legacy recorded false survives bootstrap")

print(("Multiplayer content contracts: %d checks passed"):format(checks))
