-- Lobby Options building blocks: a setting row, a mutator tile, a category button and
-- the description pane. Every one is built from a lobby settings entry
-- (lib/lobby_settings.lua) and the build context from PVP.lobby_opts.context().
-- The screen (screen.lua) lays them out; actions.lua holds their G.FUNCS.

local O = PVP.lobby_opts or {}
PVP.lobby_opts = O
-- cat: the shown category. focus: the setting the description pane names.
-- focus_id: the UI id a controller snaps back to after a rebuild.
O.state = O.state or { cat = "match" }

local ROW_W = 8.6
local LABEL_W = 4.3
-- The ‹ value › box; the arrows add about 1 more.
local CONTROL_W = 2.3
local PANE_W = 4.5

-- What every widget in one build needs to know.
function O.context()
	local config = PVP.LOBBY.config
	local forced = PVP.lobby_forced_settings(config.ruleset)
	local changed = PVP.lobby_settings_changed(config, forced)
	local changed_set = {}
	for _, setting in ipairs(changed) do
		changed_set[setting.key] = true
	end
	return {
		config = config,
		editable = O.can_edit(),
		forced = forced,
		changed = changed,
		changed_set = changed_set,
		ruleset_changed = (config.ruleset or PVP.LOBBY_STANDARD_RULESET) ~= PVP.LOBBY_STANDARD_RULESET,
	}
end

function O.can_edit()
	local lobby = MPAPI.get_current_lobby()
	return (lobby and lobby.is_host and PVP._pvp_kind == PVP.LobbyAccess.PRIVATE and not lobby:is_game_started()) and true or false
end

function O.label(setting)
	return localize("k_pvp_set_" .. setting.key)
end

local VALUE_KEYS = {
	deck_mode = { select = "k_pvp_option_select", draft = "k_pvp_option_draft", different = "k_pvp_option_different" },
	seed_mode = { random = "k_random", set = "k_pvp_option_set", different = "k_pvp_option_different" },
}

function O.value_label(setting, value)
	local keys = VALUE_KEYS[setting.key]
	if keys and keys[value] then
		return localize(keys[value])
	end
	if type(value) == "boolean" then
		return localize(PVP.lobby_setting_shown_value(setting, value) and "k_pvp_opt_on" or "k_pvp_opt_off")
	end
	if value == nil then
		return ""
	end
	return tostring(value) .. (type(value) == "number" and setting.suffix or "")
end

local function value_colour(setting, value)
	if type(value) == "boolean" then
		return PVP.lobby_setting_shown_value(setting, value) and G.C.GREEN or G.C.UI.BACKGROUND_INACTIVE
	end
	return G.C.RED
end

-- A value only some lobbies can pick (the Draft runs on the server).
function O.value_available(setting, value)
	local need = setting.needs and setting.needs[value]
	if need == "server_referee" then
		local lobby = MPAPI.get_current_lobby()
		return (lobby and MPAPI.has_server_referee(lobby)) and true or false
	end
	return true
end

-- The row's current value; a setting the config has never written reads its first value.
function O.current_value(setting, config)
	local value = PVP.lobby_setting_get(setting, config)
	if value == nil and setting.values then
		return setting.values[1]
	end
	return value
end

function O.control_id(setting)
	return "mp_pvp_set_" .. setting.key
end

local function text(str, scale, colour, extra)
	local config = { text = str, scale = scale, colour = colour or G.C.UI.TEXT_LIGHT, shadow = true }
	for k, v in pairs(extra or {}) do
		config[k] = v
	end
	return { n = G.UIT.T, config = config }
end
O.text = text

-- The ‹ value › control. A row the player cannot change shows its one value with no arrows.
local function value_cycle(setting, ctx, editable)
	local value = O.current_value(setting, ctx.config)
	local options, values, current = {}, {}, 1
	for _, v in ipairs(setting.values) do
		if v == value or (editable and O.value_available(setting, v)) then
			values[#values + 1] = v
			options[#options + 1] = O.value_label(setting, v)
			if v == value then
				current = #values
			end
		end
	end
	if not editable then
		values, options, current = { value }, { O.value_label(setting, value) }, 1
	end
	return create_option_cycle({
		id = O.control_id(setting),
		options = options,
		current_option = current,
		opt_callback = "mp_pvp_opt_cycle",
		colour = value_colour(setting, value),
		w = CONTROL_W / 0.7,
		scale = 0.7,
		no_pips = #options > 12,
		setting_key = setting.key,
		setting_values = values,
	})
end

-- A free-text value (the seed): a button that opens its entry overlay.
local function text_control(setting, ctx, editable)
	local value = tostring(ctx.config[setting.key] or "")
	return {
		n = G.UIT.C,
		config = {
			id = O.control_id(setting),
			align = "cm",
			minw = CONTROL_W + 0.95,
			minh = 0.55,
			r = 0.1,
			colour = editable and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE,
			hover = editable,
			shadow = editable,
			button = editable and "mp_pvp_seed_overlay" or nil,
		},
		nodes = { text(value, 0.42) },
	}
end

local function reset_button(setting)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			minw = 0.75,
			minh = 0.42,
			r = 0.1,
			colour = G.C.GOLD,
			hover = true,
			shadow = true,
			button = "mp_pvp_opt_reset",
			ref_table = { key = setting.key },
			focus_args = { type = "none" },
		},
		nodes = { text(localize("k_pvp_opt_reset"), 0.3, G.C.BLACK, { shadow = false }) },
	}
end

function O.setting_row(setting, ctx)
	local forced = ctx.forced[setting.key] ~= nil
	local editable = ctx.editable and not forced
	local changed = ctx.changed_set[setting.key]
	local control = setting.type == "text" and text_control(setting, ctx, editable) or value_cycle(setting, ctx, editable)
	local indent = setting.parent and 0.35 or 0
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			minw = ROW_W,
			minh = 0.78,
			r = 0.1,
			padding = 0.04,
			colour = G.C.CLEAR,
			collideable = true,
			func = "mp_pvp_opt_track_focus",
			ref_table = { key = setting.key, focus_id = O.control_id(setting) },
		},
		nodes = {
			{ n = G.UIT.C, config = { align = "cm", minw = 0.1 }, nodes = {
				{ n = G.UIT.B, config = { w = 0.07, h = 0.5, r = 0.03, colour = changed and G.C.GOLD or G.C.CLEAR } },
			} },
			{ n = G.UIT.C, config = { align = "cl", minw = LABEL_W, padding = 0.05 }, nodes = {
				{ n = G.UIT.B, config = { w = indent, h = 0.1 } },
				text(O.label(setting), setting.parent and 0.4 or 0.45, forced and G.C.UI.TEXT_INACTIVE or G.C.UI.TEXT_LIGHT),
			} },
			{ n = G.UIT.C, config = { align = "cm", minw = CONTROL_W + 1.1 }, nodes = { control } },
			{ n = G.UIT.C, config = { align = "cm", minw = 0.85 }, nodes = {
				(changed and editable) and reset_button(setting) or nil,
			} },
		},
	}
end

-- A mutator: an on/off tile with art, name and state.
function O.setting_tile(setting, ctx)
	local forced = ctx.forced[setting.key] ~= nil
	local editable = ctx.editable and not forced
	local on = PVP.lobby_setting_get(setting, ctx.config) == true
	local id = "mp_pvp_tile_" .. setting.key
	return {
		n = G.UIT.C,
		config = {
			id = id,
			align = "tm",
			minw = 2.5,
			minh = 2.5,
			r = 0.15,
			padding = 0.12,
			colour = on and mix_colours(G.C.GOLD, G.C.BLACK, 0.35) or G.C.L_BLACK,
			outline = on and 1.5 or nil,
			outline_colour = on and G.C.GOLD or nil,
			hover = editable,
			shadow = editable,
			collideable = true,
			button = editable and "mp_pvp_opt_tile" or nil,
			func = "mp_pvp_opt_track_focus",
			ref_table = { key = setting.key, focus_id = id },
		},
		nodes = {
			{ n = G.UIT.R, config = { align = "cm" }, nodes = {
				{ n = G.UIT.C, config = { align = "cm", minw = 1.1, minh = 1.1, r = 0.12, colour = on and G.C.GOLD or G.C.PURPLE, emboss = 0.08 }, nodes = {
					text(setting.art or "?", 0.75, on and G.C.BLACK or G.C.UI.TEXT_LIGHT, { shadow = not on }),
				} },
			} },
			{ n = G.UIT.R, config = { align = "cm", maxw = 2.3 }, nodes = { text(O.label(setting), 0.4) } },
			{ n = G.UIT.R, config = { align = "cm" }, nodes = {
				text(O.value_label(setting, on), 0.32, on and G.C.GOLD or G.C.UI.TEXT_INACTIVE),
			} },
		},
	}
end

function O.category_button(category, ctx)
	local selected = O.state.cat == category.key
	local count = 0
	for _, setting in ipairs(ctx.changed) do
		if setting.cat == category.key then
			count = count + 1
		end
	end
	local id = "mp_pvp_opt_cat_" .. category.key
	return {
		n = G.UIT.R,
		config = {
			id = id,
			align = "cm",
			minw = 2.9,
			minh = 0.62,
			r = 0.1,
			padding = 0.05,
			colour = selected and G.C.RED or G.C.BLACK,
			hover = true,
			shadow = true,
			button = "mp_pvp_opt_category",
			ref_table = { key = category.key, focus_id = id },
		},
		nodes = {
			{ n = G.UIT.C, config = { align = "cl", minw = 2.2 }, nodes = { text(localize("k_pvp_cat_" .. category.key), 0.42) } },
			{ n = G.UIT.C, config = { align = "cm", minw = 0.45 }, nodes = {
				count > 0 and { n = G.UIT.C, config = { align = "cm", minw = 0.36, minh = 0.32, r = 0.1, colour = G.C.GOLD }, nodes = {
					text(tostring(count), 0.3, G.C.BLACK, { shadow = false }),
				} } or nil,
			} },
		},
	}
end

-- "Shown when" names a condition: a setting's value, the ruleset or the gamemode.
local function condition_text(when)
	local key, value = when[1], when[2]
	if key == "ruleset" then
		return localize("k_pvp_lobby_ruleset_caption") .. ": " .. (PVP.ruleset_display_name(value) or tostring(value))
	end
	if key == "gamemode" then
		return localize("k_pvp_lobby_gamemode_caption") .. ": " .. localize("k_pvp_gamemode_" .. value:gsub("^pvp_", ""))
	end
	local setting = PVP.lobby_setting(key)
	return O.label(setting) .. ": " .. O.value_label(setting, value)
end

local function fact(label, value)
	return { n = G.UIT.R, config = { align = "cl", minw = PANE_W, padding = 0.02 }, nodes = {
		text(label .. "  ", 0.32, G.C.UI.TEXT_INACTIVE, { shadow = false }),
		text(value, 0.32),
	} }
end

-- The pane's contents for the focused setting.
function O.build_pane()
	local setting = O.state.focus and PVP.lobby_setting(O.state.focus)
	if not setting then
		return { nodes = {} }
	end
	local ctx = O.context()
	local rows = {
		{ n = G.UIT.R, config = { align = "cl", minw = PANE_W, padding = 0.05 }, nodes = { text(O.label(setting), 0.55) } },
	}
	local desc = localize("k_pvp_set_" .. setting.key .. "_desc")
	for line in (desc .. "\n"):gmatch("(.-)\n") do
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cl", minw = PANE_W }, nodes = { text(line, 0.34) } }
	end
	rows[#rows + 1] = { n = G.UIT.R, config = { minh = 0.25 } }
	if setting.std ~= nil then
		rows[#rows + 1] = fact(localize("k_pvp_opt_standard"), O.value_label(setting, setting.std))
	end
	local when = setting.when or (setting.parent and { setting.parent, true })
	if when then
		rows[#rows + 1] = fact(localize("k_pvp_opt_shown_when"), condition_text(when))
	end
	for value, need in pairs(setting.needs or {}) do
		rows[#rows + 1] = fact(O.value_label(setting, value), localize("k_pvp_opt_need_" .. need))
	end
	if ctx.forced[setting.key] ~= nil then
		rows[#rows + 1] = fact(localize("k_pvp_opt_forced_by"), PVP.ruleset_display_name(ctx.config.ruleset) or "")
	end
	return { nodes = rows }
end
