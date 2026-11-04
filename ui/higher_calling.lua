-- Higher Calling is an opportunity on Judgement, not a card edition.
local function is_active(card)
	return card.config.center.key == "c_judgement" and not card.debuff and PVP.CHAOS.has_rule("higher_calling")
end

SMODS.Shader({
	key = "higher_calling",
	path = "higher_calling.fs",
	send_vars = function(sprite, card)
		card = sprite.role.draw_major or card or sprite
		local cursor = G.CONTROLLER.cursor_position
		return {
			texture_details = sprite:get_pos_pixel(),
			image_details = sprite:get_image_dims(),
			phase = G.SETTINGS.reduced_motion and 0 or G.TIMERS.REAL * 0.35,
			-- Editions use this same rotation, juice and hover signal.
			motion = G.SETTINGS.reduced_motion and 0
				or (card.ARGS and card.ARGS.send_to_shader and card.ARGS.send_to_shader[1] or 0),
			fade = 1 - math.min(1, math.abs(card.dissolve or 0)),
			mouse_screen_pos = {
				(card.tilt_var and card.tilt_var.mx or cursor.x) * G.CANV_SCALE,
				(card.tilt_var and card.tilt_var.my or cursor.y) * G.CANV_SCALE,
			},
			hovering = G.SETTINGS.reduced_motion and 0 or (card.hover_tilt or 0),
			screen_scale = G.TILESCALE * G.TILESIZE * (card.mouse_damping or 1) * G.CANV_SCALE,
		}
	end,
})

SMODS.DrawStep({
	key = "higher_calling",
	order = 25, -- pearl finish over the real edition, below seals/stickers
	conditions = { vortex = false, facing = "front" },
	func = function(card)
		if not is_active(card) then return end
		-- Custom sends avoid changing edition fields, prices, slots or saved data.
		card.children.center:draw_shader("mp_higher_calling", nil, nil, nil, nil, nil, nil, nil, nil, true)
	end,
})

-- UI callbacks animate only visible tooltip elements, not every card in the run.
G.FUNCS.mp_higher_calling_pearl = function(element)
	local t = G.SETTINGS.reduced_motion and 0 or (0.5 + 0.5 * math.sin(G.TIMERS.REAL * 0.18))
	local colour = element.config.colour
	colour[1], colour[2], colour[3] = 0.96 - 0.20 * t, 0.90 + 0.02 * t, 0.76 + 0.24 * t
end

local ability_table = Card.generate_UIBox_ability_table
function Card:generate_UIBox_ability_table(...)
	local result = ability_table(self, ...)
	if not is_active(self) or result.card_type == "Locked" or result.card_type == "Undiscovered" then return result end
	local function pearl()
		return { 0.96, 0.90, 0.76, 1 }
	end
	result.main[#result.main + 1] = {
		{
			n = G.UIT.C,
			config = { align = "cm", padding = 0.04 },
			nodes = {
				{
					n = G.UIT.R,
					config = {
						align = "cm",
						r = 0.08,
						padding = 0.045,
						colour = pearl(),
						func = "mp_higher_calling_pearl",
					},
					nodes = {
						{
							n = G.UIT.T,
							config = { text = localize("k_mp_higher_calling"), scale = 0.27, colour = G.C.UI.TEXT_DARK },
						},
					},
				},
				{
					n = G.UIT.R,
					config = { align = "cm", padding = 0.025 },
					nodes = {
						{
							n = G.UIT.B,
							config = { w = 1.8, h = 0.018, colour = pearl(), func = "mp_higher_calling_pearl" },
						},
					},
				},
				{
					n = G.UIT.R,
					config = { align = "cm" },
					nodes = {
						{
							n = G.UIT.T,
							config = { text = localize("k_mp_this_ante"), scale = 0.22, colour = G.C.UI.TEXT_INACTIVE },
						},
					},
				},
			},
		},
	}
	return result
end
