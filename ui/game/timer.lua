-- ease_round override moved to game/round.lua

-- The server counts every clock; this file only draws what it publishes. What the timer box shows is
-- decided by PVP.TimerView.box over the server's clock rules, deadline, personal clock and bank.
function PVP.UI.timer_box()
	local lobby = MPAPI.get_current_lobby()
	local personal = lobby and PVP.ClocksNet.read(lobby.player_id) or { known = false }
	return PVP.TimerView.box(
		PVP.clocks_rules(),
		PVP.is_pvp_boss(),
		personal,
		PVP.TimerNet.shown_seconds(),
		PVP.SkipsNet.bank_seconds(),
		lobby and PVP.TimerView.pvp_left_seconds(MPAPI.get_state("pvp.round"), PVP.current_run_id(), lobby.player_id)
			or nil
	)
end

function PVP.UI.cam_timer_opponent()
	if not PVP.LOBBY.config.timer then return false end
	if PVP.GAME.pvp_countdown_in_progress then return false end
	local box = PVP.UI.timer_box()
	if box.kind == "seconds" and not box.pvp_allowance and box.seconds <= 0 then return false end
	if PVP.GAME.nemesis_timer_started then return false end
	local clocks = PVP.clocks_rules()
	if PVP.is_pvp_boss() and clocks ~= nil and clocks.pvp ~= nil then
		if PVP.GAME.end_pvp then return false end
		if G.STATE == G.STATES.ROUND_EVAL or G.STATE == G.STATES.NEW_ROUND then return false end
		-- The server decides who may time the PvP blind (wouldTime): the button follows its canTime.
		local lobby = MPAPI.get_current_lobby()
		return lobby ~= nil
			and PVP.TimerView.can_time(MPAPI.get_state("pvp.round"), PVP.current_run_id(), lobby.player_id)
	end
	return PVP.GAME.ready_blind
end

function G.FUNCS.mp_timer_button(e)
	-- cam_timer_opponent only decides whether the button is offered; the server decides
	-- whether the press counts (pvp_api/timer_net.lua), and the timer box follows its state.
	if PVP.UI.cam_timer_opponent() then
		if not PVP.GAME.timer_started then
			PVP.TimerNet.start(PVP.is_pvp_boss() and "pvp" or "ante")
		else
			PVP.TimerNet.pause()
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
									string = {
										{
											-- Read at draw time: the box text is never kept, so it cannot go stale.
											ref_table = setmetatable({}, {
												__index = function()
													local box = PVP.UI.timer_box()
													if box.kind == "speedlatro" then return ">>" end
													if box.kind == "unknown" then return "--" end
													local running, allowance = box.running, box.pvp_allowance
													return PVP.UTILS.timer_display_text(box.seconds, running, allowance)
												end,
											}),
											ref_value = "timer",
										},
									},
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
	local tick_delay = 1
	local seconds = PVP.LOBBY and PVP.LOBBY.config and PVP.LOBBY.config.pvp_countdown_seconds
	if seconds == nil then
		PVP.match_log("info", "[pvp] countdown seconds are not in the lobby options: using the default")
		seconds = PVP.DEFAULT_COUNTDOWN_SECONDS
	end
	-- What this countdown is for, kept in case a reconnect wipes PVP.GAME under it.
	local round_id = PVP.GAME.round_id
	local blind_context = PVP.GAME.next_blind_context
	PVP.GAME.pvp_countdown_in_progress = true
	PVP.GAME.pvp_countdown = seconds

	G.CONTROLLER.locks.enter_pvp = true

	local function show_next()
		-- A reconnect in this process reset PVP.GAME: the count is gone and so is the blind this
		-- countdown was for. End it and release its lock, then hand the round back: the start record
		-- counts it as started, so without this nothing would start the blind again and the player
		-- would sit on Blind Select. The same server state is read again and starts it afresh.
		if PVP.GAME.pvp_countdown == nil then
			G.CONTROLLER.locks.enter_pvp = nil
			PVP.GAME.next_blind_context = PVP.GAME.next_blind_context or blind_context
			if PVP.ReadyNet and round_id then
				PVP.ReadyNet.forget_start(round_id)
				PVP.ReadyNet.evaluate()
			end
			return true
		end
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
		-- The pulse follows a run's server clocks, and there is no run outside a lobby. Gradients
		-- update from boot, before pvp_api (the nets this reads) has loaded.
		if not MPAPI.get_current_lobby() then return end
		local clocks = PVP.clocks_rules()
		local rate = clocks ~= nil and clocks.personal ~= nil and clocks.personal.timedRate or 1
		local speedup = PVP.GAME.timer_started and 1 or rate

		-- When you "timering" opponent, timer stops and you cannot see is button pressed
		-- So we need switch to real timer to make it flush
		local time_value = PVP.GAME.timer_started and G.TIMERS.REAL or -(PVP.UI.timer_box().seconds or 0)
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
function G.FUNCS.set_timer_box(e)
	if PVP.LOBBY.config.timer then
		if PVP.GAME.timer_started or PVP.GAME.nemesis_timer_started then
			e.config.colour = G.C.DYN_UI.BOSS_DARK
			-- Pulse because why not
			e.children[1].config.object.colours = {
				(PVP.UI.timer_box().seconds or 0) > 0 and SMODS.Gradients["mp_timer_accelerated"] or G.C.IMPORTANT,
			}
			return
		end
		if not PVP.GAME.timer_started and PVP.UI.cam_timer_opponent() then
			e.config.colour = G.C.IMPORTANT
			e.children[1].config.object.colours = { G.C.UI.TEXT_LIGHT }
			return
		end
		e.config.colour = G.C.DYN_UI.BOSS_DARK
		local clocks = PVP.clocks_rules()
		local pressure = clocks ~= nil and clocks.personal ~= nil and clocks.personal.kind == "pressure"
		e.children[1].config.object.colours = {
			(pressure and not PVP.is_pvp_boss() and not PVP.GAME.pvp_countdown_in_progress) and G.C.IMPORTANT
				or G.C.UI.TEXT_DARK,
		}
	end
end

-- RLOG's play opcode is now recorded once, generically, by
-- BalatroMultiplayerAPI/api/replay/generic_codes.lua's own
-- G.FUNCS.play_cards_from_highlighted hook -- this override stays for
-- the double-play guard and the PvP hand commit below.
local old_play = G.FUNCS.play_cards_from_highlighted
-- A second Play before the first hand has been played is ignored (lib/play_lock.lua).
function G.FUNCS.play_cards_from_highlighted(...)
	-- Vanilla takes the hand off hands_left in an event, so this is the count before this hand.
	local hands_left = G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left
	if not PVP.PlayLock.run(old_play, ...) then
		return
	end
	if G.play and G.play.cards[1] then
		return
	end
	-- The server credits this hand's time on its own clock: tell it the hand is played, before the animation.
	local clocks = PVP.clocks_rules()
	if PVP.LOBBY.code and PVP.is_pvp_boss() and clocks ~= nil and clocks.pvp ~= nil then
		if type(hands_left) ~= "number" then
			PVP.match_log("warn", "[pvp] hand_commit skipped: hands_left is unknown")
			return
		end
		PVP.ACTIONS.hand_commit(hands_left - 1)
	end
end
