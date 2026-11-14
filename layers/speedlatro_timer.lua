-- Speedlatro practice clock. In a lobby the server owns every clock (rules.clocks) and the HUD
-- reads clock_view; this layer keeps one self-contained clock for a practice run (PVP.is_practice_mode()).
-- A replay playback is not a practice run and has no clock. It sends nothing and reports nothing,
-- so it never changes another player's outcome.

MPAPI.Layer("speedlatro_timer", {
	preview_calculate_delay = 5,
})

local BASE_SECONDS = 147

-- Pure clock arithmetic: seconds in, seconds out.
PVP.PracticeClock = {
	BASE_SECONDS = BASE_SECONDS,

	tick = function(real, dt)
		return math.max(0, real - dt)
	end,

	-- A new Boss round starts on half the base; the small and big blinds leave the clock alone.
	on_new_round = function(real, is_small_or_big)
		if is_small_or_big then return real end
		return BASE_SECONDS / 2
	end,

	-- Beating a Boss refills the clock.
	on_end_round = function(real, is_boss)
		if is_boss then return BASE_SECONDS end
		return real
	end,

	display = function(real)
		local suffix = string.sub(math.floor((real + 100) * 100), -2)
		return math.floor(real) .. "." .. suffix
	end,
}

local function practice_run()
	return PVP.is_practice_mode() and PVP.SP.playback_gamemode == nil
end

local function remove_practice_clock()
	if PVP.speedlatro_timer then
		PVP.speedlatro_timer.text:remove()
		PVP.speedlatro_timer = nil
	end
end

local function build_practice_clock()
	PVP.speedlatro_timer = { real = BASE_SECONDS, display = PVP.PracticeClock.display(BASE_SECONDS) }
	PVP.speedlatro_timer.text = UIBox({
		definition = {
			n = G.UIT.ROOT,
			config = { align = "cm", colour = G.C.CLEAR, padding = 0.2 },
			nodes = {
				{
					n = G.UIT.R,
					config = { align = "cm", maxw = 1 },
					nodes = {
						{
							n = G.UIT.O,
							config = {
								object = DynaText({
									scale = 1.1,
									string = { { ref_table = PVP.speedlatro_timer, ref_value = "display" } },
									maxw = 18,
									colours = { G.C.WHITE },
									float = true,
									shadow = true,
									silent = true,
									pop_in = 0,
									pop_in_rate = 6,
								}),
							},
						},
					},
				},
			},
		},
		config = {
			align = "cm",
			offset = { x = 0.3, y = -2.9 },
			major = G.deck,
		},
	})
end

local gupdate = Game.update
function Game:update(dt)
	if PVP.is_layer_active("speedlatro_timer") and G.STAGE == G.STAGES.RUN and practice_run() then
		if not PVP.speedlatro_timer then build_practice_clock() end
		local clock = PVP.speedlatro_timer
		clock.real = PVP.PracticeClock.tick(clock.real, dt)
		if clock.real <= 0 and G.STATE ~= G.STATES.GAME_OVER then
			G.STATE = G.STATES.GAME_OVER
			G.STATE_COMPLETE = false
		end
		clock.display = PVP.PracticeClock.display(clock.real)
	else
		remove_practice_clock()
	end
	return gupdate(self, dt)
end

local new_round_ref = new_round
function new_round()
	if PVP.speedlatro_timer and PVP.is_layer_active("speedlatro_timer") and practice_run() then
		local blind = G.GAME.round_resets.blind
		PVP.speedlatro_timer.real = PVP.PracticeClock.on_new_round(
			PVP.speedlatro_timer.real,
			blind == G.P_BLINDS["bl_small"] or blind == G.P_BLINDS["bl_big"]
		)
	end
	return new_round_ref()
end

local end_round_ref = end_round
function end_round()
	if PVP.speedlatro_timer and PVP.is_layer_active("speedlatro_timer") and practice_run() then
		PVP.speedlatro_timer.real = PVP.PracticeClock.on_end_round(
			PVP.speedlatro_timer.real,
			G.GAME.blind:get_type() == "Boss"
		)
	end
	return end_round_ref()
end
