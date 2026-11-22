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
	PVP.resolve_lobby_settings(c, {}, {})
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
	if not s.hidden then
		check("category of " .. s.key, cats[s.cat], true)
		check("label " .. s.key, type(dictionary["k_pvp_set_" .. s.key]), "string")
		check("description " .. s.key, type(dictionary["k_pvp_set_" .. s.key .. "_desc"]), "string")
	end
	if s.parent then
		check("parent of " .. s.key, PVP.lobby_setting(s.parent) ~= nil, true)
	end
	check("default is a value: " .. s.key, PVP.lobby_setting_accepts(s, s.default), true)
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
check("draft differs from the lobby default", changed_keys(standard({ deck_mode = "draft" })), "deck_mode")
check("different decks", changed_keys(standard({ different_decks = true })), "deck_mode")
check("preview off", changed_keys(standard({ preview_disabled = true })), "preview_disabled")
check("set seed", changed_keys(standard({ custom_seed = "ABCD" })), "seed_mode,custom_seed")
check("locked setting not counted", changed_keys(standard({ the_order = false }), { the_order = { locked = false } }), "")
check("missing boolean reads off", changed_keys(standard({ trap_cards = nil })), "")
check("non-default hunter lives are visible", changed_keys(standard({ manhunt = true, manhunt_hunter_lives = 12 })), "manhunt_hunter_lives")

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

-- Inactive options are harmless in gameplay; a ruleset switch doesn't erase intent.
local choices = { smallerworld = true, random_loadout = true, deck_mode = "different" }
c = standard()
PVP.resolve_lobby_settings(c, choices, { deck_mode = { locked = "draft" } })
check("hidden smallerworld is off", c.smallerworld, false)
check("locked draft masks random loadout", c.random_loadout, false)
c.ruleset = "ruleset_mp_smallworld"
PVP.resolve_lobby_settings(c, choices, {})
check("unmasked smallerworld", c.smallerworld, true)
check("unmasked random loadout", c.random_loadout, true)
c = { ruleset = PVP.LOBBY_STANDARD_RULESET, gamemode = "gamemode_mp_attrition", starting_lives = 9, timer = false, different_seeds = true }
PVP.resolve_lobby_settings(c, {}, {})
check("restore standard is verified", (PVP.verified_lobby_check(c, { { standing = "verified" } })), true)

-- Shown values
check("inverted reads flipped", PVP.lobby_setting_shown_value(PVP.lobby_setting("preview_disabled"), false), true)
check("value index", PVP.lobby_setting_index(PVP.lobby_setting("timer_base_seconds"), standard()), 5)

if failures > 0 then os.exit(1) end
print("ALL PASS")
