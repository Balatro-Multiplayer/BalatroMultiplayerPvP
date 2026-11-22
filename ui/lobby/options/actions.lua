-- Lobby Options handlers. Every change goes through the lobby settings schema
-- (lib/lobby_settings.lua), is published in the lobby metadata, and rebuilds the screen.

local O = PVP.lobby_opts

local function publish()
	local lobby = MPAPI.get_current_lobby()
	if lobby and lobby.is_host then
		lobby:set_metadata(PVP.pvp_lobby_metadata(PVP._pvp_gamemode, PVP._pvp_kind))
	end
end

local function changed(setting)
	PVP.resolve_current_lobby_settings()
	if setting then
		O.state.focus = setting.key
	end
	publish()
	O.refresh()
end

-- The setting a widget names, when the host may change it.
local function editable_setting(key)
	local setting = key and PVP.lobby_setting(key)
	if not (setting and O.can_edit()) then
		return nil
	end
	local config = PVP.LOBBY.config
	if not PVP.lobby_setting_visible(setting, config) or PVP.lobby_setting_locked(setting, PVP.lobby_settings_policy(config.ruleset)) then
		return nil
	end
	return setting
end

-- nil releases a pin, even if the old choice happened to match today's default.
local function choose(key, value)
	local setting = editable_setting(key)
	if not setting then return end
	if value ~= nil and not (PVP.lobby_setting_accepts(setting, value) and O.value_available(setting, value)) then return end
	local choices = PVP.LOBBY.setting_choices
	choices[key] = value
	if key == "seed_mode" and value == "set" and choices.custom_seed == nil
		and not PVP.lobby_settings_policy(PVP.LOBBY.config.ruleset).custom_seed then
		-- Roll once on the host, never during resolution on each client.
		choices.custom_seed = generate_starting_seed()
	end
	O.state.focus_id = O.control_id(setting)
	changed(setting)
end

-- From create_option_cycle: args.cycle_config is the cycle's own args (widgets.lua).
G.FUNCS.mp_pvp_opt_cycle = function(args)
	local cycle = args.cycle_config
	local value = cycle.setting_values[args.to_key]
	if value ~= nil then choose(cycle.setting_key, value) end
end

G.FUNCS.mp_pvp_opt_tile = function(e)
	local setting = editable_setting(e.config.ref_table.key)
	if not setting then
		return
	end
	choose(setting.key, not PVP.lobby_setting_get(setting, PVP.LOBBY.config))
end

G.FUNCS.mp_pvp_opt_reset = function(e)
	choose(e.config.ref_table.key, nil)
end

G.FUNCS.mp_pvp_opt_restore = function()
	if not O.can_edit() then
		return
	end
	PVP.LOBBY.setting_choices = {}
	PVP.LOBBY.config.ruleset = PVP.LOBBY_STANDARD_RULESET
	changed()
end

G.FUNCS.mp_pvp_opt_category = function(e)
	O.state.cat = e.config.ref_table.key
	O.state.focus = nil
	O.state.focus_id = e.config.ref_table.focus_id
	O.refresh()
end

-- The rulesets a private lobby's host can pick, in header order.
local function ruleset_keys()
	local R = PVP.RulesetKey
	return { R.VANILLA, R.BALANCED, R.EXPANDED, R.SMALLWORLD }
end

G.FUNCS.mp_pvp_opt_ruleset = function(e)
	if not O.can_edit() then
		return
	end
	local keys = ruleset_keys()
	local current = 1
	for i, key in ipairs(keys) do
		if key == PVP.LOBBY.config.ruleset then
			current = i
		end
	end
	local next_index = (current - 1 + e.config.ref_table.dir) % #keys + 1
	PVP.LOBBY.config.ruleset = keys[next_index]
	O.state.focus_id = nil
	changed()
end

-- Hover or controller focus on a row or tile points the description pane at it.
G.FUNCS.mp_pvp_opt_track_focus = function(e)
	local ref = e.config.ref_table
	local active = false
	for _, node in ipairs(G.CONTROLLER.collision_list or {}) do
		if node == e then
			active = true
			break
		end
	end
	if not active then
		local target = G.CONTROLLER.focused and G.CONTROLLER.focused.target
		while target do
			if target == e then
				active = true
				break
			end
			target = target.parent
		end
	end
	if e.UIT == G.UIT.R then
		e.config.colour = O.state.focus == ref.key and G.C.L_BLACK or G.C.CLEAR
	end
	if active and O.state.focus ~= ref.key then
		O.state.focus = ref.key
		O.refresh_pane()
	end
	if active and G.CONTROLLER.HID.controller then
		O.state.focus_id = ref.focus_id
	end
end

G.FUNCS.mp_pvp_seed_overlay = function()
	if not editable_setting("custom_seed") then
		return
	end
	local lobby = MPAPI.get_current_lobby()
	local current = PVP.LOBBY.config.custom_seed
	PVP.LOBBY.temp_seed = (current and current ~= "random") and current or ""
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({
			back_func = "mp_pvp_lobby_options",
			contents = { { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = {
				create_text_input({
					max_length = 8,
					all_caps = true,
					ref_table = PVP.LOBBY,
					ref_value = "temp_seed",
					prompt_text = localize("k_enter_seed"),
					keyboard_offset = 4,
					callback = function()
						local seed = PVP.LOBBY.temp_seed
						if MPAPI.get_current_lobby() == lobby and seed and seed ~= "" then choose("custom_seed", seed) end
					end,
				}),
				{ n = G.UIT.T, config = { text = localize("k_enter_to_save"), scale = 0.3, colour = G.C.UI.TEXT_LIGHT } },
			} } },
		}),
	})
end
