-- TAB-hold shortcuts menu
-- Shows a context-aware overlay of quick actions while TAB is held

PVP.UI.shortcuts = {
	visible = false,
	ui = nil,
}

-- Build the list of available shortcuts based on current state
local function get_shortcuts()
	local shortcuts = {}
	-- PvP's own menu only: elsewhere (the vanilla menu, another mod's menu or
	-- lobby) TAB stays the game's, and "C" must not open a PvP lobby.
	if MPAPI.get_focused_mod() ~= PVP.id then
		return shortcuts
	end
	local in_lobby = PVP.LOBBY.code ~= nil
	-- PVP.LOBBY.connected is only set inside a lobby (lobby_bridge.lua); out of one,
	-- the server connection itself is what the join/create shortcuts need.
	local connected = MPAPI.is_connected()
	local in_menu = G.STAGE == G.STAGES.MAIN_MENU

	if in_menu then
		if in_lobby then
			table.insert(shortcuts, {
				label = localize("b_copy_code"),
				key = "C",
				action = function()
					PVP.UTILS.copy_to_clipboard(PVP.LOBBY.code)
				end,
			})
			table.insert(shortcuts, {
				label = localize("b_view_code"),
				key = "V",
				action = function()
					PVP.UI.UTILS.overlay_message(PVP.LOBBY.code)
				end,
			})
			table.insert(shortcuts, {
				label = localize("b_leave_lobby"),
				key = "L",
				action = function()
					G.FUNCS.mp_pvp_leave_lobby()
				end,
			})
		elseif connected then
			table.insert(shortcuts, {
				label = localize("b_join_lobby_clipboard"),
				key = "V",
				action = function()
					G.FUNCS.mp_pvp_join_lobby_from_clipboard()
				end,
			})
			table.insert(shortcuts, {
				label = localize("b_join_lobby"),
				key = "J",
				action = function()
					G.FUNCS.mp_pvp_join_lobby_by_code()
				end,
			})
			table.insert(shortcuts, {
				label = localize("b_create_lobby"),
				key = "C",
				action = function()
					G.FUNCS.mp_pvp_create_lobby()
				end,
			})
		end
	end

	return shortcuts
end

-- Create the UI definition for the shortcuts overlay
local function create_shortcuts_ui(shortcuts)
	local rows = {}

	-- Header
	table.insert(rows, {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.08 },
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = localize("k_sc_title"),
					scale = 0.5,
					colour = G.C.UI.TEXT_LIGHT,
					shadow = true,
				},
			},
		},
	})

	-- Shortcut rows
	for _, sc in ipairs(shortcuts) do
		table.insert(rows, {
			n = G.UIT.R,
			config = {
				align = "cm",
				padding = 0.04,
				r = 0.08,
				colour = G.C.L_BLACK,
				hover = true,
				button = "mp_shortcut_exec",
				ref_table = sc,
			},
			nodes = {
				{
					n = G.UIT.C,
					config = { align = "cm", minw = 1 },
					nodes = {
						{
							n = G.UIT.R,
							config = {
								align = "cm",
								padding = 0.04,
								r = 0.05,
								colour = G.C.PURPLE,
								minw = 0.6,
							},
							nodes = {
								{
									n = G.UIT.T,
									config = {
										text = sc.key,
										scale = 0.4,
										colour = G.C.UI.TEXT_LIGHT,
										shadow = true,
									},
								},
							},
						},
					},
				},
				{
					n = G.UIT.C,
					config = { align = "cl", minw = 3.5 },
					nodes = {
						{
							n = G.UIT.T,
							config = {
								text = " " .. sc.label,
								scale = 0.38,
								colour = G.C.UI.TEXT_LIGHT,
							},
						},
					},
				},
			},
		})
	end

	-- Footer hint
	table.insert(rows, {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.06 },
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = localize("k_sc_hint"),
					scale = 0.3,
					colour = G.C.UI.TEXT_INACTIVE,
				},
			},
		},
	})

	return {
		n = G.UIT.ROOT,
		config = {
			align = "cl",
			colour = { 0, 0, 0, 0.4 },
			r = 0.15,
			padding = 0.15,
			minw = 5,
		},
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cl", padding = 0.05 },
				nodes = rows,
			},
		},
	}
end

function G.FUNCS.mp_shortcut_exec(e)
	if e.config.ref_table and e.config.ref_table.action then
		PVP.UI.shortcuts.hide()
		e.config.ref_table.action()
	end
end

function PVP.UI.shortcuts.show()
	if PVP.UI.shortcuts.visible then return end

	local shortcuts = get_shortcuts()
	if #shortcuts == 0 then return end

	PVP.UI.shortcuts.visible = true
	PVP.UI.shortcuts.current_shortcuts = shortcuts

	PVP.UI.shortcuts.ui = UIBox({
		definition = create_shortcuts_ui(shortcuts),
		config = {
			align = "cm",
			offset = { x = -5, y = 0 },
			major = G.ROOM_ATTACH,
			bond = "Weak",
		},
	})
end

function PVP.UI.shortcuts.hide()
	if not PVP.UI.shortcuts.visible then return end

	PVP.UI.shortcuts.visible = false
	if PVP.UI.shortcuts.ui then
		PVP.UI.shortcuts.ui:remove()
		PVP.UI.shortcuts.ui = nil
	end
	PVP.UI.shortcuts.current_shortcuts = nil
end

-- Execute a shortcut by its key letter
function PVP.UI.shortcuts.execute_key(key)
	if not PVP.UI.shortcuts.current_shortcuts then return false end

	local upper_key = string.upper(key)
	for _, sc in ipairs(PVP.UI.shortcuts.current_shortcuts) do
		if sc.key == upper_key then
			PVP.UI.shortcuts.hide()
			sc.action()
			return true
		end
	end
	return false
end

-- Hook into Controller to detect TAB press and shortcut key presses
local key_press_update_ref = Controller.key_press_update
function Controller:key_press_update(key, dt)
	-- Intercept shortcut key presses while menu is visible
	if PVP.UI.shortcuts.visible and #key == 1 then
		if PVP.UI.shortcuts.execute_key(key) then
			return
		end
	end

	if key == "tab" and not G.OVERLAY_MENU then
		PVP.UI.shortcuts.show()
		if PVP.UI.shortcuts.visible then return end
	end
	key_press_update_ref(self, key, dt)
end

local key_release_update_ref = Controller.key_release_update
function Controller:key_release_update(key, dt)
	if key == "tab" then
		PVP.UI.shortcuts.hide()
	end
	key_release_update_ref(self, key, dt)
end
