-- ease_round override moved to game/round.lua

-- The button shows while the server says I may start a timer, or while my own timer runs (to pause it).
function PVP.UI.cam_timer_opponent()
	if not PVP.LOBBY.config.timer then return false end
	return PVP.UI.timer.button() ~= nil
end

function G.FUNCS.mp_timer_button(e)
	PVP.UI.timer.press()
end

function PVP.UI.timer_hud()
	if PVP.LOBBY.config.timer then
		return {
			n = G.UIT.C,
			config = {
				align = "cm",
				padding = 0.05,
				minw = 1.45,
				minh = 1,
				colour = G.C.DYN_UI.BOSS_MAIN,
				emboss = 0.05,
				r = 0.1,
			},
			nodes = {
				{
					n = G.UIT.R,
					config = { align = "cm", maxw = 1.35 },
					nodes = {
						{
							n = G.UIT.T,
							config = {
								text = localize("k_timer"),
								minh = 0.33,
								scale = 0.34,
								colour = G.C.UI.TEXT_LIGHT,
								shadow = true,
							},
						},
					},
				},
				{
					n = G.UIT.R,
					config = {
						align = "cm",
						r = 0.1,
						minw = 1.2,
						colour = G.C.DYN_UI.BOSS_DARK,
						id = "row_round_text",
						func = "set_timer_box",
						button = "mp_timer_button",
					},
					nodes = {
						{
							n = G.UIT.O,
							config = {
								object = DynaText({
									string = PVP.RULES.is_layer_active("speedlatro_timer") and ">>" or {
										{
											ref_table = setmetatable({}, {
												__index = function()
													return PVP.UI.timer.text()
												end,
											}),
											ref_value = "timer",
										},
									}, -- sorry
									colours = { G.C.UI.TEXT_DARK },
									shadow = true,
									scale = 0.8,
								}),
								id = "timer_UI_count",
							},
						},
					},
				},
			},
		}
	end
end

function PVP.UI.start_pvp_countdown(callback)
	local seconds = countdown_seconds
	local tick_delay = 1
	if PVP.LOBBY and PVP.LOBBY.config and PVP.LOBBY.config.pvp_countdown_seconds then
		seconds = PVP.LOBBY.config.pvp_countdown_seconds
	end
    PVP.GAME.pvp_countdown_in_progress = true
	PVP.GAME.pvp_countdown = seconds

	G.CONTROLLER.locks.enter_pvp = true

	local function show_next()
		if PVP.GAME.pvp_countdown <= 0 then
			if callback then callback() end
            G.E_MANAGER:add_event(Event({
                blocking = false,
                func = function()
                    G.E_MANAGER:add_event(Event({
                        blocking = false,
                        func = function()
                            PVP.GAME.pvp_countdown_in_progress = nil
                            return true
                        end,
                    }))
                    return true
                end,
            }))
			G.E_MANAGER:add_event(Event({
				no_delete = true,
				trigger = "after",
				blocking = false,
				blockable = false,
				delay = 1,
				timer = "TOTAL",
				func = function()
					G.CONTROLLER.locks.enter_pvp = nil
					return true
				end,
			}))
			return true
		end

		G.FUNCS.attention_text_realtime({
			text = tostring(PVP.GAME.pvp_countdown),
			scale = 5,
			hold = 0.85,
			align = "cm",
			major = G.play,
			backdrop_colour = G.C.MULT,
		})

		play_sound("tarot2", 1, 0.4)

		PVP.GAME.pvp_countdown = PVP.GAME.pvp_countdown - 1

		G.E_MANAGER:add_event(Event({
			trigger = "after",
			timer = "REAL",
			delay = tick_delay,
			blockable = false,
			func = show_next,
		}))
		return true
	end

	G.E_MANAGER:add_event(Event({
		trigger = "after",
		timer = "REAL",
		delay = 0,
		blockable = false,
		func = show_next,
	}))
end

SMODS.Gradient({
	key = "timer_accelerated",
	cycle = 1,
	colours = {
		mix_colours(G.C.WHITE, G.C.IMPORTANT, 0.55),
		G.C.IMPORTANT,
		G.C.IMPORTANT,
		G.C.IMPORTANT,
		G.C.IMPORTANT,
	},
	update = function(self, dt)
		if #self.colours < 2 or not PVP.LOBBY.config.ruleset or not PVP.UI.timer.timing then return end
		local own_clock = PVP.UI.timer.timing()
		local speedup = own_clock and 1 or PVP.UI.timer.rate()

		-- When you "timering" opponent, timer stops and you cannot see is button pressed
		-- So we need switch to real timer to make it flush
		local time_value = own_clock and G.TIMERS.REAL or -(PVP.UI.timer.seconds() or 0)
		local timer = (time_value / speedup) % self.cycle
		local start_index = math.ceil(timer * #self.colours / self.cycle)
		if start_index == 0 then start_index = 1 end
		local end_index = start_index == #self.colours and 1 or start_index + 1
		local start_colour, end_colour = self.colours[start_index], self.colours[end_index]
		local partial_timer = (timer % (self.cycle / #self.colours)) * #self.colours / self.cycle
		for i = 1, 4 do
			if self.interpolation == "linear" then
				self[i] = start_colour[i] + partial_timer * (end_colour[i] - start_colour[i])
			elseif self.interpolation == "trig" then
				self[i] = start_colour[i]
					+ 0.5 * (1 - math.cos(partial_timer * math.pi)) * (end_colour[i] - start_colour[i])
			end
		end
	end,
})
SMODS.Gradient({
	key = "speedlatro_timer_accelerated",
	cycle = 1,
	colours = {
		G.C.WHITE,
		G.C.WHITE,
		G.C.WHITE,
		G.C.WHITE,
		mix_colours(G.C.IMPORTANT, G.C.WHITE, 0.55),
	},
	update = function(self, dt)
		if #self.colours < 2 or not PVP.UI.speedlatro_timer or not PVP.UI.timer.personal then return end
		local speedup, seconds
		if PVP.LOBBY.code then
			local personal = PVP.UI.timer.personal()
			speedup, seconds = personal and personal.rate or 1, personal and personal.seconds or 0
		else
			speedup, seconds = PVP.RULES.current().timer_speedup_multiplier or 1, PVP.UI.speedlatro_timer.real or 0
		end

		local timer_value = PVP.GAME.ready_blind and 0 or -seconds
		local timer = (timer_value / speedup) % self.cycle
		local start_index = math.ceil(timer * #self.colours / self.cycle)
		if start_index == 0 then start_index = 1 end
		local end_index = start_index == #self.colours and 1 or start_index + 1
		local start_colour, end_colour = self.colours[start_index], self.colours[end_index]
		local partial_timer = (timer % (self.cycle / #self.colours)) * #self.colours / self.cycle
		for i = 1, 4 do
			if self.interpolation == "linear" then
				self[i] = start_colour[i] + partial_timer * (end_colour[i] - start_colour[i])
			elseif self.interpolation == "trig" then
				self[i] = start_colour[i]
					+ 0.5 * (1 - math.cos(partial_timer * math.pi)) * (end_colour[i] - start_colour[i])
			end
		end
	end,
})

-- pvp_api loads after ui, so the hint table is built on first use.
local timer_tooltip_keys
local function tooltip_keys()
	local Tip = PVP.READ.timer.Tip
	timer_tooltip_keys = timer_tooltip_keys or {
		[Tip.CAN_START] = { "k_timer_tip_can_start_1", "k_timer_tip_can_start_2" },
		[Tip.CAN_PAUSE] = { "k_timer_tip_can_pause_1", "k_timer_tip_can_pause_2" },
		[Tip.RUNNING] = { "k_timer_tip_running" },
		[Tip.AGAINST_ME] = { "k_timer_tip_nemesis_running_1", "k_timer_tip_nemesis_running_2" },
		[Tip.EXPIRED] = { "k_timer_tip_expired" },
		[Tip.IDLE] = { "k_timer_tip_idle_1", "k_timer_tip_idle_2" },
		[Tip.BLOCKED] = { "k_timer_tip_blocked_1", "k_timer_tip_blocked_2" },
	}
	return timer_tooltip_keys
end

-- Swap the tooltip only when the state changes; if it's open, rebuild it in place.
local function update_timer_tooltip(e)
	local state = PVP.UI.timer.tip()
	if e.config.mp_timer_tooltip_state == state then return end
	e.config.mp_timer_tooltip_state = state
	local text = {}
	for i, key in ipairs(tooltip_keys()[state]) do
		text[i] = localize(key)
	end
	e.config.on_demand_tooltip = { text = text }
	if e.states and e.states.hover and e.states.hover.is then
		e:stop_hover()
		e:hover()
	end
end

function G.FUNCS.set_timer_box(e)
	if PVP.LOBBY.config.timer then
		update_timer_tooltip(e)
		if PVP.UI.timer.timed() then
			e.config.colour = G.C.DYN_UI.BOSS_DARK
			-- Pulse because why not
			e.children[1].config.object.colours = {
				(PVP.UI.timer.seconds() or 0) > 0 and SMODS.Gradients["mp_timer_accelerated"] or G.C.IMPORTANT,
			}
			return
		end
		if not PVP.UI.timer.timing() and PVP.UI.cam_timer_opponent() then
			e.config.colour = G.C.IMPORTANT
			e.children[1].config.object.colours = { G.C.UI.TEXT_LIGHT }
			return
		end
		e.config.colour = G.C.DYN_UI.BOSS_DARK
		e.children[1].config.object.colours =
			{
                (not PVP.UTILS.is_pvp_blind() and not PVP.GAME.pvp_countdown_in_progress and PVP.RULES.is_layer_active("pressure_timer"))
                and G.C.IMPORTANT or G.C.UI.TEXT_DARK
            }
	end
end

-- RLOG's play opcode is now recorded once, generically, by
-- BalatroMultiplayerAPI/api/replay/generic_codes.lua's own
-- G.FUNCS.play_cards_from_highlighted hook -- this override stays for
-- the double-play guard and the handPlayed input.
local old_play = G.FUNCS.play_cards_from_highlighted
-- A second Play before the first hand has been played is ignored (lib/play_lock.lua).
-- Play is refused here too, not only on the button: a paused game keeps the button lit.
function G.FUNCS.play_cards_from_highlighted(...)
	if not PVP.UI.pvp_blind.may_play() then return end
	local hand_played = PVP.UI.pvp_blind.play_body()
	if not PVP.ACTIONS.play_lock.run(old_play, ...) then
		return
	end
	PVP.UI.pvp_blind.send_hand_played(hand_played)
end