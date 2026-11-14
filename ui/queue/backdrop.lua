-- Owns the menu splash shader and clock while searching or revealing a match.
-- Changing shader time directly jumps the swirl; integrate a separate clock instead.
-- Never change a replacement G.SPLASH_BACK created by a run starting.

local Backdrop = {
	sprite = nil, -- the G.SPLASH_BACK we've taken over
	mode = nil, -- "splash" or "reveal"
	clock = 0, -- the splash's time while it's ours
	rate = 1, -- how fast that time runs, eased toward target_rate
	target_rate = 1,
	palette = nil, -- the reveal's colours, as the background shader takes them
	spin = { real = 0, eased = 0, amount = 0 }, -- as G.ARGS.spin
	spin_time = 0, -- as G.TIMERS.BACKGROUND
}
PVP.QUEUE_BACKDROP = Backdrop

-- Which preset the reveal plays over, or false to keep the menu's swirl.
Backdrop.REVEAL = "planet_pack"

-- Palettes for the background shader, written as ease_background_colour args
-- (functions/common_events.lua), so any of the game's can be pasted in. `spin` is where the
-- swirl settles after the match's spin spike, in G.ARGS.spin.real terms (a boss is 0.25-1).
Backdrop.PRESETS = {
	planet_pack = { new_colour = G.C.BLACK, contrast = 3, spin = 0.3 },
	spectral_pack = {
		new_colour = G.C.SECONDARY_SET.Spectral,
		special_colour = darken(G.C.BLACK, 0.2),
		contrast = 2,
		spin = 0.5,
	},
	tarot_pack = { new_colour = G.C.PURPLE, special_colour = darken(G.C.BLACK, 0.2), contrast = 1.5, spin = 0.3 },
	showdown = {
		new_colour = G.C.BLUE,
		special_colour = G.C.RED,
		tertiary_colour = darken(G.C.BLACK, 0.4),
		contrast = 3,
		spin = 0.8,
	},
}

local function reduced_motion()
	return G.SETTINGS and G.SETTINGS.reduced_motion
end

-- ease_background_colour's mapping from its args to the shader's three colours and contrast.
function Backdrop.palette_of(preset)
	local new, special, tertiary = preset.new_colour, preset.special_colour, preset.tertiary_colour
	local function scaled(c, k)
		return { c[1] * k, c[2] * k, c[3] * k, 1 }
	end
	local p = { contrast = preset.contrast or 1 }
	if special and tertiary then
		p.L, p.C, p.D = scaled(new, 1), scaled(special, 1), scaled(tertiary, 1)
	else
		p.L = scaled(new, 1.3)
		p.D = scaled(new, special and 0.4 or 0.7)
		p.C = special and scaled(special, 1) or scaled(new, 0.9)
	end
	return p
end

-- The sprite we may draw on: the one we already hold, or a fresh menu splash.
local function claim()
	local sprite = G.SPLASH_BACK
	if not sprite then return nil end
	if sprite ~= Backdrop.sprite then
		local step = sprite.draw_steps and sprite.draw_steps[1]
		if not (step and step.shader == "splash") then return nil end
		Backdrop.sprite, Backdrop.mode = sprite, nil
	end
	return sprite
end

-- Vanilla's main-menu splash, but with our clock for its time.
local function draw_splash(sprite)
	Backdrop.mode = "splash"
	sprite:define_draw_steps({
		{
			shader = "splash",
			send = {
				{
					name = "time",
					func = function()
						return reduced_motion() and G.TIMERS.REAL_SHADER or Backdrop.clock
					end,
				},
				{ name = "vort_speed", val = 0.4 },
				{ name = "colour_1", ref_table = G.C, ref_value = "RED" },
				{ name = "colour_2", ref_table = G.C, ref_value = "BLUE" },
				{ name = "mid_flash", val = 0 },
				{ name = "vort_offset", val = 0 },
			},
		},
	})
end

local function draw_reveal(sprite)
	Backdrop.mode = "reveal"
	sprite:define_draw_steps({
		{
			shader = "background",
			send = {
				{ name = "time", ref_table = G.TIMERS, ref_value = "REAL_SHADER" },
				{
					name = "spin_time",
					func = function()
						return Backdrop.spin_time
					end,
				},
				{ name = "colour_1", ref_table = Backdrop.palette, ref_value = "C" },
				{ name = "colour_2", ref_table = Backdrop.palette, ref_value = "L" },
				{ name = "colour_3", ref_table = Backdrop.palette, ref_value = "D" },
				{ name = "contrast", ref_table = Backdrop.palette, ref_value = "contrast" },
				{ name = "spin_amount", ref_table = Backdrop.spin, ref_value = "amount" },
			},
		},
	})
end

-- Runs the menu swirl at `rate` times its normal speed (eased there). Reduced motion keeps it.
function Backdrop.set_speed(rate)
	local sprite = claim()
	if not sprite or reduced_motion() then return end
	if Backdrop.mode ~= "splash" then
		Backdrop.clock = G.TIMERS.REAL_SHADER
		Backdrop.rate = 1
		draw_splash(sprite)
	end
	Backdrop.target_rate = rate
end

-- Swaps the swirl for the Backdrop.REVEAL preset, its spin starting from `spin` (0 under reduced
-- motion). Returns whether it did.
function Backdrop.reveal(spin)
	local preset = Backdrop.REVEAL and Backdrop.PRESETS[Backdrop.REVEAL]
	local sprite = preset and claim()
	if not sprite then return false end
	Backdrop.palette = Backdrop.palette_of(preset)
	Backdrop.spin.real, Backdrop.spin.eased, Backdrop.spin.amount =
		reduced_motion() and 0 or (spin or preset.spin or 0), 0, 0
	Backdrop.spin_time = 0
	draw_reveal(sprite)
	return true
end

-- Lets the reveal's spin settle where its preset rests.
function Backdrop.settle()
	local preset = Backdrop.REVEAL and Backdrop.PRESETS[Backdrop.REVEAL]
	if preset and Backdrop.mode == "reveal" then Backdrop.spin.real = reduced_motion() and 0 or (preset.spin or 0) end
end

-- Back to the menu swirl at its normal speed, if the sprite we took is still the one on screen.
-- The splash keeps our clock, eased back to 1x, so it doesn't jump.
function Backdrop.restore()
	if not Backdrop.sprite or G.SPLASH_BACK ~= Backdrop.sprite then
		Backdrop.sprite, Backdrop.mode = nil, nil
		return
	end
	if Backdrop.mode == "reveal" then
		Backdrop.clock = G.TIMERS.REAL_SHADER
		Backdrop.rate = 1
		draw_splash(Backdrop.sprite)
	end
	Backdrop.target_rate = 1
end

-- Per frame. The spin easing is the game's own (Game:start_run's background event).
function Backdrop.update(dt)
	if not Backdrop.mode or G.SPLASH_BACK ~= Backdrop.sprite then return end
	if Backdrop.mode == "splash" then
		Backdrop.rate = Backdrop.rate + (Backdrop.target_rate - Backdrop.rate) * math.min(1, dt * 2)
		Backdrop.clock = Backdrop.clock + dt * Backdrop.rate
		return
	end
	local s = Backdrop.spin
	local _dt = s.amount > s.eased and dt * 2 or 0.3 * dt
	local delta = s.real - s.eased
	if math.abs(delta) > _dt then delta = delta * _dt / math.abs(delta) end
	s.eased = s.eased + delta
	s.amount = _dt * s.eased + (1 - _dt) * s.amount
	Backdrop.spin_time = Backdrop.spin_time + dt * s.amount - 60 * (s.eased - s.amount) * _dt
end
