-- What the match screens do to the game when the view says so: start the run, enter and end the PvP
-- blind, show lives, the opponent's location and the end screens.
local effects = {}
PVP.UI.match = effects

function effects.start_game(seed, stake)
	PVP.match_log("debug", string.format("Game starting — %s", os.date("%Y-%m-%dT%H:%M:%S%z")))
	-- Clear any stale practice state so it can't leak into real PVP
	PVP.PRACTICE.practice = false
	PVP.PRACTICE.playback_gamemode = nil

	PVP.LOBBY.reset_game()
	-- Snapshot who started this match: the end screen lists them even after they leave.
	local start_lobby = MPAPI.get_current_lobby()
	PVP.LOBBY.match_players = PVP.MATCH_PLAYERS.snapshot(start_lobby and start_lobby:get_players())
	PVP.GAME.run_started_at = love.timer.getTime()
	stake = tonumber(stake)
	PVP.ACTIONS.set_ante(0)
	if PVP.LOBBY.config.different_seeds then
		-- Every player rolls their own seed instead of sharing the server's.
		seed = generate_starting_seed()
	elseif PVP.LOBBY.config.custom_seed ~= "random" then
		seed = PVP.LOBBY.config.custom_seed
	end

	-- One replay-log block per match. lobby_config, version, hash, challenge and sleeve ride inside
	-- lobby_info's `options`: match_manifest's own shape is fixed across mods.
	PVP.REPLAY.log.begin_run()
	MPAPI.RLOGCodes.match_manifest:write()
	do
		local players = { { id = PVP.LOBBY.host.id, is_host = true } }
		if PVP.LOBBY.guest and PVP.LOBBY.guest.id then
			players[#players + 1] = { id = PVP.LOBBY.guest.id, is_host = false }
		end
		MPAPI.RLOGCodes.lobby_info:write(PVP.LOBBY.config.gamemode, PVP.LOBBY.config.ruleset, players, {
			PVP.LOBBY.config.back,
		}, {
			sleeve = PVP.LOBBY.config.sleeve,
			challenge = PVP.LOBBY.config.challenge,
			modifier_layers = PVP.LOBBY.config.modifier_layers,
			the_order_enabled = PVP.RULES.use_the_order(),
			different_seeds = PVP.LOBBY.config.different_seeds,
			mod_version = PVP and PVP.version,
			mod_hash = PVP.QUEUE.mod_string,
			smods_version = SMODS.version,
			lovely_version = PVP.MIN_LOVELY_VERSION,
		})
	end
	MPAPI.RLOGCodes.run_info:write(seed, PVP.LOBBY.config.back, stake)

	G.FUNCS.lobby_start_run(nil, { seed = seed, stake = stake })
	PVP.LOBBY.ready_to_start = false
end

-- True once select_blind has run.
local function begin_pvp_blind()
	local button = PVP.GAME.next_blind_context or PVP.UI.boss_select_button()
	if not button then
		sendErrorMessage("The blind select has no blind button", "MULTIPLAYER")
		return false
	end
	G.FUNCS.select_blind(button)
	return true
end

-- on_selected runs once select_blind ran; on_missed when no button was left to press.
function effects.start_pvp_blind(on_selected, on_missed)
	-- Reset the stored opponent score each blind so the first frame after we
	-- play (which lifts the "???" mask) shows 0, not last blind's stale score.
	PVP.GAME.enemy.score = PVP.SCORE.ZERO
	PVP.GAME.enemy.score_ease = nil
	PVP.GAME.enemy.real_score = PVP.SCORE.ZERO
	PVP.GAME.enemy.score_text = PVP.SCORE.ZERO
	-- Re-mask the opponent's score until the first enemyInfo of the new blind.
	PVP.GAME.enemy.info_received = false
	-- Unknown (shown as k_pvp_hands_unknown) until the view has the opponent's hands.
	PVP.GAME.enemy.hands = nil
	if PVP.UI.refresh_enemy_score_label then
		PVP.UI.refresh_enemy_score_label()
	end
	if PVP.LOBBY.current then PVP.LOBBY.mirror_players(PVP.LOBBY.current) end
	PVP.GAME.ready_blind = false
	PVP.UI.start_pvp_countdown(function()
		if begin_pvp_blind() then
			if on_selected then on_selected() end
		elseif on_missed then
			on_missed()
		end
	end)
end

function effects.end_pvp_blind(lost, timer_lost)
	if lost and timer_lost then
		if G.GAME.current_round.hands_left > 0 then
			stop_use()
			SMODS.calculate_context({ mp_pvp_loss = true, mp_hands_left = G.GAME.current_round.hands_left })
		end
	end
	PVP.GAME.end_pvp = true
	PVP.GAME.ready_blind = false
	PVP.GAME.score = nil
end

function effects.show_lives(lives)
	if PVP.GAME.lives ~= lives then
		PVP.UI.ease_lives(lives - PVP.GAME.lives, true)
		if PVP.LOBBY.config.no_gold_on_pvp_loss and (G.GAME.blind and G.GAME.blind.dollars) then
			G.GAME.blind.dollars = 0
		end
	end
	PVP.GAME.lives = lives
end

function effects.win()
	PVP.GAME.won = true
	PVP.STATS.record_match(true)
	PVP.REPLAY.log.end_run({ result = "win" })
	PVP.UTILS.log_mem_debug_messages()
	-- end_pvp releases HAND_PLAYED.
	PVP.GAME.end_pvp = true
	win_game()
end

function effects.lose()
	PVP.STATS.record_match(false)
	G.STATE_COMPLETE = false
	G.STATE = G.STATES.GAME_OVER
	PVP.REPLAY.log.end_run({ result = "loss" })
	PVP.UTILS.log_mem_debug_messages()
end

-- A draw: game-over state, no stats.
function effects.draw()
	PVP.GAME.draw = true
	G.STATE_COMPLETE = false
	G.STATE = G.STATES.GAME_OVER
	PVP.REPLAY.log.end_run({ result = "draw" })
	PVP.UTILS.log_mem_debug_messages()
end

function effects.show_enemy_location(location)
	if location == nil then return end
	local value = ""

	if string.find(location, "-") then
		local split = {}
		for str in string.gmatch(location, "([^-]+)") do
			table.insert(split, str)
		end
		location = split[1]
		value = split[2] or ""
	end

	local loc_location = G.localization.misc.dictionary[location]

	if loc_location == nil then
		if location ~= nil then
			loc_location = location
		else
			loc_location = "Unknown"
		end
	end

	PVP.GAME.enemy.location = loc_location
	PVP.GAME.enemy.location_blind = value
	PVP.GAME.enemy.location_type = location
	PVP.GAME.enemy.location_full = location .. "-" .. value
	PVP.UI.update_enemy_location_render()
end
