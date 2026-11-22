-- luajit tests/unit/lobby_settings_flow_test.lua
-- Real settings handlers, rulesets, layer composition, metadata writer and guest mirror.
-- Stub the UI refresh and transport; deliver snapshots explicitly to model host migration.
local api = (os.getenv("MPAPI_DIR") or "../BalatroMultiplayerAPI") .. "/"
local noop = function() end
local lobby = { is_host = true, is_game_started = function() return false end }
local metadata, sends = {}, 0
function lobby:set_metadata(patch) metadata, sends = patch, sends + 1 end
function lobby:get_metadata() return metadata end
MPAPI = {
	Rulesets = {}, Party = { KIND = "party" }, get_current_lobby = function() return lobby end,
	has_server_referee = function() return false end,
}
G = { FUNCS = {} }
PVP = {
	LayerKey = { SANDBOX = "sandbox", MULTIPLAYER_CONTENT = "multiplayer_content" },
	PVP_GAMEMODES = { pvp_nemesis = { ruleset = "ruleset_mp_expanded", gamemode = "gamemode_mp_attrition" } },
	MatchmakingPolicy = { cocktail_recipe = noop }, compute_verified_lobby = function() return false end,
}
dofile(api .. "api/layers/registry.lua")
dofile(api .. "api/layers/fields.lua")
dofile(api .. "api/layers/modifiers.lua")
MPAPI.Ruleset = function(init)
	MPAPI.Rulesets[init.key] = MPAPI.resolve_layers(init)
	return { inject = noop }
end
dofile("rulesets/_rulesets.lua")
for _, name in ipairs({ "balanced", "expanded", "expanded_draft", "multiplayer_content", "pvp_timer", "majorleague", "sandbox" }) do
	MPAPI.Layer(name, {})
end
for _, name in ipairs({ "vanilla", "expanded", "sandbox", "minorleague", "majorleague", "traditional" }) do
	dofile("rulesets/" .. name .. ".lua")
end
MPAPI.Layer("more_lives", { lobby_settings = { starting_lives = { default = 6 } } })
PVP.Ruleset({ key = "balanced", layers = { "more_lives" } })
dofile("lib/lobby_settings.lua")
dofile("pvp_api/flow.lua")
dofile("pvp_api/setup.lua")
dofile("pvp_api/lobby_bridge.lua")
dofile("ui/lobby/options/_widgets.lua")
dofile("ui/lobby/options/actions.lua")
PVP.lobby_opts.refresh = noop
local F, R = G.FUNCS, PVP.RulesetKey
local function fresh()
	PVP.LOBBY = { config = { ruleset = R.EXPANDED }, deck = {}, setting_choices = {} }
	PVP.resolve_current_lobby_settings()
end
local function set(key, value)
	F.mp_pvp_opt_cycle({ cycle_config = { setting_key = key, setting_values = { value } }, to_key = 1 })
end
local function switch(dir)
	F.mp_pvp_opt_ruleset({ config = { ref_table = { dir = dir } } })
end
local function reset(key)
	F.mp_pvp_opt_reset({ config = { ref_table = { key = key } } })
end

PVP._pvp_kind, PVP._pvp_gamemode = "private", "pvp_nemesis"
fresh()
set("the_order", true) -- Explicitly choose even though it's the base default.
switch(-2)
assert(metadata.ruleset == R.VANILLA and metadata.the_order == false and metadata.setting_choices.the_order == true)
local before = sends
set("the_order", true)
reset("the_order")
assert(sends == before, "locked setting accepted a write")

-- A guest joins while the lock is active, then takes over. No local history.
fresh()
lobby.is_host = false
PVP.mirror_lobby_metadata(lobby)
assert(PVP.LOBBY.config.the_order == false and PVP.LOBBY.setting_choices.the_order == true)
set("starting_lives", 10)
assert(sends == before, "guest wrote settings")
lobby.is_host = true
switch(2)
assert(metadata.ruleset == R.EXPANDED and metadata.the_order == true, "masked choice lost across migration")
set("the_order", false)
switch(-2)
switch(2)
assert(metadata.the_order == false, "an explicit false is not absence")

switch(-1)
assert(metadata.ruleset == R.BALANCED and metadata.starting_lives == 6, "layer default")
set("starting_lives", 6)
switch(1)
assert(metadata.starting_lives == 6, "selecting the default is still a choice")
reset("starting_lives")
assert(metadata.starting_lives == 4 and metadata.setting_choices.starting_lives == nil)
switch(-1)
assert(metadata.starting_lives == 6, "reset must follow future defaults")
before = sends
set("starting_lives", 17)
set("deck_mode", "draft")
set("custom_seed", "HIDDEN")
assert(sends == before, "invalid, unavailable or hidden choice was accepted")
F.mp_pvp_opt_restore()
assert(metadata.ruleset == R.EXPANDED and next(metadata.setting_choices) == nil and metadata.the_order == true)

-- A seed is rolled once, not again on each mirror. Submitting an open editor
-- must recheck editability (the host can change while it is on screen).
generate_starting_seed = function() return "TESTSEED" end
set("seed_mode", "set")
assert(metadata.custom_seed == "TESTSEED")
PVP.mirror_lobby_metadata(lobby)
assert(PVP.LOBBY.config.custom_seed == "TESTSEED")
local submit
G.UIT, G.C = { R = 1, T = 2 }, { UI = {} }
localize = function(key) return key end
create_text_input = function(args) submit = args.callback; return {} end
create_UIBox_generic_options, F.overlay_menu = noop, noop
F.mp_pvp_seed_overlay()
PVP.LOBBY.temp_seed = "EDITED"
before, lobby.is_host = sends, false
submit()
assert(sends == before and PVP.LOBBY.config.custom_seed == "TESTSEED")
lobby.is_host = true
submit()
assert(metadata.custom_seed == "EDITED")
F.mp_pvp_opt_restore()

-- Check an empty override snapshot actually clears old choices on another client.
PVP.LOBBY.setting_choices = { the_order = false }
PVP.mirror_lobby_metadata(lobby)
assert(next(PVP.LOBBY.setting_choices) == nil and PVP.LOBBY.config.the_order == true)

-- Casual's vote and Ranked's metadata must resolve the same league settings.
metadata = { kind = "casual", ruleset = R.EXPANDED }
lobby._game = { setup = { results = { ruleset = { option = "majorleague" } } } }
PVP.mirror_lobby_metadata(lobby)
assert(PVP.LOBBY.config.timer_base_seconds == 180 and PVP.LOBBY.config.preview_disabled and not PVP.LOBBY.config.the_order)
lobby._game = nil
metadata = { kind = "ranked", ruleset = "ruleset_mp_minorleague" }
PVP.mirror_lobby_metadata(lobby)
assert(PVP.LOBBY.config.timer_forgiveness == 1 and PVP.LOBBY.config.timer_base_seconds == 210 and PVP.LOBBY.config.the_order)
metadata.ruleset = R.EXPANDED
PVP.mirror_lobby_metadata(lobby)
assert(PVP.LOBBY.config.timer_forgiveness == 0 and PVP.LOBBY.config.timer_base_seconds == 150)

-- False is a valid default or lock, but an ambiguous or mistyped declaration isn't.
for _, policy in ipairs({
	{ the_order = { locked = false, default = true } }, { timer = {} },
	{ timer = { default = true, enabled = false } },
	{ starting_lives = { default = "4" } }, { unknown = { locked = true } },
}) do
	assert(not pcall(PVP.resolve_lobby_settings, {}, {}, policy))
end
print("Lobby settings flow passed")
