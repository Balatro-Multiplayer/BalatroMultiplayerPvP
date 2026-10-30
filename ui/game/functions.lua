-- Contains function overrides (monkey-patches) for G.FUNCS callbacks
-- Overrides button callback functions like can_play, can_open, select_blind, skip_blind, etc.

G.FUNCS.pvp_ready_button = function(e)
	if e.children[1].config.ref_table[e.children[1].config.ref_value] == localize("Select", "blind_states") then
		e.config.button = "mp_toggle_ready"
		e.config.one_press = false
		e.children[1].config.ref_table = PVP.GAME
		e.children[1].config.ref_value = "ready_blind_text"
	end
	if e.config.button == "mp_toggle_ready" then e.config.colour = (PVP.GAME.ready_blind and G.C.GREEN) or G.C.RED end
end

function G.FUNCS.mp_toggle_ready(e)
	sendTraceMessage("Toggling Ready", "MULTIPLAYER")
	PVP.GAME.ready_blind = not PVP.GAME.ready_blind
	PVP.GAME.ready_blind_text = PVP.GAME.ready_blind and localize("b_unready") or localize("b_ready")
	PVP.RLOG.record(MPAPI.OPCODE.READY_BLIND, PVP.GAME.ready_blind and 1 or 0)

    PVP.GAME.pvp_reached = true

	if PVP.GAME.ready_blind then
		PVP.ACTIONS.set_location("loc_ready")
		PVP.ACTIONS.ready_blind(e)
	else
		PVP.ACTIONS.set_location("loc_selecting")
		PVP.ACTIONS.pause_ante_timer()
		PVP.ACTIONS.unready_blind()
	end
end

local old_skip_blind = G.FUNCS.skip_blind
function G.FUNCS.skip_blind(...)
	old_skip_blind(...)
	if PVP.LOBBY.code then
		PVP.ACTIONS.update_location()
	end
end

local can_play_ref = G.FUNCS.can_play
G.FUNCS.can_play = function(e)
	if PVP.in_session() and G.GAME.current_round.hands_left <= 0 then
		e.config.colour = G.C.UI.BACKGROUND_INACTIVE
		e.config.button = nil
	else
		can_play_ref(e)
	end
end

local can_open_ref = G.FUNCS.can_open
G.FUNCS.can_open = function(e)
	if PVP.in_session() and PVP.GAME.ready_blind then
		e.config.colour = G.C.UI.BACKGROUND_INACTIVE
		e.config.button = nil
		return
	end
	can_open_ref(e)
end

local select_blind_ref = G.FUNCS.select_blind
function G.FUNCS.select_blind(e)
	PVP.GAME.end_pvp = false
	PVP.GAME.prevent_eval = false
	select_blind_ref(e)
	-- Confirmed-safe checkpoint for Phase 9's reconnect tail-replay -- drains
	-- any pending opponent catch-up queued since the last checkpoint.
	if PVP.RECONNECT_TAIL and PVP.in_session() then PVP.RECONNECT_TAIL.on_checkpoint() end
	if PVP.is_mp_or_practice() then
		PVP.GAME.ante_key = tostring(math.random())
		-- Carbon: log the freshly-rolled (non-deterministic) ante_key so a
		-- replay can restore it -- PvP-only opcode, still recorded directly
		-- here (not one of the shared generic opcodes). select_blind itself
		-- is now recorded once, generically, by
		-- BalatroMultiplayerAPI/api/replay/generic_codes.lua's own
		-- G.FUNCS.select_blind hook.
		PVP.RLOG.record(MPAPI.OPCODE.SET_ANTE_KEY, PVP.GAME.ante_key)
		PVP.ACTIONS.play_hand(0, G.GAME.round_resets.hands)
		PVP.ACTIONS.new_round()
		PVP.ACTIONS.set_location("loc_playing", (e.config.ref_table.key or e.config.ref_table.name))
		if PVP.UI.hide_enemy_location then PVP.UI.hide_enemy_location() end
	end
end

local skip_blind_ref = G.FUNCS.skip_blind
G.FUNCS.skip_blind = function(e)
	-- Reported before the skip moves blind_on_deck on: a pending death on this blind
	-- waits for the skipper's result, and a skipped blind counts as passed.
	if PVP.LOBBY.code then
		PVP.ACTIONS.blind_result(true)
	end
	skip_blind_ref(e)
	if PVP.LOBBY.code then
		-- Old timer: add time from skipping to own timer when not timered and not timering
		if
            PVP.LOBBY.config.timer
			and not PVP.GAME.timer_started
			and not PVP.GAME.nemesis_timer_started
            and not PVP.GAME.timer_consumed
            and not PVP.is_any_layer_active({ "no_animation_timer", "pressure_timer" })
			and (PVP.LOBBY.config.timer_increment_seconds or 0) > 0
        then
            PVP.UI.restore_timer(PVP.LOBBY.config.timer_increment_seconds)
		end

		PVP.ACTIONS.skip(G.GAME.skips)
		-- RLOG's skip_blind opcode is now recorded once, generically, by
		-- BalatroMultiplayerAPI/api/replay/generic_codes.lua's own
		-- G.FUNCS.skip_blind hook -- nothing left to do here.

		--Update the furthest blind
		local temp_furthest_blind = 0
		if G.GAME.round_resets.blind_states.Big == "Skipped" then
			temp_furthest_blind = G.GAME.round_resets.ante * 10 + 2
		elseif G.GAME.round_resets.blind_states.Small == "Skipped" then
			temp_furthest_blind = G.GAME.round_resets.ante * 10 + 1
		end

		PVP.GAME.pincher_index = PVP.GAME.pincher_index + 1

		PVP.GAME.furthest_blind = (temp_furthest_blind > PVP.GAME.furthest_blind) and temp_furthest_blind
			or PVP.GAME.furthest_blind

		PVP.ACTIONS.set_furthest_blind(PVP.GAME.furthest_blind)
	end
end

function G.FUNCS.view_nemesis_deck()
	G.SETTINGS.paused = true
	if G.deck_preview then
		G.deck_preview:remove()
		G.deck_preview = nil
	end
	G.FUNCS.overlay_menu({
		definition = G.UIDEF.create_UIBox_view_nemesis_deck(),
	})
end

-- Screen-wipe teardown (relocated from the removed legacy ui/main_menu/main_menu.lua).
-- Paired with the vanilla G.FUNCS.wipe_on(); continue_in_singleplayer below is the sole
-- caller. Standalone — only vanilla globals (G.screenwipe, G.E_MANAGER, Event).
G.FUNCS.wipe_off = function()
	G.E_MANAGER:add_event(Event({
		no_delete = true,
		func = function()
			delay(0.3)
			if not G.screenwipe then return true end
			G.screenwipe.children.particles.max = 0
			G.E_MANAGER:add_event(Event({
				trigger = "ease",
				no_delete = true,
				blockable = false,
				blocking = false,
				timer = "REAL",
				ref_table = G.screenwipe.colours.black,
				ref_value = 4,
				ease_to = 0,
				delay = 0.3,
				func = function(t)
					return t
				end,
			}))
			G.E_MANAGER:add_event(Event({
				trigger = "ease",
				no_delete = true,
				blockable = false,
				blocking = false,
				timer = "REAL",
				ref_table = G.screenwipe.colours.white,
				ref_value = 4,
				ease_to = 0,
				delay = 0.3,
				func = function(t)
					return t
				end,
			}))
			return true
		end,
	}))
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0.55,
		no_delete = true,
		blocking = false,
		timer = "REAL",
		func = function()
			if not G.screenwipe then return true end
			if G.screenwipecard then G.screenwipecard:start_dissolve({ G.C.BLACK, G.C.ORANGE, G.C.GOLD, G.C.RED }) end
			if G.screenwipe:get_UIE_by_ID("text") then
				for k, v in ipairs(G.screenwipe:get_UIE_by_ID("text").children) do
					v.children[1].config.object:pop_out(4)
				end
			end
			return true
		end,
	}))
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 1.1,
		no_delete = true,
		blocking = false,
		timer = "REAL",
		func = function()
			if not G.screenwipe then return true end
			G.screenwipe.children.particles:remove()
			G.screenwipe:remove()
			G.screenwipe.children.particles = nil
			G.screenwipe = nil
			G.screenwipecard = nil
			return true
		end,
	}))
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 1.2,
		no_delete = true,
		blocking = true,
		timer = "REAL",
		func = function()
			return true
		end,
	}))
end

function G.FUNCS:continue_in_singleplayer(e)
	-- Detach from the multiplayer lobby (the API owns leave now; the legacy
	-- PVP.ACTIONS.leave_lobby() is a no-op here), then update UI. The run itself is kept
	-- and reloaded below so the player continues solo.
	PVP.LOBBY.code = nil
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		lobby:leave()
	end
	PVP.UI.update_connection_status()

	-- Resume from the in-memory save of this run. The save file is written a
	-- frame later and game over removes it, so it is never read back here.
	G.SETTINGS.current_setup = "Continue"
	G.FUNCS.wipe_on()
	-- A vanilla boss to stand in for the PvP blind, picked while the run is live.
	local fallback_boss
	for _, key in pairs(G.GAME.round_resets.blind_choices) do
		if key == "bl_mp_nemesis" then fallback_boss = get_new_boss(); break end
	end
	local snapshot = PVP.take_run_snapshot(G, save_run)
	-- The PvP blind (or the game over) counts as beaten: resume at the cash out.
	if snapshot then
		PVP.solo_resume_snapshot(snapshot, {
			states = G.STATES,
			nemesis_key = "bl_mp_nemesis",
			fallback_boss = fallback_boss,
			next_vouchers = SMODS.get_next_vouchers,
		})
	end
	G:delete_run()

	G.E_MANAGER:add_event(Event({
		trigger = "immediate",
		no_delete = true,
		func = function()
			G:start_run({ savetext = snapshot })
			return true
		end,
	}))
	G.FUNCS.wipe_off()
end

function G.FUNCS.attention_text_realtime(args)
	args = args or {}
	args.text = args.text or "test"
	args.scale = args.scale or 1
	args.colour = copy_table(args.colour or G.C.WHITE)
	args.hold = (args.hold or 0)
	args.pos = args.pos or { x = 0, y = 0 }
	args.align = args.align or "cm"
	args.emboss = args.emboss or nil

	args.fade = 1

	if args.cover then
		args.cover_colour = copy_table(args.cover_colour or G.C.RED)
		args.cover_colour_l = copy_table(lighten(args.cover_colour, 0.2))
		args.cover_colour_d = copy_table(darken(args.cover_colour, 0.2))
	else
		args.cover_colour = copy_table(G.C.CLEAR)
	end

	args.uibox_config = {
		align = args.align or "cm",
		offset = args.offset or { x = 0, y = 0 },
		major = args.cover or args.major or nil,
	}

	G.E_MANAGER:add_event(Event({
		trigger = "after",
		timer = "REAL",
		delay = 0,
		blockable = false,
		blocking = false,
		func = function()
			args.AT = UIBox({
				T = { args.pos.x, args.pos.y, 0, 0 },
				definition = {
					n = G.UIT.ROOT,
					config = {
						align = args.cover_align or "cm",
						minw = (args.cover and args.cover.T.w or 0.001) + (args.cover_padding or 0),
						minh = (args.cover and args.cover.T.h or 0.001) + (args.cover_padding or 0),
						padding = 0.03,
						r = 0.1,
						emboss = args.emboss,
						colour = args.cover_colour,
					},
					nodes = {
						{
							n = G.UIT.O,
							config = {
								draw_layer = 1,
								object = DynaText({
									scale = args.scale,
									string = args.text,
									maxw = args.maxw,
									colours = { args.colour },
									float = true,
									shadow = true,
									silent = not args.noisy,
									args.scale,
									pop_in = 0,
									pop_in_rate = 6,
									rotate = args.rotate or nil,
								}),
							},
						},
					},
				},
				config = args.uibox_config,
			})
			args.AT.attention_text = true

			args.text = args.AT.UIRoot.children[1].config.object
			args.text:pulse(0.5)

			if args.cover then
				Particles(args.pos.x, args.pos.y, 0, 0, {
					timer_type = "TOTAL",
					timer = 0.01,
					pulse_max = 15,
					max = 0,
					scale = 0.3,
					vel_variation = 0.2,
					padding = 0.1,
					fill = true,
					lifespan = 0.5,
					speed = 2.5,
					attach = args.AT.UIRoot,
					colours = { args.cover_colour, args.cover_colour_l, args.cover_colour_d },
				})
			end
			if args.backdrop_colour then
				args.backdrop_colour = copy_table(args.backdrop_colour)
				Particles(args.pos.x, args.pos.y, 0, 0, {
					timer_type = "TOTAL",
					timer = 5,
					scale = 2.4 * (args.backdrop_scale or 1),
					lifespan = 5,
					speed = 0,
					attach = args.AT,
					colours = { args.backdrop_colour },
				})
			end
			return true
		end,
	}))

	G.E_MANAGER:add_event(Event({
		trigger = "after",
		timer = "REAL",
		delay = args.hold,
		blockable = false,
		blocking = false,
		func = function()
			if not args.start_time then
				args.start_time = G.TIMERS.TOTAL
				args.text:pop_out(3)
			else
				args.fade = math.max(0, 1 - 3 * (G.TIMERS.TOTAL - args.start_time))
				if args.cover_colour then args.cover_colour[4] = math.min(args.cover_colour[4], 2 * args.fade) end
				if args.cover_colour_l then args.cover_colour_l[4] = math.min(args.cover_colour_l[4], args.fade) end
				if args.cover_colour_d then args.cover_colour_d[4] = math.min(args.cover_colour_d[4], args.fade) end
				if args.backdrop_colour then args.backdrop_colour[4] = math.min(args.backdrop_colour[4], args.fade) end
				args.colour[4] = math.min(args.colour[4], args.fade)
				if args.fade <= 0 then
					args.AT:remove()
					return true
				end
			end
		end,
	}))
end

function G.FUNCS.overlay_endgame_menu()
	G.FUNCS.overlay_menu({
		definition = PVP.GAME.won and create_UIBox_win() or create_UIBox_game_over(),
		config = { no_esc = true },
	})
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 2.5,
		blocking = false,
		func = function()
			if G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("jimbo_spot") then
				local Jimbo = Card_Character({ x = 0, y = 5 })
				local spot = G.OVERLAY_MENU:get_UIE_by_ID("jimbo_spot")
				spot.config.object:remove()
				spot.config.object = Jimbo
				Jimbo.ui_object_updated = true
				local jimbo_words = PVP.GAME.won and "wq_" .. math.random(1, 7) or "lq_" .. math.random(1, 10)
				Jimbo:add_speech_bubble(jimbo_words, nil, { quip = true })
				Jimbo:say_stuff(5)
			end
			return true
		end,
	}))
end

function PVP.UI.ease_lives(mod, instant)
	G.E_MANAGER:add_event(Event({
		trigger = "immediate",
        blockable = not instant,
		func = function()
			if not G.hand_text_area then return end

			if PVP.LOBBY.config.disable_live_and_timer_hud then
				return true -- Returning nothing hangs the game because it's a part of an event
			end

			local lives_UI = G.hand_text_area.ante
			if not lives_UI or not lives_UI.config.object then return true end

			mod = mod or 0
			local text = "+"
			local col = G.C.IMPORTANT
			if mod < 0 then
				text = "-"
				col = G.C.RED
			end
			lives_UI.config.object:update()
			G.HUD:recalculate()
			attention_text({
				text = text .. tostring(math.abs(mod)),
				scale = 1,
				hold = 0.7,
				cover = lives_UI.parent,
				cover_colour = col,
				align = "cm",
			})
			play_sound("highlight2", 0.685, 0.2)
			play_sound("generic1")
			return true
		end,
	}))
end

function PVP.UI.show_asteroid_hand_level_up()
	local hand_priority = {
		["Flush Five"] = 1,
		["Flush House"] = 2,
		["Five of a Kind"] = 3,
		["Straight Flush"] = 4,
		["Four of a Kind"] = 5,
		["Full House"] = 6,
		["Flush"] = 7,
		["Straight"] = 8,
		["Three of a Kind"] = 9,
		["Two Pair"] = 11,
		["Pair"] = 12,
		["High Card"] = 13,
	}
	local hand_type = "High Card"
	local max_level = 0

	for k, v in pairs(G.GAME.hands) do
		if SMODS.is_poker_hand_visible(k) then
			if hand_priority[k] == nil then
				hand_priority[k] = 0 -- Safeguard for modded hands
			end
			if
				to_big(v.level) > to_big(max_level)
				or (to_big(v.level) == to_big(max_level) and hand_priority[k] < hand_priority[hand_type])
			then
				hand_type = k
				max_level = v.level
			end
		end
	end
	SMODS.upgrade_poker_hands({ hands = hand_type, level_up = -1 })
end

--[[
function PVP.UI.create_UIBox_Misprint_Display()
	return {
		n = G.UIT.ROOT,
		config = { align = "cm", padding = 0.03, colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.05, colour = G.C.UI.TRANSPARENT_DARK, r = 0.1 },
				nodes = {
					{
						n = G.UIT.O,
						config = {
							id = "misprint_display",
							func = "misprint_display_set",
							object = DynaText({
								string = { { ref_table = PVP.GAME, ref_value = "misprint_display" } },
								colours = { G.C.UI.TEXT_LIGHT },
								shadow = true,
								float = true,
								scale = 0.5,
							}),
						},
					},
				},
			},
		},
	}
end

function G.FUNCS.misprint_display_set(e)
	local misprint_raw = (G.deck and G.deck.cards[1] and G.deck.cards[#G.deck.cards].base.id or 11)
		.. (G.deck and G.deck.cards[1] and G.deck.cards[#G.deck.cards].base.suit:sub(1, 1) or "D")
	if misprint_raw == e.config.last_misprint then
		return
	end
	e.config.last_misprint = misprint_raw

	local value = tonumber(misprint_raw:sub(1, -2))
	local suit = misprint_raw:sub(-1)

	local suit_full = { H = "Hearts", D = "Diamonds", C = "Clubs", S = "Spades" }

	local value_key = tostring(value)
	if value == 14 then
		value_key = "Ace"
	elseif value == 11 then
		value_key = "Jack"
	elseif value == 12 then
		value_key = "Queen"
	elseif value == 13 then
		value_key = "King"
	end

	local localized_card = {}

	localize({
		type = "other",
		key = "playing_card",
		set = "Other",
		nodes = localized_card,
		vars = {
			localize(value_key, "ranks"),
			localize(suit_full[suit], "suits_plural"),
			colours = { G.C.UI.TEXT_LIGHT },
		},
	})

	-- Yes I know this is stupid
	PVP.GAME.misprint_display = localized_card[1][2].config.text .. localized_card[1][3].config.text
	e.config.object.colours = { G.C.SUITS[suit_full[suit]]
--}
--end
--]]
