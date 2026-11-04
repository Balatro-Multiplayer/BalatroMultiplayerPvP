local checks, draws, active = 0, 0, true
local function check(ok, message)
	assert(ok, message)
	checks = checks + 1
end
local shader, step
SMODS = {
	Shader = function(def)
		shader = def
	end,
	DrawStep = function(def)
		step = def
	end,
}
PVP = { CHAOS = {
	has_rule = function(key)
		return active and key == "higher_calling"
	end,
} }
G = {
	SETTINGS = {},
	TIMERS = { REAL = 12 },
	CONTROLLER = { cursor_position = { x = 0, y = 0 } },
	CANV_SCALE = 1,
	TILESCALE = 1,
	TILESIZE = 1,
	FUNCS = {},
	UIT = { C = "column", R = "row", T = "text", B = "box" },
	C = { UI = { TEXT_DARK = {}, TEXT_INACTIVE = {} } },
}
local base_row = { "Normal Judgement description" }
Card = {
	generate_UIBox_ability_table = function(self)
		return { main = { base_row }, card_type = self.test_type or "Tarot" }
	end,
}
localize = function(key)
	return key
end
dofile("ui/higher_calling.lua")
local sprite = {
	role = {},
	get_pos_pixel = function()
		return { 0, 0, 71, 95 }
	end,
	get_image_dims = function()
		return { 710, 950 }
	end,
	draw_shader = function(_, key, _, _, _, _, _, _, _, _, custom)
		check(key == "mp_higher_calling" and custom, "Uses only the custom cosmetic shader")
		draws = draws + 1
	end,
}
local card = { config = { center = { key = "c_judgement" } }, children = { center = sprite } }
sprite.role.draw_major = card
check(step.order > 20 and step.order < 30, "Effect composes between editions and seals")
check(step.conditions.facing == "front" and step.conditions.vortex == false, "No back or vortex overlay")
step.func(card)
check(draws == 1 and not card.edition, "Draws without inventing an edition")
card.edition = { negative = true }
step.func(card)
check(card.edition.negative, "Real edition is preserved")
card.debuff = true
step.func(card)
check(draws == 2, "No promise of improved outcomes on a debuffed card")
card.debuff, active = false, false
step.func(card)
check(draws == 2, "Expiry immediately removes the visual")
active = true
card.config.center.key = "c_fool"
step.func(card)
check(draws == 2, "Other consumables remain unchanged")
local uniforms = shader.send_vars(sprite)
check(math.abs(uniforms.phase - 4.2) < 1e-12 and uniforms.fade == 1, "Visual time does not consume gameplay RNG")
card.ARGS = { send_to_shader = { 0.7, 12 } }
check(shader.send_vars(sprite).motion == 0.7, "Light follows the host edition motion signal")
G.SETTINGS.reduced_motion = true
card.hover_tilt = 1
uniforms = shader.send_vars(sprite)
check(
	uniforms.phase == 0 and uniforms.motion == 0 and uniforms.hovering == 0,
	"Reduced motion freezes the geometry and hover tilt"
)
card.dissolve = 0.5
check(shader.send_vars(sprite).fade == 0.5, "Visual fades with the card")
card.config.center.key = "c_judgement"
local tooltip = Card.generate_UIBox_ability_table(card)
check(#tooltip.main == 2 and tooltip.main[1] == base_row, "Footer preserves the native description")
local footer = tooltip.main[2][1].nodes
check(footer[1].nodes[1].config.text == "k_mp_higher_calling", "Footer names the effect")
check(footer[3].nodes[1].config.text == "k_mp_this_ante", "Footer states its duration")
local element = { config = { colour = { 0, 0, 0, 1 } } }
G.FUNCS.mp_higher_calling_pearl(element)
local red = element.config.colour[1]
G.TIMERS.REAL = 100
G.FUNCS.mp_higher_calling_pearl(element)
check(element.config.colour[1] == red, "Reduced motion freezes tooltip sheen")
G.SETTINGS.reduced_motion = false
G.FUNCS.mp_higher_calling_pearl(element)
check(element.config.colour[1] ~= red, "Tooltip sheen follows visual time")
for _, kind in ipairs({ "Locked", "Undiscovered" }) do
	card.test_type = kind
	check(#Card.generate_UIBox_ability_table(card).main == 1, "No footer on " .. kind .. " card")
end
card.test_type, card.debuff = nil, true
check(#Card.generate_UIBox_ability_table(card).main == 1, "No footer on debuffed Judgement")
card.debuff, active = false, false
check(#Card.generate_UIBox_ability_table(card).main == 1, "No footer after expiry")
active = true
card.config.center.key = "c_fool"
check(#Card.generate_UIBox_ability_table(card).main == 1, "No footer on other consumables")
print("Higher Calling visuals: " .. checks .. " checks passed")
