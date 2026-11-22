-- The private lobby's settings, as data. One entry per setting the host can change in
-- Lobby Options (ui/lobby/options/). The screen, the "changed from standard" marks, the
-- verified-lobby baseline (lib/verified_lobby.lua), the metadata keys (pvp_api/flow.lua)
-- and the lobby's rules strip (ui/lobby/rules_strip.lua) all read this table, so a new
-- knob is one entry here plus its two localization keys:
--   k_pvp_set_<key>       the row label
--   k_pvp_set_<key>_desc  the description pane text, one line per \n
--
-- Entry fields:
--   key            the PVP.LOBBY.config key (or a virtual key, see get/set)
--   cat            a PVP.LOBBY_SETTING_CATEGORIES key
--   values         the values the row cycles through (a boolean setting defaults to off/on)
--   std            the standard value: a standard ranked match (the Expanded ruleset).
--                  nil: the setting has no standard and never counts as changed.
--   also_standard  { [value] = true } for other values that still count as standard
--   invert         a boolean the row shows flipped ("Score preview: On" for preview_disabled = false)
--   suffix         appended to a number value ("150s")
--   parent         the setting this one hangs under; without `shown` it shows while the parent is on
--   shown          function(config) -> whether the row shows
--   type           "text": a free-text value edited in its own overlay
--   get / set      a virtual setting: one control over several config keys
--   writes         a virtual setting's config keys
--   standard_config  a virtual setting's standard, as the config values it means
--   needs          { [value] = need } a value only some lobbies can pick ("server_referee")
--   when           { key, value } the condition the description pane names ("Shown when");
--                  key is a setting, "ruleset" or "gamemode". Default: { parent, true }.
--   reset_when_hidden  back to standard whenever the row hides (its condition is not a
--                  changed setting, so a hidden value would hold the lobby off standard)
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

PVP.LOBBY_SETTING_CATEGORIES = {
	{ key = "match" },
	{ key = "decks" },
	{ key = "blinds" },
	{ key = "loss" },
	{ key = "clock" },
	{ key = "mutators", layout = "tiles" },
}

PVP.LOBBY_SETTINGS = {
	{ key = "starting_lives", cat = "match", values = range(1, 16), std = 4 },
	{ key = "pvp_start_round", cat = "match", values = range(1, 20), std = 2 },
	{ key = "preview_disabled", cat = "match", std = false, invert = true },
	{
		key = "manhunt_hunter_lives",
		cat = "match",
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
		std = "select",
		also_standard = { draft = true },
		needs = { draft = "server_referee" },
		writes = { "deck_mode", "different_decks", "random_loadout" },
		standard_config = { different_decks = false, random_loadout = false },
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
		std = false,
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
		std = "random",
		writes = { "different_seeds", "custom_seed" },
		standard_config = { different_seeds = false, custom_seed = "random" },
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
			elseif (config.custom_seed or "random") == "random" then
				-- A set seed needs a value at all; start from a fresh one.
				config.custom_seed = generate_starting_seed and generate_starting_seed() or "AAAAAAAA"
			end
		end,
	},
	{
		key = "custom_seed",
		cat = "decks",
		type = "text",
		parent = "seed_mode",
		when = { "seed_mode", "set" },
		writes = {},
		shown = function(config)
			local seed = config.custom_seed
			return config.different_seeds ~= true and seed ~= nil and seed ~= "" and seed ~= "random"
		end,
	},

	{ key = "normal_bosses", cat = "blinds", std = false },
	{ key = "the_order", cat = "blinds", std = true },

	{ key = "gold_on_life_loss", cat = "loss", std = true },
	{ key = "no_gold_on_round_loss", cat = "loss", std = false, invert = true },
	{ key = "death_on_round_loss", cat = "loss", std = true },

	{ key = "timer", cat = "clock", std = true },
	{ key = "timer_base_seconds", cat = "clock", values = range(30, 240, 30), suffix = "s", std = 150, parent = "timer" },
	{ key = "timer_increment_seconds", cat = "clock", values = range(0, 180, 30), suffix = "s", std = 60, parent = "timer" },
	{ key = "pvp_countdown_seconds", cat = "clock", values = { 0, 3, 5, 10 }, suffix = "s", std = 3 },

	{ key = "trap_cards", cat = "mutators", std = false, art = "!" },
	{
		key = "smallerworld",
		cat = "mutators",
		std = false,
		art = "S",
		when = { "ruleset", "ruleset_mp_smallworld" },
		reset_when_hidden = true,
		shown = function(config)
			return config.ruleset == "ruleset_mp_smallworld"
		end,
	},
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

function PVP.lobby_setting_is_standard(setting, config)
	if setting.std == nil then
		return true
	end
	local value = PVP.lobby_setting_get(setting, config)
	return value == setting.std or (setting.also_standard ~= nil and setting.also_standard[value] == true)
end

-- Puts every hidden reset_when_hidden setting back to standard. Run after any change.
function PVP.lobby_settings_reset_hidden(config)
	for _, setting in ipairs(PVP.LOBBY_SETTINGS) do
		if setting.reset_when_hidden and not PVP.lobby_setting_visible(setting, config) then
			PVP.lobby_setting_apply_standard(setting, config)
		end
	end
end

-- The settings a lobby has changed from standard, in schema order: visible ones only,
-- and none a ruleset forces (forced: { [key] = value }, see PVP.lobby_forced_settings).
function PVP.lobby_settings_changed(config, forced)
	local changed = {}
	for _, setting in ipairs(PVP.LOBBY_SETTINGS) do
		if
			not (forced and forced[setting.key] ~= nil)
			and PVP.lobby_setting_visible(setting, config)
			and not PVP.lobby_setting_is_standard(setting, config)
		then
			changed[#changed + 1] = setting
		end
	end
	return changed
end

-- The config values that make a lobby standard (the ruleset is the caller's, it is not a row).
function PVP.lobby_settings_standard_config()
	local values = {}
	for _, setting in ipairs(PVP.LOBBY_SETTINGS) do
		if setting.standard_config then
			for key, value in pairs(setting.standard_config) do
				values[key] = value
			end
		elseif setting.std ~= nil then
			values[setting.key] = setting.std
		end
	end
	return values
end

function PVP.lobby_settings_apply_standard(config)
	for key, value in pairs(PVP.lobby_settings_standard_config()) do
		config[key] = value
	end
end

function PVP.lobby_setting_apply_standard(setting, config)
	if setting.standard_config then
		for key, value in pairs(setting.standard_config) do
			config[key] = value
		end
	elseif setting.std ~= nil then
		PVP.lobby_setting_set(setting, config, setting.std)
	end
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

-- The settings a ruleset forces in a private lobby, as { [key] = value }. Rulesets force
-- them by assignment (PVP.force_lobby_options); this runs that against a scratch config and
-- reads back what was written, so a ruleset or layer adding a forced option shows up here.
function PVP.lobby_forced_settings(ruleset_key)
	if not (ruleset_key and PVP.force_lobby_options and PVP.LobbyAccess) then
		return {}
	end
	local real = PVP.LOBBY.config
	local scratch = {}
	PVP.LOBBY.config = scratch
	local ok = pcall(PVP.force_lobby_options, PVP.LobbyAccess.PRIVATE, ruleset_key)
	PVP.LOBBY.config = real
	local forced = {}
	if ok then
		for key, value in pairs(scratch) do
			if by_key[key] then
				forced[key] = value
			end
		end
	end
	return forced
end
