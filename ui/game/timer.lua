-- ease_round override moved to game/round.lua

function PVP.UI.cam_timer_opponent()
	if not PVP.LOBBY.config.timer then return false end
    if PVP.GAME.pvp_countdown_in_progress then return false end
    if PVP.GAME.timer <= 0 then return false end
    if PVP.GAME.nemesis_timer_started then return false end
	if PVP.is_pvp_boss() and PVP.is_layer_active("pvp_timer") then
        if PVP.GAME.end_pvp then return false end
		if G.STATE == G.STATES.ROUND_EVAL or G.STATE == G.STATES.NEW_ROUND then return false end
        if PVP.LOBBY.config.hide_score_until_played and not PVP.GAME.enemy.info_received then return false end
		if PVP.Score.greater(PVP.GAME.score, PVP.GAME.enemy.real_score) then return true end
        if PVP.Score.equal(PVP.GAME.score, PVP.GAME.enemy.real_score) then return PVP.GAME.pvp_reached_first end
		return false
	end
	return PVP.GAME.ready_blind
end

function G.FUNCS.mp_timer_button(e)
	-- Under pressure_timer the local timer auto-ticks regardless of timer_started,
	-- but the button still needs to fire — pressing it broadcasts startAnteTimer,
	-- which is what flips the opponent's nemesis_timer_started and triggers 2x.
	if PVP.UI.cam_timer_opponent() then
		if PVP.GAME.timer <= 0 then
			return
		elseif not PVP.GAME.timer_started then
			PVP.ACTIONS.start_ante_timer()
		else
			PVP.ACTIONS.pause_ante_timer()
		end
	end
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
									string = PVP.is_layer_active("speedlatro_timer") and ">>" or {
										{
											ref_table = setmetatable({}, {
												__index = function()
													if not PVP.GAME.timer then return 0 end
													return PVP.UTILS.timer_display_text(
														PVP.GAME.timer,
														PVP.GAME.timer_started or PVP.GAME.nemesis_timer_started
													)
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
		if #self.colours < 2 or not PVP.LOBBY.config.ruleset then return end
		local speedup = PVP.GAME.timer_started and 1 or PVP.current_ruleset().timer_speedup_multiplier or 1

		-- When you "timering" opponent, timer stops and you cannot see is button pressed
		-- So we need switch to real timer to make it flush
		local time_value = PVP.GAME.timer_started and G.TIMERS.REAL or -(PVP.GAME.timer or 0)
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
		if #self.colours < 2 or not PVP.speedlatro_timer then return end
		local speedup = PVP.current_ruleset().timer_speedup_multiplier or 1

        local timer_value = PVP.GAME.ready_blind and 0 or -(PVP.speedlatro_timer.real or 0)
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

function G.FUNCS.set_timer_box(e)
	if PVP.LOBBY.config.timer then
		if PVP.GAME.timer_started or PVP.GAME.nemesis_timer_started then
			e.config.colour = G.C.DYN_UI.BOSS_DARK
			-- Pulse because why not
			e.children[1].config.object.colours = {
				PVP.GAME.timer > 0 and SMODS.Gradients["mp_timer_accelerated"] or G.C.IMPORTANT,
			}
			return
		end
		if not PVP.GAME.timer_started and PVP.UI.cam_timer_opponent() then
			e.config.colour = G.C.IMPORTANT
			e.children[1].config.object.colours = { G.C.UI.TEXT_LIGHT }
			return
		end
		e.config.colour = G.C.DYN_UI.BOSS_DARK
		e.children[1].config.object.colours =
			{
                (not PVP.is_pvp_boss() and not PVP.GAME.pvp_countdown_in_progress and PVP.is_layer_active("pressure_timer"))
                and G.C.IMPORTANT or G.C.UI.TEXT_DARK
            }
	end
end

local animation_budget_capacity = 40
local animation_budget_restore_rate = 2.5
local animation_budget_decay_rate = 0

PVP.TIMER_ANIMATION_BUDGET = animation_budget_capacity

local gameUpdateRef = Game.update
---@diagnostic disable-next-line: duplicate-set-field
function Game:update(dt)
	gameUpdateRef(self, dt)

	-- If I let timer tick only when we're in PVP context
	-- then big jump of dt will happend between state changes.
	-- So we need count time all the time. Sad!

	-- Again, we cannot rely on any variant of dt since game does not
	-- update at all while window is grabbed,
	-- and when you release it dt does not reflect time wasted

	-- This thing cost NOTHING im comparision to game drawing and UI updating
	-- We can afford some inefficiencies.
	local new_time = love.timer.getTime()
	local timer_dt = new_time - (PVP.TIMER_CLOCK or new_time)
	PVP.TIMER_CLOCK = new_time

	-- Remove gamespeed force setted up for previous frame
	PVP.TIMER_FORCE_GAMESPEED = false

	-- Restore animation budget (used to prevent skipping too much time by animations)
	PVP.TIMER_ANIMATION_BUDGET =
		math.min(animation_budget_capacity, PVP.TIMER_ANIMATION_BUDGET + timer_dt * animation_budget_restore_rate)

	-- Bail fast: not an PVP PvP-timer context
	if G.STATE == G.STATES.GAME_OVER then return end
	if not PVP.LOBBY.code then return end
	if not PVP.LOBBY.config.timer then return end
	if PVP.GAME.timer_consumed then return end
	if not PVP.GAME.timer or PVP.GAME.timer <= 0 then return end
	if PVP.is_layer_active("speedlatro_timer") then return end

	local is_no_animation_timer = PVP.is_layer_active("no_animation_timer")
	local is_pressure_timer = PVP.is_layer_active("pressure_timer")
	local is_pvp_boss = PVP.is_pvp_boss()
	local is_pvp_timer = PVP.is_layer_active("pvp_timer") and is_pvp_boss

	-- Tick gating differs by layer:
	--   pressure_timer ON  -> tick during regular play (not ready_blind, not pvp boss)
	--   pressure_timer OFF -> tick whenever someone pressed a timer button.
	--     timer_started = YOU pressed it; nemesis_timer_started = OPPONENT pressed it
	--     (i.e. they're timering you). Either way your local timer should tick.
	local should_check_animations = false

	if is_pvp_timer then
        -- PvP timer: tick when opponent timering, stop when animations, state checks, pvp blind only
		if not PVP.GAME.nemesis_timer_started then return end
        if G.GAME.current_round.hands_left <= 0 then return end
		if G.STATE == G.STATES.NEW_ROUND or G.STATE == G.STATES.ROUND_EVAL then return end
		should_check_animations = true
	elseif is_pressure_timer then
        -- Pressure timer: tick from the start of a game, stop when reached pvp (unless timered) or animations, not in pvp blind
		if PVP.GAME.pvp_reached and not PVP.GAME.nemesis_timer_started then return end
		if PVP.GAME.ready_blind or is_pvp_boss then return end
		should_check_animations = true
	elseif is_no_animation_timer then
        -- No-animation timer: tick when opponen timering, stop when animations, not in pvp
		if not PVP.GAME.nemesis_timer_started then return end
		if PVP.GAME.ready_blind or is_pvp_boss then return end
		should_check_animations = true
	else
        -- Old timer: tick when opponent timering, not in pvp
        if is_pvp_boss then return end
        if PVP.GAME.pvp_reached and PVP.GAME.ready_blind and not PVP.GAME.timer_started then return end
		if not (PVP.GAME.timer_started or PVP.GAME.nemesis_timer_started) then return end
	end

	if should_check_animations then
		PVP.TIMER_FORCE_GAMESPEED = true

		-- Don't tick during animations, unless the user is paused or has a menu open
		local interactive = not ((G.CONTROLLER.locked and not G.CONTROLLER.locks.frame) or (G.GAME.STOP_USE or 0) > 0)
		local menu_or_paused = G.SETTINGS.paused or G.OVERLAY_MENU

		-- Consume animations time from budget
		if not (interactive or menu_or_paused) then
			PVP.TIMER_ANIMATION_BUDGET = math.max(
				0,
				PVP.TIMER_ANIMATION_BUDGET - timer_dt * (animation_budget_restore_rate + animation_budget_decay_rate)
			)
			if PVP.TIMER_ANIMATION_BUDGET > 0 then return end
		end
	end

	local speedup = is_pvp_timer and 1 or PVP.current_ruleset().timer_speedup_multiplier or 1
	local tick_mult = PVP.GAME.nemesis_timer_started and speedup or 1
	PVP.GAME.timer = math.max(0, PVP.GAME.timer - timer_dt * tick_mult)

	if PVP.GAME.timer_threshold_pending and not PVP.UTILS.timer_start_held_back(PVP.GAME.timer) then
		PVP.GAME.timer_threshold_pending = false
		PVP.ACTIONS.announce_ante_timer(PVP.UTILS.timer_display_threshold())
	end

	if PVP.GAME.timer == 0 then
		PVP.GAME.timer_consumed = true
        -- PvP timer: end PvP immediately as a loss (only when timered by opponent)
        if is_pvp_timer then
            if PVP.GAME.nemesis_timer_started then
                PVP.ACTIONS.fail_pvp_timer()
            end
        -- Old, No-animations: lose a live when timered by opponent
        -- Pressure timers: lose a live regardless
        elseif (is_pressure_timer or PVP.GAME.nemesis_timer_started) then
            if PVP.GAME.timers_forgiven < PVP.LOBBY.config.timer_forgiveness then
                PVP.GAME.timers_forgiven = PVP.GAME.timers_forgiven + 1
            else
                PVP.ACTIONS.fail_timer()
            end
        end
	end
end

function PVP.UI.consume_timer(amount, silent, min_timer)
	if amount > 0 and PVP.LOBBY.config.timer and PVP.GAME.timer and PVP.GAME.timer > (min_timer or 0) then
		PVP.GAME.timer = math.max(0, PVP.GAME.timer - amount)
		if not silent then
			local timer_ui = G.HUD:get_UIE_by_ID("timer_UI_count")
			if timer_ui then timer_ui.config.object:juice_up() end
		end
	end
end

function PVP.UI.restore_timer(amount, silent, max_timer)
	if amount > 0 and PVP.LOBBY.config.timer and PVP.GAME.timer and (not max_timer or PVP.GAME.timer < max_timer) then
		PVP.GAME.timer = math.max(0, PVP.GAME.timer + amount)
		if not silent then
			local timer_ui = G.HUD:get_UIE_by_ID("timer_UI_count")
			if timer_ui then timer_ui.config.object:juice_up() end
		end
	end
end

-- Old timer: skip time covers only how far ahead of the opponent a player has
-- skipped since the last PvP (as in 0.5). Skipping further ahead adds
-- timer_increment_seconds; the opponent catching up takes it back (down to 10s),
-- so when both skip, both timers end where they started. A ruleset with a display
-- threshold (MLBa) keeps adding time for each of the player's own skips.
function PVP.UI.update_matching_skip_timer(from_opponent)
	local increment = PVP.LOBBY.config.timer_increment_seconds or 0
	if
		not PVP.LOBBY.config.timer
		or increment <= 0
		or PVP.is_any_layer_active({ "no_animation_timer", "pressure_timer" })
	then
		return
	end
	local threshold = PVP.UTILS.timer_display_threshold() > 0
	local change = 0
	if not threshold then
		-- The baseline moves even while the gate below is closed, so a skip made
		-- during a running timer is not paid out again later.
		local diff = math.max((PVP.GAME.skips_before_pvp or 0) - (PVP.GAME.enemy.skips_before_pvp or 0), 0)
		change = diff - (PVP.GAME.skips_difference or 0)
		PVP.GAME.skips_difference = diff
	end
	if PVP.GAME.timer_started or PVP.GAME.nemesis_timer_started or PVP.GAME.timer_consumed then
		return
	end
	if threshold then
		if not from_opponent then PVP.UI.restore_timer(increment) end
		return
	end
	if change > 0 then
		PVP.UI.restore_timer(increment)
	elseif change < 0 then
		PVP.UI.consume_timer(math.min(increment, PVP.GAME.timer - 10), false, 10)
	end
end

-- RLOG's play opcode is now recorded once, generically, by
-- BalatroMultiplayerAPI/api/replay/generic_codes.lua's own
-- G.FUNCS.play_cards_from_highlighted hook -- this override stays for
-- the double-play guard and PvP's own timer-increment logic below.
local old_play = G.FUNCS.play_cards_from_highlighted
-- Vanilla only stops a second play once the first hand's cards reach G.play, which
-- can take a while when the event queue is busy. A second click before then plays
-- the same cards again, and both hands score from the same chips, so one hand's
-- score is lost. Ignore it until the first play's events have run (or 10s pass, or
-- a new run starts: leaving clears the event queue, unlock included).
local play_pending = nil
function G.FUNCS.play_cards_from_highlighted(...)
    if play_pending and play_pending.game == G.GAME and love.timer.getTime() - play_pending.at < 10 then return end
    play_pending = { game = G.GAME, at = love.timer.getTime() }
    old_play(...)
    G.E_MANAGER:add_event(Event({ func = function() play_pending = nil; return true end }))
    if G.play and G.play.cards[1] then return end
    if PVP.LOBBY.code and PVP.LOBBY.config.timer and not PVP.GAME.timer_consumed then
        if PVP.is_pvp_boss() then
            -- PvP timer: Increment timer when hand is played during pvp
            if PVP.is_layer_active("pvp_timer") then
                local increment = PVP.LOBBY.config.pvp_timer_hand_played_increment_seconds or PVP.current_ruleset().pvp_timer_hand_played_increment_seconds or 0
                PVP.UI.restore_timer(increment)
            end
        else
            -- No-animation, Pressure timers: Increment timer when hand is played during regular blinds
            if PVP.is_any_layer_active({ "no_animation_timer", "pressure_timer" }) then
                local increment = PVP.LOBBY.config.timer_hand_played_increment_seconds or PVP.current_ruleset().timer_hand_played_increment_seconds or 0
                PVP.UI.restore_timer(increment)
            end
        end
    end
end