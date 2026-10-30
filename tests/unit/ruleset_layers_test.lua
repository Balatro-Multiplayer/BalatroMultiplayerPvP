-- Plain Lua test for the Balanced and Expanded layers and the rulesets that list them (no game needed).
-- Run from the repo root: luajit tests/unit/ruleset_layers_test.lua
-- MPAPI_DIR points at the BalatroMultiplayerAPI checkout (default ../BalatroMultiplayerAPI/).
local api = os.getenv("MPAPI_DIR") or "../BalatroMultiplayerAPI/"
if api:sub(-1) ~= "/" then api = api .. "/" end

MPAPI = {}
dofile(api .. "api/layers/registry.lua")
dofile(api .. "api/layers/fields.lua")
MPAPI.MODIFIERS = {}

PVP = { LayerKey = { SANDBOX = "sandbox" } }
local resolved = {}
function PVP.Ruleset(init)
	resolved[init.key] = MPAPI.resolve_layers(init)
	return { inject = function() end }
end
local reworks = {}
function PVP.ReworkCenter(key, opts)
	reworks[#reworks + 1] = { key = key, layers = opts.layers }
end

-- Layers with game code stay out of this test; only their names matter to the rulesets.
for _, name in ipairs({ "sandbox", "smallworld", "speedlatro_timer", "classic", "wsob" }) do
	MPAPI.Layer(name, {})
end
for _, name in ipairs({ "pvp_timer", "balanced", "expanded" }) do
	dofile("layers/" .. name .. ".lua")
end
local ruleset_names = { "balanced", "expanded", "traditional", "speedlatro", "smallworld", "chaos" }
for _, name in ipairs(ruleset_names) do
	dofile("rulesets/" .. name .. ".lua")
end
dofile("objects/enhancements/mp_glass.lua")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local function sorted_list(list)
	local copy = {}
	for i, v in ipairs(list) do copy[i] = v end
	table.sort(copy)
	return table.concat(copy, ",")
end

-- What Expanded, and every ruleset that lists both layers, resolved to when they listed the single shared layer.
local full = {
	banned_jokers = "j_mp_conjoined_joker,j_mp_defensive_joker,j_mp_speedrun",
	banned_consumables = "c_justice",
	banned_silent = "c_ouija,j_bloodstone,j_hanging_chad,j_selzer,j_ticket,j_turtle_bean",
	reworked_jokers = "j_mp_bloodstone,j_mp_hanging_chad,j_mp_seltzer,j_mp_ticket,j_mp_turtle_bean",
	reworked_consumables = "c_mp_ouija_standard",
	reworked_enhancements = "m_glass",
}
-- Balanced keeps the Hanging Chad, Bloodstone and Glass reworks and the Justice ban, and nothing else.
local near_vanilla = {
	banned_jokers = "",
	banned_consumables = "c_justice",
	banned_silent = "j_bloodstone,j_hanging_chad",
	reworked_jokers = "j_mp_bloodstone,j_mp_hanging_chad",
	reworked_consumables = "",
	reworked_enhancements = "m_glass",
}

for _, name in ipairs(ruleset_names) do
	local want = name == "balanced" and near_vanilla or full
	for field, expected in pairs(want) do
		check(name .. " " .. field, sorted_list(resolved[name][field] or {}), expected)
	end
	check(name .. " PvP-only cards", resolved[name].multiplayer_content, name ~= "balanced")
end
check("balanced timer", resolved.balanced.pvp_timer_base_seconds, 60)
check("expanded timer", resolved.expanded.pvp_timer_base_seconds, 60)

-- Glass is on in a ruleset when any layer it names is in that ruleset's layer chain.
local glass_layers
for _, rework in ipairs(reworks) do
	if rework.key == "m_glass" and type(rework.layers) == "table" then glass_layers = rework.layers end
end
local function glass_on(ruleset_short)
	local chain = { [ruleset_short] = true }
	for _, layer in ipairs(resolved[ruleset_short]._layer_order) do chain[layer] = true end
	for _, layer in ipairs(glass_layers) do
		if chain[layer] then return true end
	end
	return false
end
for _, name in ipairs(ruleset_names) do
	check("glass in " .. name, glass_on(name), true)
end

check("old shared layer is gone", MPAPI.Layers.standard, nil)

-- The later layer wins a scalar, so the layer after the one that turns PvP-only cards off turns them on.
check("balanced layer alone turns PvP-only cards off", MPAPI.Layers.balanced.multiplayer_content, false)
check("expanded layer turns PvP-only cards on", MPAPI.Layers.expanded.multiplayer_content, true)
MPAPI.Layer("test_off", { multiplayer_content = false })
MPAPI.Layer("test_on", { multiplayer_content = true })
check(
	"later layer on beats earlier layer off",
	MPAPI.resolve_layers({ key = "a", layers = { "test_off", "test_on" } }).multiplayer_content,
	true
)
check(
	"later layer off beats earlier layer on",
	MPAPI.resolve_layers({ key = "b", layers = { "test_on", "test_off" } }).multiplayer_content,
	false
)

if failures > 0 then
	os.exit(1)
end
