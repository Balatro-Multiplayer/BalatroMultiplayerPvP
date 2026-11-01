-- The menu background (G.SPLASH_BACK) while queueing and on a match.
--
-- Searching: the menu's own splash swirl, run on a clock of ours so it can go faster. The
-- splash shader has no spin input and its speed is baked into its time, so changing its
-- vort_speed would jump; changing how fast its time runs doesn't.
--
-- On a match: the game's in-run `background` shader (blinds, shop, packs) in the palette
-- named by B.REVEAL, spun up the way a boss blind spins it. B.restore puts the splash back.
--
-- Only the splash on screen when the queue started is ever touched: a run starting builds a
-- new G.SPLASH_BACK, and that one is left alone.

local B = {
	sprite = nil, -- the G.SPLASH_BACK we've taken over
	mode = nil, -- "splash" or "reveal"
	clock = 0, -- the splash's time while it's ours
	rate = 1, -- how fast that time runs, eased toward target_rate
	target_rate = 1,
	palette = nil, -- the reveal's colours, as the background shader takes them
	spin = { real = 0, eased = 0, amount = 0 }, -- as G.ARGS.spin
	spin_time = 0, -- as G.TIMERS.BACKGROUND
}
PVP.QUEUE_BACKDROP = B

-- Which preset the reveal plays over, or false to keep the menu's swirl.
B.REVEAL = "planet_pack"

-- Palettes for the background shader, written as ease_background_colour args
-- (functions/common_events.lua), so any of the game's can be pasted in. `spin` is where the
-- swirl settles after the match's spin spike, in G.ARGS.spin.real terms (a boss is 0.25-1).
B.PRESETS = {
	planet_pack = { new_colour = G.C.BLACK, contrast = 3, spin = 0.3 },
	spectral_pack = { new_colour = G.C.SECONDARY_SET.Spectral, special_colour = darken(G.C.BLACK, 0.2), contrast = 2, spin = 0.5 },
	tarot_pack = { new_colour = G.C.PURPLE, special_colour = darken(G.C.BLACK, 0.2), contrast = 1.5, spin = 0.3 },
	showdown = { new_colour = G.C.BLUE, special_colour = G.C.RED, tertiary_colour = darken(G.C.BLACK, 0.4), contrast = 3, spin = 0.8 },
}

local function reduced_motion()
	return G.SETTINGS and G.SETTINGS.reduced_motion
end

-- ease_background_colour's mapping from its args to the shader's three colours and contrast.
function B.palette_of(preset)
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
	if not sprite then
		return nil
	end
	if sprite ~= B.sprite then
		local step = sprite.draw_steps and sprite.draw_steps[1]
		if not (step and step.shader == "splash") then
			return nil
		end
		B.sprite, B.mode = sprite, nil
	end
	return sprite
end

-- Vanilla's main-menu splash, but with our clock for its time.
local function draw_splash(sprite)
	B.mode = "splash"
	sprite:define_draw_steps({ {
		shader = "splash",
		send = {
			{ name = "time", func = function()
				return reduced_motion() and G.TIMERS.REAL_SHADER or B.clock
			end },
			{ name = "vort_speed", val = 0.4 },
			{ name = "colour_1", ref_table = G.C, ref_value = "RED" },
			{ name = "colour_2", ref_table = G.C, ref_value = "BLUE" },
			{ name = "mid_flash", val = 0 },
			{ name = "vort_offset", val = 0 },
		},
	} })
end

local function draw_reveal(sprite)
	B.mode = "reveal"
	sprite:define_draw_steps({ {
		shader = "background",
		send = {
			{ name = "time", ref_table = G.TIMERS, ref_value = "REAL_SHADER" },
			{ name = "spin_time", func = function() return B.spin_time end },
			{ name = "colour_1", ref_table = B.palette, ref_value = "C" },
			{ name = "colour_2", ref_table = B.palette, ref_value = "L" },
			{ name = "colour_3", ref_table = B.palette, ref_value = "D" },
			{ name = "contrast", ref_table = B.palette, ref_value = "contrast" },
			{ name = "spin_amount", ref_table = B.spin, ref_value = "amount" },
		},
	} })
end

-- Runs the menu swirl at `rate` times its normal speed (eased there). Reduced motion keeps it.
function B.set_speed(rate)
	local sprite = claim()
	if not sprite or reduced_motion() then
		return
	end
	if B.mode ~= "splash" then
		B.clock = G.TIMERS.REAL_SHADER
		B.rate = 1
		draw_splash(sprite)
	end
	B.target_rate = rate
end

-- Swaps the swirl for the B.REVEAL preset, its spin starting from `spin` (0 under reduced
-- motion). Returns whether it did.
function B.reveal(spin)
	local preset = B.REVEAL and B.PRESETS[B.REVEAL]
	local sprite = preset and claim()
	if not sprite then
		return false
	end
	B.palette = B.palette_of(preset)
	B.spin.real, B.spin.eased, B.spin.amount = reduced_motion() and 0 or (spin or preset.spin or 0), 0, 0
	B.spin_time = 0
	draw_reveal(sprite)
	return true
end

-- Lets the reveal's spin settle where its preset rests.
function B.settle()
	local preset = B.REVEAL and B.PRESETS[B.REVEAL]
	if preset and B.mode == "reveal" then
		B.spin.real = reduced_motion() and 0 or (preset.spin or 0)
	end
end

-- Back to the menu swirl at its normal speed, if the sprite we took is still the one on screen.
-- The splash keeps our clock, eased back to 1x, so it doesn't jump.
function B.restore()
	if not B.sprite or G.SPLASH_BACK ~= B.sprite then
		B.sprite, B.mode = nil, nil
		return
	end
	if B.mode == "reveal" then
		B.clock = G.TIMERS.REAL_SHADER
		B.rate = 1
		draw_splash(B.sprite)
	end
	B.target_rate = 1
end

-- Per frame. The spin easing is the game's own (Game:start_run's background event).
function B.update(dt)
	if not B.mode or G.SPLASH_BACK ~= B.sprite then
		return
	end
	if B.mode == "splash" then
		B.rate = B.rate + (B.target_rate - B.rate) * math.min(1, dt * 2)
		B.clock = B.clock + dt * B.rate
		return
	end
	local s = B.spin
	local _dt = s.amount > s.eased and dt * 2 or 0.3 * dt
	local delta = s.real - s.eased
	if math.abs(delta) > _dt then
		delta = delta * _dt / math.abs(delta)
	end
	s.eased = s.eased + delta
	s.amount = _dt * s.eased + (1 - _dt) * s.amount
	B.spin_time = B.spin_time + dt * s.amount - 60 * (s.eased - s.amount) * _dt
end
