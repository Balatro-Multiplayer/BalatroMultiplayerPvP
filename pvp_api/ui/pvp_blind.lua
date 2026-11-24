-- The PvP blind on the match net: Play and a scored hand are sent as inputs; the blind's state, the
-- result, lives and the opponent's side are read back from the view (pvp_api/read/pvp_blind.lua decides). A
-- blind that already has a blind (after a load or a restart) takes its hands and score from the view.
local screen = {}
PVP.UI.pvp_blind = screen

local function net()
	return PVP.NET
end

local function warn(text)
	sendWarnMessage("[pvp_blind] " .. text, "MULTIPLAYER")
end

local function in_real_blind()
	return PVP.LOBBY.in_session() and not PVP.PRACTICE.is_on() and PVP.UTILS.is_pvp_blind()
end

local function blind_key()
	return PVP.READ.view.pvp_blind_key(G.GAME.round_resets.ante)
end

-- Run id and blind key of the blind the game is in; nil without a run.
local function key_now()
	local run_id = G.GAME and G.GAME.pvp_net and G.GAME.pvp_net.runId
	return run_id and PVP.READ.view.entry_key(run_id, blind_key()) or nil
end

-- Play is refused once the view says my blind is over, while the blind still waits for its hands and
-- before its blindStart went out.
function screen.may_play()
	if not in_real_blind() then return true end
	local reader, source = PVP.READ.pvp_blind, PVP.GAME.hands_source
	if reader.blind_start_waiting(source, key_now()) then return false end
	return not reader.hands_from_server_waiting(source, key_now()) and reader.may_play(net().view, blind_key())
end

-- The body of the handPlayed this Play press sends, or nil.
function screen.play_body()
	if not in_real_blind() then return nil end
	return PVP.READ.pvp_blind.hand_played({
		blind_key = blind_key(),
		hands_left = G.GAME.current_round.hands_left,
		highlighted = #G.hand.highlighted,
		selecting_hand = G.STATE == G.STATES.SELECTING_HAND and not (G.play and G.play.cards[1]),
	})
end

function screen.send_hand_played(body)
	if body and not net().send("handPlayed", body) then warn("handPlayed was not sent") end
end

-- The hand has finished scoring: the score and the hands left now.
function screen.hand_scored(score, hands_left)
	if not in_real_blind() then return end
	local body = { blindKey = blind_key(), handsLeft = hands_left, score = score }
	if not net().send("handScored", body) then warn("handScored was not sent") end
end

-- A hand was gained inside a PvP blind (ease_hands_played with a positive change): the server's
-- hands left follow it, with the score as it stands. Before my first hand, blindStart or the first
-- handScored carries the hands, and an early handScored would mark me as having played.
function screen.hands_gained(change)
	if change > 0 and PVP.UTILS.is_pvp_blind() and G.GAME.current_round.hands_played > 0 then
		screen.hand_scored(PVP.SCORE.from_game_value(G.GAME.chips), G.GAME.current_round.hands_left)
	end
end

-- True once applied; false, with nothing changed, while the HUD is not built (asked again next frame).
local function set_hands_from_view(change)
	if change.hands_left ~= G.GAME.current_round.hands_left then
		local hands = G.HUD and G.HUD:get_UIE_by_ID("hand_UI_count")
		if not hands then return false end
		G.GAME.current_round.hands_left = change.hands_left
		hands.config.object:update()
		G.HUD:recalculate()
	end
	local chips, why = PVP.SCORE.to_game_value(change.score)
	if chips == nil then
		warn("the score " .. tostring(change.score) .. " cannot be shown: " .. tostring(why))
	else
		G.GAME.chips = chips
		G.GAME.chips_text = number_format(chips)
	end
	PVP.GAME.score = change.score
	return true
end

local function show_opponent(view)
	local reader, shown = PVP.READ.pvp_blind, PVP.READ.view
	local opponent = reader.opponent_now(view, blind_key())
	local ready = reader.ready_look(opponent)
	if shown.changed("pvp_blind opponent ready", ready) and (opponent == nil or opponent.waiting) and not PVP.RULES.current().enemy_location_disabled then
		PVP.UI.match.show_enemy_location(ready and "loc_ready" or "loc_selecting")
	end
	if shown.changed("pvp_blind opponent blind", shown.entry_key(view.match.run.id, blind_key())) then shown.forget("pvp_blind opponent shown ") end
	if not opponent or opponent.waiting then return end
	local hands = opponent.hands ~= nil and shown.changed("pvp_blind opponent shown hands", opponent.hands)
	local score = opponent.score ~= nil and shown.changed("pvp_blind opponent shown score", opponent.score)
	if not (hands or score) then return end
	if hands then PVP.GAME.enemy.hands = opponent.hands end
	if score then
		PVP.UI.ease_enemy_score(opponent.score)
		PVP.GAME.enemy.real_score = opponent.score
		if PVP.SCORE.greater(opponent.score, PVP.GAME.enemy.highest_score) then PVP.GAME.enemy.highest_score = opponent.score end
	end
	PVP.GAME.enemy.info_received = true
	if PVP.UI.juice_up_pvp_hud then PVP.UI.juice_up_pvp_hud() end
end

local function show_lives(view)
	local change = PVP.READ.pvp_blind.lives_change(PVP.GAME.lives, view)
	if not change then return end
	if change.show then
		PVP.UI.match.show_lives(change.lives)
	else
		PVP.GAME.lives = change.lives
	end
end

function screen.update()
	local live = net().view
	local view = PVP.READ.view.game(live)
	local pvp_net = G.GAME and G.GAME.pvp_net
	local reader = PVP.READ.pvp_blind
	if not pvp_net then
		PVP.GAME.hands_source = { kind = "game" }
	elseif G.GAME.round_resets then
		local source, now = PVP.GAME.hands_source, key_now()
		if source.kind == "blind start due" and source.key ~= now then
			warn("the blindStart of " .. tostring(source.key) .. " was dropped, the game is at " .. tostring(now))
		end
		PVP.GAME.hands_source = reader.hands_source_at(source, now)
	end
	if not (PVP.READ.view.run(view) and pvp_net and G.STAGE == G.STAGES.RUN and PVP.LOBBY.in_session()) then return end
	if PVP.PRACTICE.is_on() then return end
	show_lives(view)
	if G.STATE == G.STATES.BLIND_SELECT or PVP.UTILS.is_pvp_blind() then show_opponent(view) end
	-- An ended game is only shown; it takes no inputs.
	if view ~= live or not PVP.UTILS.is_pvp_blind() then return end
	local picking_hand = G.STATE == G.STATES.SELECTING_HAND and G.STATE_COMPLETE
	local game = {
		blind_key = blind_key(),
		inbox_done = pvp_net.inboxDone,
		key = key_now(),
		selecting_hand = picking_hand,
		hands_left = G.GAME.current_round.hands_left,
		score = picking_hand and PVP.SCORE.from_game_value(G.GAME.chips) or nil,
	}
	local body = reader.blind_start(PVP.GAME.hands_source, game)
	if body and net().send("blindStart", body) then
		PVP.GAME.hands_source = reader.hands_source_done(PVP.GAME.hands_source, "blind start sent")
	end
	if picking_hand and reader.hands_from_server_waiting(PVP.GAME.hands_source, game.key) then
		local change = reader.hands_after_load(view, game)
		local settled = change.kind == "nothing to set" or (change.kind == "set hands" and set_hands_from_view(change))
		if settled then PVP.GAME.hands_source = reader.hands_source_done(PVP.GAME.hands_source, "hands settled") end
	end
	local result_key, result = reader.result_of(view, game)
	if result and PVP.READ.view.changed("pvp_blind result", result_key) then
		PVP.GAME.hands_source = reader.hands_source_done(PVP.GAME.hands_source, "result shown")
		PVP.UI.match.end_pvp_blind(result.lost, result.timer_lost)
	end
	local timer_key = reader.timer_out(view, game)
	if timer_key and PVP.READ.view.changed("pvp_blind timer out", timer_key) then
		attention_text({
			scale = 0.8,
			text = localize("k_pvp_timer_out"),
			hold = 5,
			align = "cm",
			offset = { x = 0, y = -1.5 },
			major = G.play,
		})
	end
end


return screen
