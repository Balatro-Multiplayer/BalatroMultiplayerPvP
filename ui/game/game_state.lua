-- Contains function overrides (monkey-patches) for game state management
-- Overrides Game methods like update_draw_to_hand, update_hand_played, update_new_round, etc.

local update_draw_to_hand_ref = Game.update_draw_to_hand
function Game:update_draw_to_hand(dt)
	if PVP.is_mp_or_practice() then
		if
			not G.STATE_COMPLETE
			and G.GAME.current_round.hands_played == 0
			and G.GAME.current_round.discards_used == 0
			and G.GAME.facing_blind
		then
			if PVP.is_pvp_boss() then
				PVP.GAME.pincher_unlock = true
				G.after_pvp = true -- i can't find a reasonable way to detect end of pvp (for pizza) so i'm doing something strange instead

				if PVP.GAME.asteroids > 0 then -- launch asteroids, messy event garbage
					delay(0.8)
					update_hand_text({ sound = "button", volume = 0.7, pitch = 0.8, delay = 0.3 }, {
						handname = localize("k_asteroids"),
						chips = localize("k_amount_short"),
						mult = PVP.GAME.asteroids,
					})
					delay(0.6)
					local send = 0
					for i = 1, PVP.GAME.asteroids do
						local perc = PVP.GAME.asteroids - send
						G.E_MANAGER:add_event(Event({
							func = function()
								play_sound("tarot1", 0.9 + (perc / 10), 1)
								return true
							end,
						}))
						send = send + 1
						update_hand_text({ delay = 0 }, { mult = PVP.GAME.asteroids - send })
						delay(0.2)
					end
					G.E_MANAGER:add_event(Event({
						func = function()
							for i = 1, PVP.GAME.asteroids do
								PVP.broadcast_asteroid()
							end
							PVP.GAME.asteroids = 0
							return true
						end,
					}))
					delay(0.7)
					update_hand_text(
						{ sound = "button", volume = 0.7, pitch = 1.1, delay = 0 },
						{ mult = 0, chips = 0, handname = "", level = "" }
					)
				end
			end
		end
	end
	update_draw_to_hand_ref(self, dt)
end

-- Set blind PvP state appropriately (moved from previous hook to be earlier)
local blind_set_blindref = Blind.set_blind
function Blind:set_blind(blind, reset, silent)
	blind_set_blindref(self, blind, reset, silent)
	if G.GAME.round_resets and G.GAME.round_resets.pvp_blind_choices then 
		G.GAME.blind.pvp = G.GAME.round_resets.pvp_blind_choices[G.GAME.blind_on_deck]
	end
end

local function eval_hand_and_jokers()
	for i = 1, #G.hand.cards do
		--Check for hand doubling
		local reps = { 1 }
		local j = 1
		while j <= #reps do
			local percent = (i - 0.999) / (#G.hand.cards - 0.998) + (j - 1) * 0.1
			if reps[j] ~= 1 then
				card_eval_status_text(
					(reps[j].jokers or reps[j].seals).card,
					"jokers",
					nil,
					nil,
					nil,
					(reps[j].jokers or reps[j].seals)
				)
			end

			--calculate the hand effects
			local effects = { G.hand.cards[i]:get_end_of_round_effect() }
			for k = 1, #G.jokers.cards do
				--calculate the joker individual card effects
				local eval = G.jokers.cards[k]:calculate_joker({
					cardarea = G.hand,
					other_card = G.hand.cards[i],
					individual = true,
					end_of_round = true,
				})
				if eval then table.insert(effects, eval) end
			end

			if reps[j] == 1 then
				--Check for hand doubling
				--From Red seal
				local eval = eval_card(
					G.hand.cards[i],
					{ end_of_round = true, cardarea = G.hand, repetition = true, repetition_only = true }
				)
				if next(eval) and (next(effects[1]) or #effects > 1) then
					for h = 1, eval.seals.repetitions do
						reps[#reps + 1] = eval
					end
				end

				--from Jokers
				for j = 1, #G.jokers.cards do
					--calculate the joker effects
					local eval = eval_card(G.jokers.cards[j], {
						cardarea = G.hand,
						other_card = G.hand.cards[i],
						repetition = true,
						end_of_round = true,
						card_effects = effects,
					})
					if next(eval) then
						for h = 1, eval.jokers.repetitions do
							reps[#reps + 1] = eval
						end
					end
				end
			end

			for ii = 1, #effects do
				--if this effect came from a joker
				if effects[ii].card then
					G.E_MANAGER:add_event(Event({
						trigger = "immediate",
						func = function()
							effects[ii].card:juice_up(0.7)
							return true
						end,
					}))
				end

				--If dollars
				if effects[ii].h_dollars then
					ease_dollars(effects[ii].h_dollars)
					card_eval_status_text(G.hand.cards[i], "dollars", effects[ii].h_dollars, percent)
				end

				--Any extras
				if effects[ii].extra then
					card_eval_status_text(G.hand.cards[i], "extra", nil, percent, nil, effects[ii].extra)
				end
			end
			j = j + 1
		end
	end
end

local update_hand_played_ref = Game.update_hand_played
---@diagnostic disable-next-line: duplicate-set-field
function Game:update_hand_played(dt)
	-- Ignore for singleplayer or regular blinds
	local practice = PVP.is_practice_mode()
	if (not practice and (not PVP.LOBBY.connected or not PVP.LOBBY.code)) or not PVP.is_pvp_boss() then
		update_hand_played_ref(self, dt)
		return
	end

	if self.buttons then
		self.buttons:remove()
		self.buttons = nil
	end
	if self.shop then
		self.shop:remove()
		self.shop = nil
	end

	if not G.STATE_COMPLETE then
		G.STATE_COMPLETE = true
		G.E_MANAGER:add_event(Event({
			trigger = "immediate",
			func = function()
				if not practice then
					PVP.ACTIONS.play_hand(G.GAME.chips, G.GAME.current_round.hands_left)
				end

				if G.GAME.current_round.hands_left < 1 then
					if practice then
						-- No referee to wait on -- always continue to the next blind,
						-- regardless of score (see update_new_round's practice branch).
						PVP.GAME.end_pvp = true
					else
						attention_text({
							scale = 0.8,
							text = localize("k_wait_enemy"),
							hold = 5,
							align = "cm",
							offset = { x = 0, y = -1.5 },
							major = G.play,
						})
					end
					if G.hand.cards[1] and G.STATE == G.STATES.HAND_PLAYED then
						eval_hand_and_jokers()
						G.FUNCS.draw_from_hand_to_discard()
					end
				elseif not PVP.GAME.end_pvp and G.STATE == G.STATES.HAND_PLAYED then
					G.STATE_COMPLETE = false
					G.STATE = G.STATES.DRAW_TO_HAND
				end
				return true
			end,
		}))
	end

	if PVP.GAME.end_pvp and PVP.is_pvp_boss() and not (G.GAME.STOP_USE and G.GAME.STOP_USE > 0) then
		G.STATE_COMPLETE = false
		G.STATE = G.STATES.NEW_ROUND
		PVP.GAME.end_pvp = false
	end
end

local update_new_round_ref = Game.update_new_round
function Game:update_new_round(dt)
	if PVP.GAME.end_pvp then
		if G.STATE ~= G.STATES.NEW_ROUND then
			G.FUNCS.draw_from_hand_to_deck()
			G.FUNCS.draw_from_discard_to_deck()
		end
		G.STATE = G.STATES.NEW_ROUND
		PVP.GAME.end_pvp = false
	end
	if PVP.is_mp_or_practice() and not G.STATE_COMPLETE then
		local practice = PVP.is_practice_mode()
		-- Prevent player from losing
		if to_big(G.GAME.chips) < to_big(G.GAME.blind.chips) and not PVP.is_pvp_boss() then
			G.GAME.blind.chips = -1
			if practice then
				-- Just score as much as you can -- no life, no fail, ever.
			else
				PVP.ACTIONS.fail_round(G.GAME.current_round.hands_played)
			end
		elseif not practice and not PVP.is_pvp_boss() then
			PVP.ACTIONS.blind_result(true)
		end

		if practice then
			-- Just let this state's own transition run (no win_ante=999 suppression to
			-- undo afterward) -- the ante-8 stop itself is forced explicitly from
			-- ease_ante (ui/game/round.lua), not here; see that override's comment for why.
			update_new_round_ref(self, dt)
			return
		end

		-- Prevent player from winning
		G.GAME.win_ante = 999

		update_new_round_ref(self, dt)

		-- Reset ante number
		G.GAME.win_ante = 8
		return
	end
	update_new_round_ref(self, dt)
end

local update_selecting_hand_ref = Game.update_selecting_hand
function Game:update_selecting_hand(dt)
	-- Out of cards with hands left. On a PvP blind this always counts as playing the
	-- last hand (even with extra hands, e.g. Burglar, or before any hand was played),
	-- so the referee gets 0 hands left instead of the player leaving through end_round.
	if
		#G.hand.cards < 1
		and #G.deck.cards < 1
		and #G.play.cards < 1
		and PVP.is_mp_or_practice()
		and (PVP.is_pvp_boss() or G.GAME.current_round.hands_left < G.GAME.round_resets.hands)
	then
		G.GAME.current_round.hands_left = 0
		if not PVP.is_pvp_boss() then
			G.STATE_COMPLETE = false
			G.STATE = G.STATES.NEW_ROUND
		else
			if not PVP.is_practice_mode() then
				PVP.ACTIONS.play_hand(G.GAME.chips, 0)
			end
			G.STATE_COMPLETE = false
			G.STATE = G.STATES.HAND_PLAYED
		end
		return
	end
	update_selecting_hand_ref(self, dt)

	if PVP.GAME.end_pvp and PVP.is_pvp_boss() and PVP.is_mp_or_practice() then
		G.hand:unhighlight_all()
		G.STATE_COMPLETE = false
		G.STATE = G.STATES.NEW_ROUND
		PVP.GAME.end_pvp = false
	end
end

-- Consolidate both update_shop overrides
local update_shop_ref = Game.update_shop
function Game:update_shop(dt)
	if not G.STATE_COMPLETE then
		PVP.GAME.ready_blind = false
		PVP.GAME.ready_blind_text = localize("b_ready")
		PVP.GAME.end_pvp = false
	end

	local updated_location = false
	if PVP.LOBBY.code and not G.STATE_COMPLETE and not updated_location and not G.GAME.USING_RUN then
		updated_location = true
		PVP.ACTIONS.set_location("loc_shop")
		PVP.GAME.spent_before_shop = to_big(PVP.GAME.spent_total) + to_big(0)
		if PVP.UI.show_enemy_location then PVP.UI.show_enemy_location() end
	end
	if G.STATE_COMPLETE and updated_location then updated_location = false end
	update_shop_ref(self, dt)
end

local update_blind_select_ref = Game.update_blind_select
function Game:update_blind_select(dt)
	local updated_location = false
	if PVP.LOBBY.code and not G.STATE_COMPLETE and not updated_location then
		updated_location = true
		PVP.ACTIONS.set_location("loc_selecting")
		if PVP.UI.show_enemy_location then PVP.UI.show_enemy_location() end
	end
	if G.STATE_COMPLETE and updated_location then updated_location = false end
	update_blind_select_ref(self, dt)
end

-- Whether the centers still carry the reworks of the last PvP session's run.
local session_reworks_loaded = false

-- Reworks go on before the run body makes its cards (MPAPI's own pass runs
-- after it). Outside a PvP session MPAPI alone owns them; a session's
-- leftovers come off first so this run's cards aren't made from them.
local function load_run_reworks()
	if PVP.in_session() then
		PVP.LoadReworks(PVP.get_active_ruleset())
		session_reworks_loaded = true
	elseif session_reworks_loaded then
		PVP.LoadReworks(nil)
		session_reworks_loaded = false
	end
end

local start_run_ref = Game.start_run
function Game:start_run(args)
	load_run_reworks()
	-- prevent_eval only ever spans one PvP round; a run starts without it.
	PVP.GAME.prevent_eval = nil

	start_run_ref(self, args)

	-- Not extended to practice: this UIBox-rebuild is only ever needed to show
	-- lives (practice has no life system, see update_new_round's practice branch) and
	-- doing it synchronously at run start raced with other HUD setup in local-lobby
	-- testing (no risk in a real lobby, which has natural network pacing beforehand).
	PVP.UI.apply_lives_hud()
end

local function lobby_hud_shown()
	return PVP.LOBBY.connected and PVP.LOBBY.code and not PVP.LOBBY.config.disable_live_and_timer_hud
end

-- The run HUD gets its Timer box (lovely/hud.toml) only when it is built
-- inside a lobby. A crash-rejoin rebuilds the run with no lobby and joins it
-- afterwards, so the box is put in then, in place of the Round box.
function PVP.UI.apply_timer_hud()
	if not (G.HUD and lobby_hud_shown()) or G.HUD:get_UIE_by_ID("timer_UI_count") then
		return
	end
	local definition = PVP.UI.timer_hud()
	local hud_ante = G.HUD:get_UIE_by_ID("hud_ante")
	local row = hud_ante and hud_ante.parent
	if not (definition and row and #row.children >= 3) then
		return
	end
	-- The Round box is the row's last child (Ante box, spacer, Round box).
	local round_box = row.children[#row.children]
	round_box:remove()
	row.children[#row.children] = nil
	G.HUD:add_child(definition, row)
	if G.hand_text_area then
		G.hand_text_area.round = nil
	end
end

-- Lobby-only HUD pieces, for a run that was built before its lobby was joined.
function PVP.UI.apply_lobby_hud()
	PVP.UI.apply_timer_hud()
	PVP.UI.apply_lives_hud()
end

-- The opponent lives in the Lives box (PVP.shown_opponent_lives). Read through
-- __index so the text node reads it again every frame.
local hud_opponent_lives = setmetatable({}, {
	__index = function()
		local lobby = MPAPI.get_current_lobby()
		local player_ids = {}
		for _, p in ipairs(lobby and lobby:get_players() or {}) do
			player_ids[#player_ids + 1] = p.id
		end
		return PVP.shown_opponent_lives({
			ref_players = PVP.REF and PVP.REF.players,
			self_id = PVP.self_player_id(),
			own_lives = PVP.GAME and PVP.GAME.lives,
			cache = PVP._player_lives_cache,
			starting_lives = PVP.LOBBY.config.starting_lives,
			player_ids = player_ids,
			nemesis_id = PVP.LOBBY.config.nemesis_pairing and PVP.GAME.nemesis_partner_id or nil,
		})
	end,
})

-- Turns the Ante box into the Lives box: your lives "vs" the opponent's. Reads
-- PVP.GAME by reference, so it is built again whenever PVP.GAME is replaced
-- (PVP.reset_game_states).
function PVP.UI.apply_lives_hud()
	if not (G.HUD and lobby_hud_shown()) then return end

	local scale = 0.4
	local hud_ante = G.HUD:get_UIE_by_ID("hud_ante")
	if not hud_ante then return end
	hud_ante.children[1].children[1].config.text = localize("k_lives")

	-- Set lives number
    local lives_container = hud_ante.children[2].children[1]
    if  lives_container.config.object then
        lives_container.config.object:remove()
    end
    lives_container.config.object = UIBox({
        definition = {
            n = G.UIT.ROOT,
            config = { colour = G.C.CLEAR },
            nodes = {
                {
                    n = G.UIT.R,
                    config = { align = "cm", minw = 1.2, maxw = 1.2, minh = 0.664 },
                    nodes = {
                        {
                            n = G.UIT.T,
                            config = {
                                ref_table = PVP.GAME,
                                ref_value = "lives",
                                scale = 2 * scale * 0.8,
                                colour = G.C.IMPORTANT,
                                shadow = true,
                                maxw = 0.5,
                            }
                        },
                        { n = G.UIT.B, config = { w = 0.05, h = 0.05 } },
                        {
                            n = G.UIT.T,
                            config = {
                                text = "vs", -- not localized intentionally
                                scale = scale * 0.8,
                                colour = G.C.UI.TEXT_DARK,
                                shadow = true,
                            }
                        },
                        { n = G.UIT.B, config = { w = 0.05, h = 0.05 } },
                        {
                            n = G.UIT.T,
                            config = {
                                ref_table = hud_opponent_lives,
                                ref_value = "lives",
                                scale = 2 * scale * 0.8,
                                colour = G.C.RED,
                                shadow = true,
                                maxw = 0.5,
                            }
                        },
                    }
                }
            }
        },
        config = {},
    })

	-- Remove unnecessary HUD elements from ante counter
	hud_ante.children[2].children[2] = nil
	hud_ante.children[2].children[3] = nil
	hud_ante.children[2].children[4] = nil

	G.HUD:recalculate()
end

-- This prevents duplicate execution during certain cases. e.g. Full deck discard before playing any hands.
function PVP.handle_duplicate_end()
	if PVP.is_mp_or_practice() then
		if PVP.GAME.round_ended then
			if not PVP.GAME.duplicate_end then
				PVP.GAME.duplicate_end = true
				sendDebugMessage("Duplicate end_round calls prevented.", "MULTIPLAYER")
			end
			return true
		end
	end
	return false
end

-- This handles an edge case where a player plays no hands, and discards the only cards in their deck:
-- on a non-PvP blind it fails the round. A PvP blind already finished through
-- update_selecting_hand's out-of-cards check, with a score of 0.
function PVP.handle_deck_out()
	if PVP.is_mp_or_practice() and not PVP.is_pvp_boss() then
		if
			G.GAME.current_round.hands_played == 0
			and G.GAME.current_round.discards_used > 0
		then
			PVP.ACTIONS.fail_round(1)
		end
	end
end

local mp_jimbo = nil
local mp_jimbo_pos = nil

local JIMBO_POSITIONS = {
	[1] = { align = "cri", offset = { x = 1, y = 0 }, bubble_align = "cl", bubble_offset = { x = 0, y = 0 } },
	[2] = { align = "tli", offset = { x = -0.75, y = -0.75 }, bubble_align = "cr", bubble_offset = { x = 0, y = -0.5 } },
	[3] = { align = "tri", offset = { x = 1.8, y = -0.1 }, bubble_align = "bl", bubble_offset = { x = 2.1, y = 0 } },
	[4] = { align = "cmi", offset = { x = 0, y = -1.5 }, bubble_align = "cr", bubble_offset = { x = 0, y = 0 } },
}

function PVP.UI.create_jimbo(pos, text)
	if mp_jimbo then PVP.UI.remove_jimbo() end
	local p = JIMBO_POSITIONS[pos] or JIMBO_POSITIONS[1]
	mp_jimbo_pos = pos or 1
	mp_jimbo = Card_Character({
		x = 0,
		y = G.ROOM.T.h + 5,
		center = "j_perkeo",
		particle_colours = { HEX("4e997b"), HEX("e9564e"), HEX("ebecee") },
	})
	mp_jimbo.children.particles:remove()
	mp_jimbo.children.particles = nil
	mp_jimbo.children.card:set_edition({ negative = true }, true, true)
	mp_jimbo.say_stuff = function(self, n, not_first)
		self.talking = true
		if not not_first then
			G.E_MANAGER:add_event(Event({
				trigger = "after",
				timer = "REAL",
				delay = 0.1,
				func = function()
					if self.children.speech_bubble then self.children.speech_bubble.states.visible = true end
					self:say_stuff(n, true)
					return true
				end,
			}))
		else
			if n <= 0 then
				self.talking = false
				return
			end
			play_sound("voice" .. math.random(1, 11), math.random() * 0.2 + 1, 0.5)
			self.children.card:juice_up()
			G.E_MANAGER:add_event(
				Event({
					trigger = "after",
					timer = "REAL",
					blockable = false,
					blocking = false,
					delay = 0.13,
					func = function()
						self:say_stuff(n - 1, true)
						return true
					end,
				}),
				"tutorial"
			)
		end
	end
	mp_jimbo:set_alignment({
		major = G.ROOM_ATTACH,
		type = p.align,
		offset = p.offset,
	})
	if text then PVP.UI.jimbo_say(text) end
	return mp_jimbo
end

function PVP.UI.move_jimbo(pos)
	if not mp_jimbo then return end
	local p = JIMBO_POSITIONS[pos] or JIMBO_POSITIONS[1]
	mp_jimbo_pos = pos or 1
	mp_jimbo:set_alignment({
		major = G.ROOM_ATTACH,
		type = p.align,
		offset = p.offset,
	})
	if mp_jimbo.children.speech_bubble then
		mp_jimbo.children.speech_bubble.alignment.type = p.bubble_align
		mp_jimbo.children.speech_bubble.alignment.offset = p.bubble_offset
		mp_jimbo.children.speech_bubble:align_to_major()
	end
end

function PVP.UI.jimbo_say(text)
	if not mp_jimbo then return end
	if mp_jimbo.children.speech_bubble then mp_jimbo.children.speech_bubble:remove() end
	local lines = {}
	for line in PVP.UTILS.wrapText(text, 30):gmatch("[^\n]+") do
		lines[#lines + 1] = line:match("^%s*(.-)%s*$")
	end
	local rows = {}
	for _, line in ipairs(lines) do
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cl" },
			nodes = {
				{ n = G.UIT.T, config = { text = line, scale = 0.4, colour = G.C.UI.TEXT_DARK } },
			},
		}
	end
	local definition = {
		n = G.UIT.ROOT,
		config = { align = "cm", minh = 1, r = 0.3, padding = 0.07, minw = 1, colour = G.C.JOKER_GREY, shadow = true },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", minh = 1, r = 0.2, padding = 0.1, minw = 1, colour = G.C.WHITE },
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm", minh = 1, r = 0.2, padding = 0.03, minw = 1, colour = G.C.WHITE },
						nodes = rows,
					},
				},
			},
		},
	}
	local p = JIMBO_POSITIONS[mp_jimbo_pos] or JIMBO_POSITIONS[1]
	mp_jimbo.children.speech_bubble = UIBox({
		definition = definition,
		config = { align = p.bubble_align, offset = p.bubble_offset, parent = mp_jimbo },
	})
	mp_jimbo.children.speech_bubble:set_role({
		role_type = "Minor",
		xy_bond = "Weak",
		r_bond = "Strong",
		major = mp_jimbo,
	})
	mp_jimbo.children.speech_bubble.states.visible = true
	local word_count = select(2, text:gsub("%S+", ""))
	local read_time = math.max(5, word_count * 0.3 + 1) + 5
	mp_jimbo:say_stuff(math.ceil(word_count / 2))
	local bubble_ref = mp_jimbo.children.speech_bubble
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		timer = "REAL",
		blockable = false,
		blocking = false,
		delay = read_time,
		func = function()
			if mp_jimbo and mp_jimbo.children.speech_bubble == bubble_ref then
				mp_jimbo.children.speech_bubble:remove()
				mp_jimbo.children.speech_bubble = nil
			end
			return true
		end,
	}))
end

function PVP.UI.remove_jimbo()
	if not mp_jimbo then return end
	local jimbo = mp_jimbo
	mp_jimbo = nil
	if jimbo.children.speech_bubble then
		jimbo.children.speech_bubble:remove()
		jimbo.children.speech_bubble = nil
	end
	if jimbo.children.button then
		jimbo.children.button:remove()
		jimbo.children.button = nil
	end
	jimbo.children.card:start_dissolve({ HEX("4e997b") }, nil, nil, true)
	if jimbo.children.particles then jimbo.children.particles:fade(0.5) end
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		blockable = false,
		delay = 0.8,
		func = function()
			jimbo:remove()
			return true
		end,
	}))
end
