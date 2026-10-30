-- Thin PvP-specific wrapper over MPAPI.enemy_location (see
-- BalatroMultiplayerAPI/ui/enemy_location.lua for the shared swap/hover
-- mechanics and the id contract that keeps this crash-safe). PvP shows a
-- single opposing nemesis: a blind icon + name in the main slot, and the
-- same location box beside the opponent's name in the hover popup.

function PVP.UI.enemy_location_blind_render()
	local blind_key, blind_object = PVP.GAME.enemy.location_blind, nil
	if blind_key then blind_object = G.P_BLINDS[blind_key] end

	local blind_object_render
	if blind_object then
		blind_object_render = SMODS.create_sprite(
			0,
			0,
			0.4,
			0.4,
			blind_object.atlas or "blind_chips",
			blind_object.pos or G.P_BLINDS.bl_small.pos
		)
		blind_object_render:define_draw_steps({
			{ shader = "dissolve", shadow_height = 0.05 * 0.4 * 0.75 },
			{ shader = "dissolve" },
		})
	elseif blind_key and blind_key ~= "" then
		blind_object_render = DynaText({
			string = { blind_key or "Unknown" },
			colours = { G.C.WHITE },
			scale = 0.35,
			shadow = true,
		})
	else
		blind_object_render = Moveable()
	end

	return blind_object_render
end

-- The location and the " (catching up)" badge read as one text, so a long pair scales down
-- together to fit the column instead of the badge overflowing it.
local shown_location = setmetatable({}, {
	__index = function(_, key)
		if key == "text" then
			return PVP.GAME.enemy.location .. PVP.GAME.enemy.catching_up_text
		end
	end,
})

-- The [text location][blind icon] pair shown both in the main HUD slot and
-- in the hover popup -- the text node carries chip_ui_id per
-- MPAPI.enemy_location's contract; the icon is a separate sibling node kept
-- live-updatable by id (mp_enemy_location_render) since it isn't a plain
-- ref_table/ref_value binding like the text is.
local function value_nodes(chip_ui_id)
	return {
		{
			n = G.UIT.C,
			config = { maxw = 2.2, align = "cm" },
			nodes = {
				{
					n = G.UIT.T,
					config = {
						ref_table = shown_location,
						ref_value = "text",
						scale = 0.35,
						colour = G.C.WHITE,
						id = chip_ui_id,
						shadow = true,
						maxw = 2.5,
					},
				},
			},
		},
		{ n = G.UIT.B, config = { w = 0.1, h = 0.1 } },
		{
			n = G.UIT.O,
			config = {
				object = PVP.UI.enemy_location_blind_render(),
				id = "mp_enemy_location_render",
			},
		},
	}
end

-- The opponent this location belongs to; before a target latches, the same
-- gamemode name the blind shows (see ui/game/blind_hud.lua).
local function opponent_name()
	if PVP.is_announced_bye() then
		return PVP.pvp_blind_opponent_name()
	end
	local opponent = PVP.LOBBY.is_host and PVP.LOBBY.guest or PVP.LOBBY.host
	return (opponent and opponent.username) or PVP.pvp_blind_opponent_name()
end

-- The hover popup names the opponent where the HUD slot says "Enemy location".
-- Built on each hover, so the name is read fresh.
local function popup_rows()
	return { MPAPI.enemy_location_row(
		nil,
		{ { n = G.UIT.R, config = { align = "cm", padding = 0, maxw = 1.2 }, nodes = {
			{ n = G.UIT.T, config = { text = tostring(opponent_name() or ""), scale = 0.42, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} } },
		-- Fresh value_nodes() here: the popup is a separate live UIBox with its own nodes.
		value_nodes("mp_enemy_location_popup_value"),
		2.8
	) }
end

PVP._enemy_location = MPAPI.enemy_location({
	-- A function: this file loads before the localization does.
	label = function()
		return localize("ml_enemy_loc")
	end,
	build_value_nodes = value_nodes,
	build_popup_rows = popup_rows,
	swatch_minw = 2.8,
	popup_disabled = function()
		return PVP.current_ruleset().enemy_location_disabled and true or false
	end,
	-- Vietnamese reads more naturally with round/score swapped; vanilla
	-- itself doesn't do this, it's a PvP-specific community fix.
	round_score_labels = function()
		if G.SETTINGS.language == "vi" then
			return { localize("k_lower_score"), localize("k_round") }
		end
		return { localize("k_round"), localize("k_lower_score") }
	end,
})

function PVP.UI.show_enemy_location()
	if PVP.current_ruleset().enemy_location_disabled then return end
	PVP._enemy_location.show()
end

function PVP.UI.hide_enemy_location()
	PVP._enemy_location.hide()
end

-- Refreshes the blind-icon renderer(s) in place when a new location update
-- arrives over the network (networking/action_handlers.lua's `receive`
-- handler) -- unlike the text, the icon isn't a ref_table/ref_value binding,
-- so it needs an explicit rebuild-and-swap.
function PVP.UI.update_enemy_location_render()
	if not G.HUD then return end
	local renderer = G.HUD:get_UIE_by_ID("mp_enemy_location_render")
	if renderer then
		local blind_object_render = PVP.UI.enemy_location_blind_render()
		renderer.config.object:remove()
		renderer.config.object = blind_object_render
		blind_object_render.parent = renderer

		renderer.UIBox:recalculate()
	end

	local hover_renderer = PVP._enemy_location.popup and PVP._enemy_location.popup:get_UIE_by_ID("mp_enemy_location_render")

	if hover_renderer then
		local blind_object_render = PVP.UI.enemy_location_blind_render()
		hover_renderer.config.object:remove()
		hover_renderer.config.object = blind_object_render
		blind_object_render.parent = hover_renderer

		hover_renderer.UIBox:recalculate()
	end
end
