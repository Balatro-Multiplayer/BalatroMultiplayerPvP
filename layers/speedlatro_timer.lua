-- Speedlatro/Chaos clock: my personal countdown, read from the server's view. The server owns its
-- start, its rate and its run-out (a life); nothing here ticks or ends anything.

MPAPI.Layer("speedlatro_timer", {
	preview_calculate_delay = 5,
	preview_calculate_cost = 0,
	timer_speedup_multiplier = 2,
})

local base_timer = 147

local function create_text()
	PVP.UI.speedlatro_timer = { real = base_timer, display = PVP.READ.timer.hundredths_text(base_timer) }
	PVP.UI.speedlatro_timer.text = UIBox({
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
								func = "mp_update_speedlatro_timer",
								object = DynaText({
									scale = 1.1,
									string = { { ref_table = PVP.UI.speedlatro_timer, ref_value = "display" } },
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

-- No lobby: the clock is local (seconds in PVP.UI.speedlatro_timer.real) and its run-out ends the run.
local function tick_local(dt)
	local timer = PVP.UI.speedlatro_timer
	if not (G.CONTROLLER.locks.enter_pvp or PVP.GAME.ready_blind or timer.wait) then
		local self_score = PVP.SCORE.from_game_value(G.GAME.chips)
		if (not PVP.UTILS.is_pvp_blind()) or PVP.SCORE.greater(PVP.GAME.enemy.score, self_score) then
			local speedup = PVP.RULES.current().timer_speedup_multiplier or 2
			local tick_mult = (PVP.UI.timer.clock() == "against me" and not PVP.UTILS.is_pvp_blind()) and speedup or 1
			timer.real = timer.real - dt * tick_mult
		end
	end
	if timer.real <= 0 then
		timer.real = 0
		if G.STATE ~= G.STATES.GAME_OVER then
			G.STATE = G.STATES.GAME_OVER
			G.STATE_COMPLETE = false
		end
	end
	timer.display = PVP.READ.timer.hundredths_text(timer.real)
end

local game_update = Game.update
function Game:update(dt)
	if PVP.RULES.is_layer_active("speedlatro_timer") and G.STAGE == G.STAGES.RUN then
		if not PVP.UI.speedlatro_timer then create_text() end
		if PVP.LOBBY.code then
			-- In a lobby the server owns the clock and its run-out.
			local personal = PVP.UI.timer.personal and PVP.UI.timer.personal()
			PVP.UI.speedlatro_timer.display = personal and PVP.READ.timer.hundredths_text(personal.seconds) or localize("k_timer_none")
		else
			tick_local(dt)
		end
	elseif PVP.UI.speedlatro_timer then
		PVP.UI.speedlatro_timer.text:remove()
		PVP.UI.speedlatro_timer = nil
	end
	return game_update(self, dt)
end

-- No lobby only: the local clock's refills. In a lobby the server refills it.
local new_round_ref = new_round
function new_round()
	if PVP.RULES.is_layer_active("speedlatro_timer") and not PVP.LOBBY.code and PVP.UI.speedlatro_timer then
		if
			G.GAME.round_resets.blind ~= G.P_BLINDS["bl_small"]
			and G.GAME.round_resets.blind ~= G.P_BLINDS["bl_big"]
		then
			PVP.UI.speedlatro_timer.real = base_timer / 2
		end
	end
	return new_round_ref()
end

local end_round_ref = end_round
function end_round()
	if PVP.RULES.is_layer_active("speedlatro_timer") and not PVP.LOBBY.code and PVP.UI.speedlatro_timer then
		if G.GAME.blind:get_type() == "Boss" then PVP.UI.speedlatro_timer.real = base_timer end
	end
	return end_round_ref()
end

G.FUNCS.mp_update_speedlatro_timer = function(e)
	if not e.config.object then return end
	local accelerated
	if PVP.LOBBY.code then
		accelerated = PVP.READ.timer.accelerated(PVP.UI.timer.personal())
	else
		accelerated = PVP.UI.timer.clock() == "against me"
			and not PVP.UTILS.is_pvp_blind()
			and PVP.UI.speedlatro_timer.real > 0
	end
	e.config.object.colours[1] = accelerated and SMODS.Gradients["mp_speedlatro_timer_accelerated"] or G.C.WHITE
end
