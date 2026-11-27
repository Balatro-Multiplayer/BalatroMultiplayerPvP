-- The private lobby's settings, as data. One entry per setting the host can change in
-- Lobby Options (ui/lobby/options/). The screen, the "changed from default" marks,
-- the metadata keys (pvp_api/flow.lua)
-- and the lobby's rules strip (ui/lobby/rules_strip.lua) all read this table, so a new
-- knob is one entry here plus its two localization keys:
--   k_pvp_set_<key>       the row label
--   k_pvp_set_<key>_desc  the description pane text, one line per \n
--
-- Entry fields:
--   key            the PVP.LOBBY.config key (or a virtual key, see get/set)
--   cat            a PVP.LOBBY_SETTING_CATEGORIES key
--   values         the values the row cycles through (a boolean setting defaults to off/on)
--   default        base value when neither ruleset nor host chooses one
--   invert         a boolean the row shows flipped ("Score preview: On" for preview_disabled = false)
--   suffix         appended to a number value ("150s")
--   parent         the setting this one hangs under; without `shown` it shows while the parent is on
--   shown          function(config) -> whether the row shows
--   description_variant  optional suffix for the description key, chosen for this lobby
--   type           "text": a free-text value edited in its own overlay
--   get / set      a virtual setting: one control over several config keys
--   writes         a virtual setting's config keys
--   needs          { [value] = need } a value only some lobbies can pick ("server_referee")
--   when           { key, value } the condition the description pane names ("Shown when");
--                  key is a setting, "ruleset" or "gamemode". Default: { parent, true }.
--   inactive       effective value while its condition is false; does not erase host intent
--   art            a tile's letter (the "tiles" category)

local function range(first, last, step)
	local values = {}
	for v = first, last, step or 1 do
		values[#values + 1] = v
	end
	return values
end

local BOOL = { false, true }

-- PVP.DeckMode lives in pvp_api/flow.lua, which loads after lib/; its values are these.
local DECK_SELECT, DECK_DRAFT = "select", "draft"
local DEFAULT_FIXED_SEED = "AAAAAAAA"

PVP.LOBBY_SETTING_CATEGORIES = {
	{ key = "match" },
	{ key = "decks" },
	{ key = "blinds" },
	{ key = "loss" },
	{ key = "clock" },
	{ key = "mutators", layout = "tiles" },
}

PVP.LOBBY_SETTINGS = {
	{
		key = "starting_lives", cat = "match", values = range(1, 16), default = 4,
		shown = function(config) return not config.manhunt end,
		description_variant = function(config) return config.team_based and "teams" or nil end,
	},
	{ key = "pvp_start_round", cat = "match", values = range(1, 20), default = 2 },
	{ key = "preview_disabled", cat = "match", default = false, invert = true },
	{
		key = "manhunt_hunter_lives",
		cat = "match",
		default = 7,
		values = range(7, 16),
		when = { "gamemode", "pvp_manhunt" },
		shown = function(config)
			return config.manhunt == true
		end,
	},

	{
		key = "deck_mode",
		cat = "decks",
		values = { "select", "draft", "different" },
		default = "select",
		needs = { draft = "server_referee" },
		writes = { "deck_mode", "different_decks", "random_loadout" },
		get = function(config)
			if config.different_decks == true then
				return "different"
			end
			return config.deck_mode == DECK_DRAFT and "draft" or "select"
		end,
		set = function(config, value)
			config.deck_mode = value == "draft" and DECK_DRAFT or DECK_SELECT
			config.different_decks = value == "different"
			if value ~= "different" then
				config.random_loadout = false
			end
		end,
	},
	{
		key = "random_loadout",
		cat = "decks",
		default = false,
		inactive = false,
		parent = "deck_mode",
		when = { "deck_mode", "different" },
		shown = function(config)
			return config.different_decks == true
		end,
	},
	{
		key = "seed_mode",
		cat = "decks",
		values = { "random", "set", "different" },
		default = "random",
		writes = { "different_seeds", "custom_seed" },
		get = function(config)
			if config.different_seeds == true then
				return "different"
			end
			local seed = config.custom_seed
			return (seed ~= nil and seed ~= "" and seed ~= "random") and "set" or "random"
		end,
		set = function(config, value)
			config.different_seeds = value == "different"
			if value ~= "set" then
				config.custom_seed = "random"
			else
				-- A fixed seed is filled by the custom_seed setting below.
				config.custom_seed = DEFAULT_FIXED_SEED
			end
		end,
	},
	{
		key = "custom_seed",
		cat = "decks",
		default = DEFAULT_FIXED_SEED,
		type = "text",
		parent = "seed_mode",
		when = { "seed_mode", "set" },
		inactive = "random",
		writes = {},
		shown = function(config)
			local seed = config.custom_seed
			return config.different_seeds ~= true and seed ~= nil and seed ~= "" and seed ~= "random"
		end,
	},

	{ key = "normal_bosses", cat = "blinds", default = false },
	{ key = "the_order", cat = "blinds", default = true },

	{ key = "gold_on_life_loss", cat = "loss", default = true },
	{ key = "no_gold_on_round_loss", cat = "loss", default = false, invert = true },
	{ key = "death_on_round_loss", cat = "loss", default = true },

	{ key = "timer", cat = "clock", default = true },
	{ key = "timer_base_seconds", cat = "clock", values = range(30, 240, 30), suffix = "s", default = 150, parent = "timer" },
	{
		key = "timer_increment_seconds", cat = "clock", values = range(0, 180, 30), suffix = "s", default = 60, parent = "timer",
		description_variant = function()
			local mode = PVP.UTILS.skip_increment_mode()
			return mode ~= "unmatched" and mode or nil
		end,
	},
	{ key = "pvp_countdown_seconds", cat = "clock", values = { 0, 3, 5, 10 }, suffix = "s", default = 3 },

	{ key = "trap_cards", cat = "mutators", default = false, art = "!" },
	{
		key = "smallerworld",
		cat = "mutators",
		default = false,
		art = "S",
		when = { "ruleset", "ruleset_mp_smallworld" },
		inactive = false,
		shown = function(config)
			return config.ruleset == "ruleset_mp_smallworld"
		end,
	},
	-- Used by the league rulesets, not offered as an editable row.
	{ key = "timer_forgiveness", default = 0, values = { 0, 1 }, hidden = true },
}

-- The standard ruleset, which the header picks rather than a row.
PVP.LOBBY_STANDARD_RULESET = "ruleset_mp_expanded"

local by_key = {}
for _, setting in ipairs(PVP.LOBBY_SETTINGS) do
	if setting.values == nil and setting.type ~= "text" then
		setting.values = BOOL
	end
	by_key[setting.key] = setting
end

function PVP.lobby_setting(key)
	return by_key[key]
end

local function is_bool(setting)
	return setting.values == BOOL
end

function PVP.lobby_setting_get(setting, config)
	if setting.get then
		return setting.get(config)
	end
	local value = config[setting.key]
	if is_bool(setting) then
		return value == true
	end
	return value
end

function PVP.lobby_setting_set(setting, config, value)
	if setting.set then
		setting.set(config, value)
	else
		config[setting.key] = value
	end
end

-- The value as the row shows it: an inverted boolean reads flipped.
function PVP.lobby_setting_shown_value(setting, value)
	if setting.invert then
		return not value
	end
	return value
end

-- The row's value index within setting.values (1 when the value is not one of them).
function PVP.lobby_setting_index(setting, config)
	local value = PVP.lobby_setting_get(setting, config)
	for i, v in ipairs(setting.values or {}) do
		if v == value then
			return i
		end
	end
	return 1
end

function PVP.lobby_setting_visible(setting, config)
	if setting.hidden then return false end
	local parent = setting.parent and by_key[setting.parent]
	if parent and not PVP.lobby_setting_visible(parent, config) then
		return false
	end
	if setting.shown then
		return setting.shown(config) and true or false
	end
	if parent then
		return PVP.lobby_setting_get(parent, config) == true
	end
	return true
end

function PVP.lobby_setting_default(setting, policy)
	local entry = policy[setting.key]
	if entry and entry.default ~= nil then return entry.default end
	return setting.default
end

function PVP.lobby_setting_locked(setting, policy)
	local entry = policy[setting.key]
	return entry ~= nil and entry.locked ~= nil
end

-- Visible deviations from this ruleset's defaults, not a ranked eligibility check.
function PVP.lobby_settings_changed(config, policy)
	policy = policy or {}
	local changed = {}
	for _, setting in ipairs(PVP.LOBBY_SETTINGS) do
		if
			not PVP.lobby_setting_locked(setting, policy)
			and PVP.lobby_setting_visible(setting, config)
			and PVP.lobby_setting_get(setting, config) ~= PVP.lobby_setting_default(setting, policy)
		then
			changed[#changed + 1] = setting
		end
	end
	return changed
end

-- Every config key the settings write, sorted: what the lobby metadata carries.
function PVP.lobby_settings_config_keys()
	local seen, keys = {}, {}
	local function add(key)
		if not seen[key] then
			seen[key] = true
			keys[#keys + 1] = key
		end
	end
	for _, setting in ipairs(PVP.LOBBY_SETTINGS) do
		if setting.writes then
			for _, key in ipairs(setting.writes) do
				add(key)
			end
		else
			add(setting.key)
		end
	end
	table.sort(keys)
	return keys
end

function PVP.lobby_settings_policy(ruleset_key)
	local def = MPAPI.Rulesets and MPAPI.Rulesets[ruleset_key]
	return def and def.lobby_settings or {}
end

function PVP.lobby_setting_accepts(setting, value)
	if setting.type == "text" then
		return type(value) == "string" and #value > 0 and #value <= 8 and value ~= "random"
	end
	for _, candidate in ipairs(setting.values) do
		if candidate == value then return true end
	end
	return false
end

-- Project intent into gameplay's existing fields. Schema order writes parents before
-- their children (notably deck/seed mode). Never infer intent from the last projection.
function PVP.resolve_lobby_settings(config, choices, policy)
	for key, entry in pairs(policy) do
		local field = type(entry) == "table" and next(entry)
		assert(by_key[key] and (field == "default" or field == "locked") and not next(entry, field),
			"expected one default or locked value for lobby setting " .. tostring(key))
		assert(PVP.lobby_setting_accepts(by_key[key], entry[field]), "invalid lobby_settings value: " .. key)
	end
	for _, setting in ipairs(PVP.LOBBY_SETTINGS) do
		local key = setting.key
		local value = choices[key]
		if PVP.lobby_setting_locked(setting, policy) then
			value = policy[key].locked
		elseif not PVP.lobby_setting_accepts(setting, value) then
			value = PVP.lobby_setting_default(setting, policy)
		end
		if setting.inactive ~= nil and not PVP.lobby_setting_visible(setting, config) then
			value = setting.inactive
		end
		PVP.lobby_setting_set(setting, config, value)
	end
end

function PVP.resolve_current_lobby_settings()
	local config = PVP.LOBBY.config
	PVP.resolve_lobby_settings(config, PVP.LOBBY.setting_choices or {}, PVP.lobby_settings_policy(config.ruleset))
end
