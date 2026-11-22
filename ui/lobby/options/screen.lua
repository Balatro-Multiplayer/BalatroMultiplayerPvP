-- The Lobby Options screen: the gamemode and ruleset in the header with the count of
-- settings changed from standard, the categories down the left, the focused category's
-- rows (or mutator tiles) in the middle, and the focused setting's description on the
-- right. Every player can open it in a private lobby; only the host can change it.
-- Built from the lobby settings schema (lib/lobby_settings.lua) and rebuilt in place on
-- every change, the host's own or a mirrored one (pvp_api/lobby_bridge.lua).

local O = PVP.lobby_opts
local text = O.text

local TILES_PER_ROW = 3

function O.visible_settings(cat, config)
	local list = {}
	for _, setting in ipairs(PVP.LOBBY_SETTINGS) do
		if setting.cat == cat and PVP.lobby_setting_visible(setting, config) then
			list[#list + 1] = setting
		end
	end
	return list
end

local function category(key)
	for _, cat in ipairs(PVP.LOBBY_SETTING_CATEGORIES) do
		if cat.key == key then
			return cat
		end
	end
end

-- Keeps the shown category and the focused setting pointing at something on screen.
function O.ensure_focus()
	if not category(O.state.cat) then
		O.state.cat = PVP.LOBBY_SETTING_CATEGORIES[1].key
	end
	local rows = O.visible_settings(O.state.cat, PVP.LOBBY.config)
	for _, setting in ipairs(rows) do
		if setting.key == O.state.focus then
			return
		end
	end
	O.state.focus = rows[1] and rows[1].key or nil
end

local function ruleset_arrow(dir)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			minw = 0.45,
			minh = 0.85,
			r = 0.1,
			colour = G.C.RED,
			hover = true,
			shadow = true,
			button = "mp_pvp_opt_ruleset",
			ref_table = { dir = dir },
		},
		nodes = { text(dir < 0 and "<" or ">", 0.5) },
	}
end

local function mode_plates(ctx)
	local lobby = MPAPI.get_current_lobby()
	local queue_mode = lobby and ((lobby:get_metadata() or {}).queue_mode or (lobby.is_host and PVP._pvp_gamemode)) or nil
	local nodes = {}
	for _, part in ipairs(PVP.lobby_mode_parts(queue_mode, ctx.config.ruleset)) do
		local plate = PVP.lobby.build_mode_plate(part)
		if part.ruleset_key and ctx.editable then
			nodes[#nodes + 1] = ruleset_arrow(-1)
			nodes[#nodes + 1] = plate
			nodes[#nodes + 1] = ruleset_arrow(1)
		else
			nodes[#nodes + 1] = plate
		end
	end
	return nodes
end

local function verdict(ctx)
	local count = #ctx.changed + (ctx.ruleset_changed and 1 or 0)
	local plate
	if count == 0 then
		plate = { n = G.UIT.C, config = { align = "cm", minh = 0.75, padding = 0.12, r = 0.1, colour = G.C.GREEN, emboss = 0.05 }, nodes = {
			text(localize("k_pvp_opt_standard"), 0.5),
		} }
	else
		plate = { n = G.UIT.C, config = { align = "cm", minh = 0.75, padding = 0.12, r = 0.1, colour = G.C.BLACK, outline = 1, outline_colour = G.C.GOLD }, nodes = {
			text(tostring(count) .. " " .. localize("k_pvp_opt_changed"), 0.5, G.C.GOLD),
		} }
	end
	local nodes = { plate }
	if ctx.editable and count > 0 then
		nodes[#nodes + 1] = {
			n = G.UIT.C,
			config = { align = "cm", minh = 0.75, padding = 0.12, r = 0.1, colour = G.C.BLUE, hover = true, shadow = true, button = "mp_pvp_opt_restore" },
			nodes = { text(localize("k_pvp_opt_restore"), 0.45) },
		}
	end
	return nodes
end

local function header(ctx)
	return { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
		{ n = G.UIT.C, config = { align = "cl", minw = 10 }, nodes = {
			{ n = G.UIT.R, config = { align = "cl", padding = 0.08 }, nodes = mode_plates(ctx) },
		} },
		{ n = G.UIT.C, config = { align = "cr", minw = 6.4 }, nodes = {
			{ n = G.UIT.R, config = { align = "cr", padding = 0.1 }, nodes = verdict(ctx) },
		} },
	} }
end

local function rail(ctx)
	local rows = {}
	for _, cat in ipairs(PVP.LOBBY_SETTING_CATEGORIES) do
		rows[#rows + 1] = O.category_button(cat, ctx)
	end
	return { n = G.UIT.C, config = { align = "tm", padding = 0.08 }, nodes = rows }
end

local function list(ctx)
	local cat = category(O.state.cat)
	local settings = O.visible_settings(cat.key, ctx.config)
	local rows = {}
	if #settings == 0 then
		rows[1] = { n = G.UIT.R, config = { align = "cm", padding = 0.3 }, nodes = {
			text(localize("k_pvp_opt_empty"), 0.4, G.C.UI.TEXT_INACTIVE, { shadow = false }),
		} }
	elseif cat.layout == "tiles" then
		local row
		for i, setting in ipairs(settings) do
			if (i - 1) % TILES_PER_ROW == 0 then
				row = { n = G.UIT.R, config = { align = "cm", padding = 0.12 }, nodes = {} }
				rows[#rows + 1] = row
			end
			row.nodes[#row.nodes + 1] = O.setting_tile(setting, ctx)
		end
	else
		for _, setting in ipairs(settings) do
			rows[#rows + 1] = O.setting_row(setting, ctx)
		end
	end
	return { n = G.UIT.C, config = { align = "tm", minw = 9.2, minh = 6.4, r = 0.1, padding = 0.1, colour = G.C.BLACK }, nodes = rows }
end

local function pane()
	return { n = G.UIT.C, config = { align = "tl", minw = 4.8, maxw = 4.8, minh = 6.4, r = 0.1, padding = 0.15, colour = G.C.BLACK }, nodes = {
		{ n = G.UIT.R, config = { align = "tl" }, nodes = { O.pane.node } },
	} }
end

local function build_screen()
	local ctx = O.context()
	return create_UIBox_generic_options({
		contents = {
			{ n = G.UIT.C, config = { align = "cm" }, nodes = {
				header(ctx),
				{ n = G.UIT.R, config = { align = "tm", padding = 0.1 }, nodes = { rail(ctx), list(ctx), pane() } },
				{ n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
					text(localize("k_pvp_opt_footer"), 0.3, G.C.UI.TEXT_INACTIVE, { shadow = false }),
				} },
			} },
		},
	})
end

function O.open()
	O.ensure_focus()
	O.pane = MPAPI.ui_element(O.build_pane)
	O.screen = MPAPI.ui_element(build_screen)
	O.screen:as_overlay()
end

function O.is_open()
	return (G.OVERLAY_MENU and G.OVERLAY_MENU ~= true and O.screen and G.OVERLAY_MENU:get_UIE_by_ID(O.screen:get_id())) and true or false
end

-- A controller keeps its place across a rebuild.
local function snap_focus()
	local id = O.state.focus_id
	if id and G.CONTROLLER.HID.controller and G.OVERLAY_MENU then
		local node = G.OVERLAY_MENU:get_UIE_by_ID(id)
		if node then
			G.CONTROLLER:snap_to({ node = node })
		end
	end
end

-- Next frame, never inside the click or cycle that asked: those nodes are about to go.
local function later(fn)
	G.E_MANAGER:add_event(Event({
		blocking = false,
		blockable = false,
		func = function()
			fn()
			return true
		end,
	}))
end

function O.refresh()
	if not O.is_open() then
		return
	end
	later(function()
		if O.is_open() then
			O.ensure_focus()
			O.screen:update()
			snap_focus()
		end
	end)
end

function O.refresh_pane()
	later(function()
		if O.is_open() then
			O.pane:update()
		end
	end)
end
