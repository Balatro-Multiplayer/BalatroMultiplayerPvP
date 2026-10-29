-- speedlatro specific timer
-- i can't be bothered to do run_start hooks and risk that being janky so it'll be initialized in gupdate

MPAPI.Layer("speedlatro_timer", {
    preview_calculate_delay = 5,
    preview_calculate_cost  = 0,
    timer_speedup_multiplier = 2,
})

local base_timer = 147

local gupdate = Game.update
function Game:update(dt)
	if PVP.is_layer_active("speedlatro_timer") and G.STAGE == G.STAGES.RUN then
		if not PVP.speedlatro_timer then
			PVP.speedlatro_timer = { real = base_timer, display = base_timer }
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
                                        func = "mp_update_speedlatro_timer",
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
		-- holy fucking conditional
		if
			not (
				G.STATE == G.STATES.HAND_PLAYED
				and G.GAME.current_round.hands_left < 1
				and G.STATE_COMPLETE
				and PVP.LOBBY.connected
				and PVP.LOBBY.code
				and PVP.is_pvp_boss()
			)
		then
			if not (G.CONTROLLER.locks.enter_pvp or PVP.GAME.ready_blind or PVP.speedlatro_timer.wait) then
				local self_score = PVP.Score.from_game_value(G.GAME.chips)

				if (not PVP.is_pvp_boss()) or PVP.Score.greater(PVP.GAME.enemy.score, self_score) then
					local speedup = PVP.current_ruleset().timer_speedup_multiplier or 2
					local tick_mult = (PVP.GAME.nemesis_timer_started and not PVP.is_pvp_boss()) and speedup or 1
					PVP.speedlatro_timer.real = PVP.speedlatro_timer.real - dt * tick_mult
				end
			end
		end
		if PVP.speedlatro_timer.real <= 0 then
			PVP.speedlatro_timer.real = 0
			-- weird logic flow
			if PVP.LOBBY.code then
				if not PVP.speedlatro_timer.failed then
					PVP.ACTIONS.fail_timer()
					PVP.speedlatro_timer.failed = true
				end
			elseif G.STATE ~= G.STATES.GAME_OVER then
				G.STATE = G.STATES.GAME_OVER
				G.STATE_COMPLETE = false
			end
		end

		-- fun
		PVP.GAME.timer = 999

		local suffix = string.sub(math.floor((PVP.speedlatro_timer.real + 100) * 100), -2)
		PVP.speedlatro_timer.display = math.floor(PVP.speedlatro_timer.real) .. "." .. suffix
	elseif PVP.speedlatro_timer then
		PVP.speedlatro_timer.text:remove()
		PVP.speedlatro_timer = nil
	end
	return gupdate(self, dt)
end

-- not perfect but whatever this mode is janky anyways

local new_round_ref = new_round
function new_round()
	if PVP.is_layer_active("speedlatro_timer") then
		if PVP.LOBBY.code then
			if G.GAME.round_resets.blind == G.P_BLINDS["bl_mp_nemesis"] then
				PVP.speedlatro_timer.real = base_timer / 2
				PVP.speedlatro_timer.failed = false
				PVP.speedlatro_timer.wait = true

				-- held together by thin and wispy threads of what humans could describe as motivation. there may exist a stronger analogue yet
				-- anyway if we don't do this you'll lose some time at the start of the pvp. would be fine if it wasn't inconsistent
				G.E_MANAGER:add_event(Event({
					blockable = false,
					blocking = false,
					trigger = "after",
					delay = 4,
					func = function()
						PVP.speedlatro_timer.wait = false
					end,
				}))
			end
		elseif
			G.GAME.round_resets.blind ~= G.P_BLINDS["bl_small"]
			and G.GAME.round_resets.blind ~= G.P_BLINDS["bl_big"]
		then
			PVP.speedlatro_timer.real = base_timer / 2
		end
	end
	return new_round_ref()
end

local end_round_ref = end_round
function end_round()
	if PVP.is_layer_active("speedlatro_timer") then
		if PVP.LOBBY.code then
			if PVP.is_pvp_boss() then
				PVP.speedlatro_timer.real = base_timer
				PVP.speedlatro_timer.failed = false
			end
		elseif G.GAME.blind:get_type() == "Boss" then
			PVP.speedlatro_timer.real = base_timer
		end
	end
	return end_round_ref()
end

G.FUNCS.mp_update_speedlatro_timer = function(e)
    if e.config.object then
        e.config.object.colours[1] = (PVP.GAME.nemesis_timer_started and not PVP.is_pvp_boss() and PVP.speedlatro_timer.real > 0)
            and SMODS.Gradients["mp_speedlatro_timer_accelerated"]
            or G.C.WHITE
    end
end
