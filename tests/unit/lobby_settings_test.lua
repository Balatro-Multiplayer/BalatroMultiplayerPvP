-- Plain Lua test for the lobby settings schema (lib/lobby_settings.lua), no game needed.
-- Run from the repo root: luajit tests/unit/lobby_settings_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

MPAPI = { Standing = { VERIFIED = "verified" } }
function MPAPI.is_launcher_verified() return false end
PVP = { LOBBY = { config = {} } }
dofile("lib/lobby_settings.lua")
dofile("lib/verified_lobby.lua")
local dictionary = dofile("localization/en-us.lua").misc.dictionary

local function standard(over)
	local c = { ruleset = PVP.LOBBY_STANDARD_RULESET, deck_mode = "select" }
	PVP.lobby_settings_apply_standard(c)
	for k, v in pairs(over or {}) do c[k] = v end
	return c
end
local function changed_keys(config, forced)
	local keys = {}
	for _, s in ipairs(PVP.lobby_settings_changed(config, forced)) do keys[#keys + 1] = s.key end
	return table.concat(keys, ",")
end
local function visible(key, config)
	return PVP.lobby_setting_visible(PVP.lobby_setting(key), config)
end

-- Schema shape
local cats = {}
for _, cat in ipairs(PVP.LOBBY_SETTING_CATEGORIES) do
	cats[cat.key] = true
	check("category label " .. cat.key, type(dictionary["k_pvp_cat_" .. cat.key]), "string")
end
for _, s in ipairs(PVP.LOBBY_SETTINGS) do
	check("category of " .. s.key, cats[s.cat], true)
	check("label " .. s.key, type(dictionary["k_pvp_set_" .. s.key]), "string")
	check("description " .. s.key, type(dictionary["k_pvp_set_" .. s.key .. "_desc"]), "string")
	if s.parent then
		check("parent of " .. s.key, PVP.lobby_setting(s.parent) ~= nil, true)
	end
	if s.std ~= nil then
		local found = false
		for _, v in ipairs(s.values) do found = found or v == s.std end
		check("standard is a value: " .. s.key, found, true)
	end
end

-- The verified baseline is the one the lobby used before the schema.
local OLD = {
	ruleset = "ruleset_mp_expanded", starting_lives = 4, pvp_start_round = 2, gold_on_life_loss = true,
	no_gold_on_round_loss = false, death_on_round_loss = true, the_order = true, normal_bosses = false,
	preview_disabled = false, smallerworld = false, trap_cards = false, timer = true, timer_base_seconds = 150,
	timer_increment_seconds = 60, pvp_countdown_seconds = 3, different_seeds = false, different_decks = false,
	random_loadout = false, custom_seed = "random",
}
local count = 0
for k, v in pairs(PVP.VERIFIED_DEFAULTS) do
	count = count + 1
	check("verified default " .. k, v, OLD[k])
end
check("verified default count", count, 19)

-- Metadata keys cover the old hand-kept list.
local keys = {}
for _, k in ipairs(PVP.lobby_settings_config_keys()) do keys[k] = true end
for _, k in ipairs({ "gold_on_life_loss", "no_gold_on_round_loss", "death_on_round_loss", "normal_bosses", "timer",
	"timer_base_seconds", "timer_increment_seconds", "pvp_countdown_seconds", "preview_disabled", "the_order",
	"smallerworld", "different_seeds", "different_decks", "random_loadout", "custom_seed" }) do
	check("metadata key " .. k, keys[k], true)
end

-- Changed from standard
check("standard lobby: nothing changed", changed_keys(standard()), "")
check("lives 6", changed_keys(standard({ starting_lives = 6 })), "starting_lives")
check("draft counts as standard", changed_keys(standard({ deck_mode = "draft" })), "")
check("different decks", changed_keys(standard({ different_decks = true })), "deck_mode")
check("preview off", changed_keys(standard({ preview_disabled = true })), "preview_disabled")
check("set seed", changed_keys(standard({ custom_seed = "ABCD" })), "seed_mode")
check("forced setting not counted", changed_keys(standard({ the_order = false }), { the_order = false }), "")
check("missing boolean reads off", changed_keys(standard({ trap_cards = nil })), "")
check("hunter lives has no standard", changed_keys(standard({ manhunt = true, manhunt_hunter_lives = 12 })), "")

-- Visibility
check("timer children shown", visible("timer_base_seconds", standard()), true)
check("timer children hidden", visible("timer_base_seconds", standard({ timer = false })), false)
check("random loadout hidden", visible("random_loadout", standard()), false)
check("random loadout shown", visible("random_loadout", standard({ different_decks = true })), true)
check("seed value hidden", visible("custom_seed", standard()), false)
check("seed value shown", visible("custom_seed", standard({ custom_seed = "ABCD" })), true)
check("smallerworld hidden", visible("smallerworld", standard()), false)
check("smallerworld shown", visible("smallerworld", standard({ ruleset = "ruleset_mp_smallworld" })), true)
check("hunter lives hidden", visible("manhunt_hunter_lives", standard()), false)

-- Virtual settings
local deck = PVP.lobby_setting("deck_mode")
local c = standard({ different_decks = true, random_loadout = true })
PVP.lobby_setting_set(deck, c, "draft")
check("deck mode draft", c.deck_mode, "draft")
check("leaving Different clears random loadout", c.random_loadout, false)
PVP.lobby_setting_set(deck, c, "different")
check("deck mode different", PVP.lobby_setting_get(deck, c), "different")
local seed = PVP.lobby_setting("seed_mode")
c = standard()
PVP.lobby_setting_set(seed, c, "set")
check("set seed gets a value", PVP.lobby_setting_get(seed, c), "set")
PVP.lobby_setting_set(seed, c, "random")
check("random seed clears it", c.custom_seed, "random")

-- Reset one / reset hidden / restore all
c = standard({ different_decks = true, random_loadout = true })
PVP.lobby_setting_apply_standard(deck, c)
check("reset deck mode", changed_keys(c), "")
check("reset deck mode clears random loadout", c.random_loadout, false)
c = standard({ smallerworld = true })
PVP.lobby_settings_reset_hidden(c)
check("hidden smallerworld goes back to off", c.smallerworld, false)
c = standard({ ruleset = "ruleset_mp_smallworld", smallerworld = true })
PVP.lobby_settings_reset_hidden(c)
check("shown smallerworld stays", c.smallerworld, true)
c = { ruleset = PVP.LOBBY_STANDARD_RULESET, gamemode = "gamemode_mp_attrition", starting_lives = 9, timer = false, different_seeds = true }
PVP.lobby_settings_apply_standard(c)
check("restore standard is verified", (PVP.verified_lobby_check(c, { { standing = "verified" } })), true)

-- Shown values
check("inverted reads flipped", PVP.lobby_setting_shown_value(PVP.lobby_setting("preview_disabled"), false), true)
check("value index", PVP.lobby_setting_index(PVP.lobby_setting("timer_base_seconds"), standard()), 5)

if failures > 0 then os.exit(1) end
print("ALL PASS")
