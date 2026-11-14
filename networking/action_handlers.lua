-- ─── DON'T PATCH THIS FILE ───────────────────────────────────────────────────
-- This file owns the core network action dispatch. The contents move; the
-- string literals in here are NOT an API. PVP.HANDLERS and PVP.dispatch_action are the exports: the
-- pvp_api/ shells call into them, nothing else should.
--
-- ─────────────────────────────────────────────────────────────────────────────

-- Local state setters
function PVP.ACTIONS.set_username(username)
	PVP.LOBBY.username = username or "Guest"
end

function PVP.ACTIONS.set_blind_col(num)
	PVP.LOBBY.blind_col = num or 1
end

-- ── Run start (relocated from the removed legacy ui/lobby/lobby.lua) ──────────────
-- G.FUNCS.lobby_start_run is the actual multiplayer run-starter. It is called by
-- action_start_game below and by the API bridge gamemode's (required, but never invoked)
-- start_run in pvp_api/gamemodes.lua. The `mp_start` contract it passes to
-- G.FUNCS.start_run is interpreted by the start_run wrapper relocated to overrides/game.lua.
local function get_random_back_pool()
	local names, seen = {}, {}
	local cocktail_keys = PVP.get_cocktail_decks(false)
	for i = 1, #cocktail_keys do
		local key = cocktail_keys[i]
		if G.P_CENTERS[key] and not seen[key] then
			seen[key] = true
			names[#names + 1] = G.P_CENTERS[key].name
		end
	end
	if G.P_CENTERS["b_mp_cocktail"] and not seen["b_mp_cocktail"] then
		names[#names + 1] = G.P_CENTERS["b_mp_cocktail"].name
	end
	return names
end

local function scoped_random(seed, salt, max)
	if seed then math.randomseed(pseudohash(seed .. "_mp_random_" .. salt)) end
	return math.random(1, max)
end

local function roll_random_back_name(seed, salt)
	local names = get_random_back_pool()
	if #names == 0 then return "Red Deck" end
	return names[scoped_random(seed, "deck_" .. (salt or ""), #names)]
end

local function roll_random_stake(seed, salt)
	local cap = PVP.DECK.MAX_STAKE > 0 and PVP.DECK.MAX_STAKE or 8
	return scoped_random(seed, "stake_" .. (salt or ""), cap)
end

function G.FUNCS.copy_host_deck()
	PVP.LOBBY.deck.back = PVP.LOBBY.config.back
	-- The lobby config's cocktail is "" until the picker is edited. Keep it unset so every
	-- client builds the default pool, not its own saved selection.
	PVP.LOBBY.deck.cocktail = PVP.LOBBY.config.cocktail or ""
	PVP.LOBBY.deck.sleeve = PVP.LOBBY.config.sleeve
	PVP.LOBBY.deck.stake = PVP.LOBBY.config.stake
	PVP.LOBBY.deck.challenge = PVP.LOBBY.config.challenge
end

---@type fun(e: table | nil, args: { deck: string, stake: number | nil, seed: string | nil })
function G.FUNCS.lobby_start_run(e, args)
	if PVP.LOBBY.config.different_decks == false then G.FUNCS.copy_host_deck() end

	if PVP.LOBBY.config.different_decks and PVP.LOBBY.config.random_loadout then
		PVP.LOBBY.deck.back = roll_random_back_name(args.seed, PVP.LOBBY.username)
		PVP.LOBBY.deck.challenge = ""
		PVP.LOBBY.deck.stake = roll_random_stake(args.seed, PVP.LOBBY.username)
	end

	local challenge = nil
	if PVP.LOBBY.deck.back == "Challenge Deck" then
		challenge = G.CHALLENGES[get_challenge_int_from_id(PVP.LOBBY.deck.challenge)]
	else
		G.GAME.viewed_back = MPAPI.back_for_key(PVP.UTILS.get_deck_key_from_name(PVP.LOBBY.deck.back))
	end

	G.FUNCS.start_run(e, {
		mp_start = true,
		challenge = challenge,
		stake = tonumber(PVP.LOBBY.deck.stake),
		seed = args.seed,
	})
end

local function action_start_game(p)
	local seed = p.seed
	PVP.match_log("debug", string.format("Game starting — %s", os.date("%Y-%m-%dT%H:%M:%S%z")))
	-- Clear any stale practice state so it can't leak into real PVP
	PVP.SP.practice = false
	PVP.SP.playback_gamemode = nil

	PVP.reset_game_states()
	-- Snapshot who started this match: the end screen lists them even after they leave.
	local start_lobby = MPAPI.get_current_lobby()
	PVP._match_players = PVP.MATCH_PLAYERS.snapshot(start_lobby and start_lobby:get_players())
	-- Stamp the run start (drives the pause menu's seed-change window).
	PVP._run_started_at = love.timer.getTime()
	local stake = tonumber(p.stake)
	PVP.ACTIONS.set_ante(0)
	if not PVP.LOBBY.config.different_seeds and PVP.LOBBY.config.custom_seed ~= "random" then
		seed = PVP.LOBBY.config.custom_seed
	end

	-- Opens this MATCH's single RLOG block (begin_run is now once-per-match,
	-- same as SPDRN -- see BalatroMultiplayerAPI/api/replay/recorder.lua).
	-- match_manifest/lobby_info/run_info all fire immediately, synchronously:
	-- PvP (unlike SPDRN) already has everything it needs right here, no
	-- BLIND_SELECT deferral required. lobby_config/version/hash/challenge/
	-- sleeve/etc fields that used to live directly on the old single manifest
	-- now ride inside lobby_info's `options` (a mod-shaped catch-all, see
	-- api/replay/framing_codes.lua), since match_manifest's own shape is
	-- fixed/shared across mods.
	PVP.RLOG.begin_run()
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
			the_order_enabled = PVP.should_use_the_order(),
			different_seeds = PVP.LOBBY.config.different_seeds,
			mod_version = PVP and PVP.version,
			mod_hash = PVP.MOD_STRING,
			smods_version = SMODS.version,
			lovely_version = PVP.MIN_LOVELY_VERSION,
		})
	end
	MPAPI.RLOGCodes.run_info:write(seed, PVP.LOBBY.config.back, stake)

	G.FUNCS.lobby_start_run(nil, { seed = seed, stake = stake })
	PVP.LOBBY.ready_to_start = false
end

local function begin_pvp_blind()
	if PVP.GAME.next_blind_context then
		G.FUNCS.select_blind(PVP.GAME.next_blind_context)
	else
		sendErrorMessage("No next blind context", "MULTIPLAYER")
	end
end

local function action_start_blind(p)
	-- The countdown of a start still runs: a second start would run a second countdown and select the
	-- blind twice (the second select finds no blind select screen). The first start stands.
	if PVP.GAME.pvp_countdown_in_progress then return end
	-- The opponent's score and hands are unknown (nil) until the server's pvp.round says them
	-- (pvp_api/enemy_score_net.lua): last blind's values are not this blind's, and 0 is a score.
	PVP.GAME.enemy.score = nil
	PVP.GAME.enemy.score_ease = nil
	PVP.GAME.enemy.real_score = nil
	PVP.GAME.enemy.score_text = "???"
	PVP.GAME.enemy.hands = nil
	PVP.GAME.enemy.hands_text = "???"
	PVP.GAME.enemy.score_known = false
	if PVP.UI.refresh_enemy_score_label then PVP.UI.refresh_enemy_score_label() end
	if PVP.CURRENT_LOBBY then PVP.mirror_players(PVP.CURRENT_LOBBY) end
	PVP.GAME.ready_blind = false
	PVP.GAME.ready_intent = false
	-- The server drops the Ante deadline as the PvP blind starts; this client stops showing it now.
	PVP.TimerNet.stop()
	PVP.UI.start_pvp_countdown(begin_pvp_blind)
end

-- (action_enemy_info was removed: the opponent score/hands/skips/lives DISPLAY is now synced
-- by the nemesis blind's calculate/receive — see objects/blinds/nemesis.lua.)

-- The server spent this player's hands (the round is still open for the others): the hands-left
-- jokers (Ice Cream, Seltzer) see the loss with the hands still unplayed, the hands go to 0 and the
-- player waits for the round's result. end_pvp stays unset: the result ends the blind through
-- action_end_pvp.
local function action_hands_spent()
	local hands_left = G.GAME.current_round.hands_left
	if hands_left <= 0 then return end
	stop_use()
	SMODS.calculate_context({ mp_pvp_loss = true, mp_hands_left = hands_left })
	G.GAME.current_round.hands_left = 0
	attention_text({
		scale = 0.8,
		text = localize("k_wait_enemy"),
		hold = 5,
		align = "cm",
		offset = { x = 0, y = -1.5 },
		major = G.play,
	})
end

local function action_end_pvp()
	PVP.GAME.end_pvp = true
	PVP.TimerNet.stop()
	PVP.GAME.ready_blind = false
	PVP.GAME.ready_intent = false
	PVP.GAME.score = nil
end

local function action_win_game()
	PVP.end_game_jokers_payload = ""
	PVP.nemesis_deck_string = ""
	PVP.end_game_jokers_received = false
	PVP.nemesis_deck_received = false
	PVP.GAME.won = true
	PVP.STATS.record_match(true)
	PVP.RLOG.end_run({ result = "win" })
	PVP.UTILS.log_mem_debug_messages()
	PVP.report_roster_result()
	-- The server result can arrive while the winner is still mid-HAND_PLAYED (last hand
	-- exhausted hands_left before the opponent's result arrived). Unlike
	-- action_lose_game (which force-sets G.STATE directly), win_game() alone
	-- doesn't know about end_pvp, the flag update_hand_played's override
	-- requires to ever release HAND_PLAYED -- without it the client hangs
	-- forever. Mirrors action_end_pvp's established handoff for this same gate.
	PVP.GAME.end_pvp = true
	win_game()
end

local function action_lose_game()
	PVP.end_game_jokers_payload = ""
	PVP.nemesis_deck_string = ""
	PVP.end_game_jokers_received = false
	PVP.nemesis_deck_received = false
	PVP.STATS.record_match(false)
	G.STATE_COMPLETE = false
	G.STATE = G.STATES.GAME_OVER
	PVP.RLOG.end_run({ result = "loss" })
	PVP.UTILS.log_mem_debug_messages()
	PVP.report_roster_result()
end

-- A draw is neither a win nor a loss -- same game-over-shaped state transition as
-- action_lose_game (PVP.GAME.won stays unset, so create_UIBox_game_over is what
-- vanilla's own win/game-over dichotomy calls, see game_end.lua's overrides), but
-- PVP.GAME.draw flags it so PVP.UI.create_UIBox_mp_game_end shows the real draw
-- screen instead, and PVP.STATS.record_match is skipped entirely (a draw counts as
-- neither a win nor a loss in the match-history stats).
local function action_draw_game()
	PVP.end_game_jokers_payload = ""
	PVP.nemesis_deck_string = ""
	PVP.end_game_jokers_received = false
	PVP.nemesis_deck_received = false
	PVP.GAME.draw = true
	G.STATE_COMPLETE = false
	G.STATE = G.STATES.GAME_OVER
	PVP.RLOG.end_run({ result = "draw" })
	PVP.UTILS.log_mem_debug_messages()
	PVP.report_roster_result()
end

local function enemyLocation(options)
	local location = options.location
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

function G.FUNCS.load_end_game_jokers()
	local card_area_save, success, err

	if not PVP.end_game_jokers or not PVP.end_game_jokers_payload then return end

	card_area_save, err = MPAPI.decode(PVP.end_game_jokers_payload)
	if not card_area_save then
		PVP.match_log("debug", string.format("Failed to unpack enemy jokers: %s", err))
		return
	end

	-- Avoid crashing if the load function ends up indexing a nil value
	success, err = pcall(PVP.end_game_jokers.load, PVP.end_game_jokers, card_area_save)
	if not success then
		PVP.match_log("debug", string.format("Failed to load enemy jokers: %s", err))
		-- Reset the card area if loading fails to avoid inconsistent state
		PVP.end_game_jokers:remove()
		PVP.end_game_jokers:init(
			---@diagnostic disable-next-line: param-type-mismatch
			0,
			0,
			5 * G.CARD_W,
			G.CARD_H,
			{ card_limit = G.GAME.starting_params.joker_slots, type = "joker", highlight_limit = 1, fixed_limit = true }
		)
		return
	end

	-- Log the jokers
	if PVP.end_game_jokers.cards then
		local jokers_str = ""
		for _, card in pairs(PVP.end_game_jokers.cards) do
			jokers_str = jokers_str .. ";" .. PVP.UTILS.joker_to_string(card)
		end
		PVP.match_log("trace", string.format("Received end game jokers: %s", jokers_str))
	end
end

local function action_receive_end_game_jokers(p)
	PVP.end_game_jokers_payload = p.keys
	PVP.end_game_jokers_received = true
	G.FUNCS.load_end_game_jokers()
end

local function action_get_end_game_jokers()
	if not G.jokers or not G.jokers.cards then
		PVP.net_route({
			action = "receiveEndGameJokers",
			keys = {},
		})
		return
	end

	-- Log the jokers
	local jokers_str = ""
	for _, card in pairs(G.jokers.cards) do
		jokers_str = jokers_str .. ";" .. PVP.UTILS.joker_to_string(card)
	end
	PVP.match_log("trace", string.format("Sending end game jokers: %s", jokers_str))

	local jokers_save = G.jokers:save()
	local jokers_encoded = MPAPI.encode(jokers_save)

	PVP.net_route({
		action = "receiveEndGameJokers",
		keys = jokers_encoded,
	})
end

local function action_get_nemesis_deck()
	local deck_str = ""
	for _, card in ipairs(G.playing_cards) do
		deck_str = deck_str .. ";" .. PVP.UTILS.card_to_string(card)
	end
	PVP.net_route({
		action = "receiveNemesisDeck",
		cards = deck_str,
	})
end

local function action_send_game_stats()
	if not PVP.GAME.stats then
		PVP.net_route({
			action = "nemesisEndGameStats",
		})
		return
	end

	local stats = {
		action = "nemesisEndGameStats",
		reroll_count = PVP.GAME.stats.reroll_count,
		reroll_cost_total = PVP.GAME.stats.reroll_cost_total,
	}

	-- Extract voucher keys where value is true and join them with a dash
	local voucher_keys = ""
	if G.GAME.used_vouchers then
		local keys = {}
		for k, v in pairs(G.GAME.used_vouchers) do
			if v == true then table.insert(keys, k) end
		end
		voucher_keys = table.concat(keys, "-")
	end

	-- Add voucher keys to stats string
	if voucher_keys ~= "" then stats.vouchers = voucher_keys end

	PVP.net_route(stats)
end

function G.FUNCS.load_nemesis_deck()
	-- nemesis_deck.cards is nil once a finished run has removed the area. Loading into it
	-- would error after each card was already added to our own deck, leaving it there.
	if
		not PVP.nemesis_deck_string
		or not PVP.nemesis_deck
		or not PVP.nemesis_deck.cards
		or not PVP.nemesis_cards
		or not PVP.LOBBY.code
	then
		return
	end

	local card_strings = PVP.UTILS.string_split(PVP.nemesis_deck_string, ";")

	for k, _ in pairs(PVP.nemesis_cards) do
		PVP.nemesis_cards[k] = nil
	end

	for _, card_str in pairs(card_strings) do
		if card_str == "" then goto continue end

		local card_params = PVP.UTILS.string_split(card_str, "-")

		local suit = card_params[1]
		local rank = card_params[2]
		local enhancement = card_params[3]
		local edition = card_params[4]
		local seal = card_params[5]

		-- Validate the card parameters
		-- If invalid suit or rank, skip the card
		-- If invalid enhancement, edition, or seal, fallback to "none"
		local front_key = tostring(suit) .. "_" .. tostring(rank)
		if not G.P_CARDS[front_key] then
			PVP.match_log("debug", string.format("Invalid playing card key: %s", front_key))
			goto continue
		end
		if not enhancement or (enhancement ~= "none" and not G.P_CENTERS[enhancement]) then
			PVP.match_log("debug", string.format("Invalid enhancement: %s", enhancement))
			enhancement = "none"
		end
		if not edition or (edition ~= "none" and not G.P_CENTERS["e_" .. edition]) then
			PVP.match_log("debug", string.format("Invalid edition: %s", edition))
			edition = "none"
		end
		if not seal or (seal ~= "none" and not G.P_SEALS[seal]) then
			PVP.match_log("debug", string.format("Invalid seal: %s", seal))
			seal = "none"
		end

		-- A bare Card, not create_playing_card: the nemesis card must never join our own deck.
		local area = PVP.nemesis_deck
		local card = Card(
			area.T.x,
			area.T.y,
			G.CARD_W,
			G.CARD_H,
			G.P_CARDS[front_key],
			enhancement ~= "none" and G.P_CENTERS[enhancement] or G.P_CENTERS.c_base
		)
		area:emplace(card)
		if edition ~= "none" then card:set_edition({ [edition] = true }, true, true) end
		if seal ~= "none" then card:set_seal(seal, true, true) end
		table.insert(PVP.nemesis_cards, card)

		::continue::
	end
end

local function action_receive_nemesis_deck(p)
	PVP.nemesis_deck_string = p.cards
	-- A reply with no live deck area is not loaded, so it does not count as received.
	PVP.nemesis_deck_received = PVP.nemesis_deck ~= nil and PVP.nemesis_deck.cards ~= nil
	G.FUNCS.load_nemesis_deck()
end

function PVP.ACTIONS.ready_blind(e)
	PVP.GAME.next_blind_context = e
	PVP.net_route({
		action = "readyBlind",
	})
end

function PVP.ACTIONS.unready_blind()
	PVP.net_route({
		action = "unreadyBlind",
	})
end

-- Tells the server how this client ended the current non-PvP blind. `blind` (optional)
-- names the blind when it is no longer the one on deck, as after a skip. A failure is
-- sent by failRound instead.
function PVP.ACTIONS.blind_result(beaten, blind)
	local lobby = MPAPI.get_current_lobby()
	local ante = G.GAME.round_resets.ante
	blind = blind or G.GAME.blind_on_deck
	if lobby then
		PVP.net_route({
			action = "blindResult",
			ante = ante,
			blind = blind,
			beaten = beaten,
		})
	end
end

function PVP.ACTIONS.fail_round(hands_used)
	if PVP.LOBBY.config.no_gold_on_round_loss then G.GAME.blind.dollars = 0 end
	if hands_used == 0 then return end
	PVP.net_route({
		action = "failRound",
		ante = G.GAME.round_resets.ante,
		blind = G.GAME.blind_on_deck,
	})
end

function PVP.ACTIONS.set_location(location, blind)
	local location_type = location
	local location_blind = blind
	if string.find(location, "-") then
		local split = {}
		for str in string.gmatch(location, "([^-]+)") do
			table.insert(split, str)
		end
		location_type = split[1]
		location_blind = split[2] or ""
	else
		location_blind = PVP.UTILS.get_blind_to_display(blind) or ""
	end
	location = location_type .. "-" .. location_blind

	if PVP.GAME.location == location then return end
	PVP.GAME.location = location
	PVP.GAME.location_type = location_type
	PVP.GAME.location_blind = location_blind
	PVP.GAME.location_full = location
	PVP.net_route({
		action = "setLocation",
		location = location,
	})
end

function PVP.ACTIONS.update_location(keep_blind)
	if PVP.GAME.location_type then
		PVP.ACTIONS.set_location(PVP.GAME.location_type, keep_blind and PVP.GAME.location_blind or nil)
	end
end

---@param score number
---@param hands_left number
function PVP.ACTIONS.play_hand(score, hands_left)
	local score_text = PVP.Score.from_game_value(score)
	PVP.GAME.score = score_text
	if PVP.Score.greater(score_text, PVP.GAME.highest_score) then PVP.GAME.highest_score = score_text end
	-- §17.10: the end-of-run roster's "highest PvP-blind score" needs the
	-- PvP-blind-only figure, not the any-blind one tracked just above.
	if PVP.is_pvp_boss() and PVP.Score.greater(score_text, PVP.GAME.highest_pvp_score) then
		PVP.GAME.highest_pvp_score = score_text
	end

	PVP.net_route({
		action = "playHand",
		score = score_text,
		handsLeft = hands_left,
	})
end

function PVP.ACTIONS.set_ante(ante)
	PVP.net_route({
		action = "setAnte",
		ante = ante,
	})
end

function PVP.ACTIONS.new_round()
	PVP.GAME.duplicate_end = false
	PVP.GAME.round_ended = false
end

function PVP.ACTIONS.set_furthest_blind(furthest_blind)
	PVP.net_route({
		action = "setFurthestBlind",
		furthestBlind = furthest_blind,
	})
end

function PVP.ACTIONS.skip(skips, blind_key)
	PVP.SkipsNet.skip(skips, blind_key)
end

function PVP.ACTIONS.get_end_game_jokers()
	PVP.net_route({
		action = "getEndGameJokers",
	})
end

function PVP.ACTIONS.get_nemesis_deck()
	PVP.net_route({
		action = "getNemesisDeck",
	})
end

function PVP.ACTIONS.send_game_stats()
	action_send_game_stats()
end

function PVP.ACTIONS.request_nemesis_stats()
	PVP.net_route({
		action = "endGameStatsRequested",
	})
end

-- Play was pressed in the PvP blind: `hands_left` is the hands left once this hand is played. The server
-- credits the hand's time on its own clock (pvp_api/net.lua handCommit, pvp_api/round_net.lua).
function PVP.ACTIONS.hand_commit(hands_left)
	PVP.net_route({
		action = "handCommit",
		handsLeft = hands_left,
	})
end

-- The player started (true) or stopped (false) animating inside a clock that freezes for animations
-- (pvp_api/animating_net.lua decides when; pvp_api/round_net.lua sends it).
function PVP.ACTIONS.set_animating(animating)
	PVP.RoundNet.animating(animating)
end

-- #endregion Client to Server

-- Utils
function PVP.ACTIONS.update_player_usernames()
	if PVP.LOBBY.code then
		if G.MAIN_MENU_UI then G.MAIN_MENU_UI:remove() end
		set_main_menu_UI()
	end
end

local function string_to_table(str)
	local tbl = {}
	for part in string.gmatch(str, "([^,]+)") do
		local key, value = string.match(part, "([^:]+):(.+)")
		if key and value then tbl[key] = value end
	end
	return tbl
end

-- The server's "you are out" for a match that goes on without this player (Royale and
-- N-player Nemesis/Manhunt): the lose screen now instead of playing on. The match's own
-- result still arrives later and is then only reported. params: { player_id }.
local function action_eliminated(params)
	if params.player_id ~= PVP.self_player_id() or PVP.GAME.eliminated or PVP.GAME.contested then return end
	PVP.GAME.eliminated = true
	PVP.end_pending_death()
	PVP.dispatch_action("loseGame")
end

-- A player lost their last life on a non-PvP blind in a 2-player match (or a whole
-- Manhunt/Teams side did: params.team_id); the result waits for the opponent to beat the
-- same blind. params: { player_id, opponent_id, blind_key, team_id? }.
local function action_death_pending(params)
	local self_id = PVP.self_player_id
	if PVP.GAME.won or PVP.GAME.draw then return end
	if params.team_id then
		-- Manhunt or Teams: a whole side is pending. Every client keeps it; the dead
		-- side's players wait on the screen.
		PVP.GAME.team_pending = { team_id = params.team_id, blind_key = params.blind_key }
		local roster = PVP.LOBBY.roster
		if not (roster and roster[self_id()] == params.team_id) then
			PVP.UI.show_pending_death_notice()
			return
		end
		PVP.GAME.pending_death = { player_id = self_id(), blind_key = params.blind_key }
		PVP.UI.show_pending_death_screen()
		return
	end
	if params.opponent_id == nil then
		-- A match of 3 or more players: only the dead player waits on the screen, the rest get a notice.
		if params.player_id ~= self_id() then
			PVP.UI.show_pending_death_notice()
			return
		end
	end
	PVP.GAME.pending_death = {
		player_id = params.player_id,
		opponent_id = params.opponent_id,
		blind_key = params.blind_key,
	}
	if params.player_id == self_id() then
		PVP.UI.show_pending_death_screen()
	else
		PVP.UI.show_pending_death_notice()
	end
end

local function noop() end

local HANDLERS = {
	startGame = action_start_game,
	startBlind = action_start_blind,
	handsSpent = action_hands_spent,
	endPvP = action_end_pvp,
	winGame = action_win_game,
	loseGame = action_lose_game,
	drawGame = action_draw_game,
	eliminated = action_eliminated,
	deathPending = action_death_pending,
	enemyLocation = enemyLocation,
	getEndGameJokers = action_get_end_game_jokers,
	receiveEndGameJokers = action_receive_end_game_jokers,
	getNemesisDeck = action_get_nemesis_deck,
	receiveNemesisDeck = action_receive_nemesis_deck,
	endGameStatsRequested = action_send_game_stats,
	nemesisEndGameStats = noop, -- nothing to apply
}

-- The same table, for the *_net.lua shells that apply a server fact through a handler
-- body (PVP.HANDLERS.winGame(), ...); the bodies are the ones above, unchanged.
PVP.HANDLERS = HANDLERS

-- Peer dispatch: invoke a server->client action handler by its wire name. The
-- MPAPI ActionType layer (pvp_api/) calls this from on_receive to run the existing
-- client-side handlers when a peer action arrives, replacing the old socket pump.
function PVP.dispatch_action(name, params)
	local handler = HANDLERS[name]
	if handler then
		handler(params or {})
	else
		sendWarnMessage("PVP.dispatch_action: no handler for '" .. tostring(name) .. "'", "MULTIPLAYER")
	end
end
