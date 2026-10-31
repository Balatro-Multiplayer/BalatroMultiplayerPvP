-- ─── DON'T PATCH THIS FILE ───────────────────────────────────────────────────
-- This file owns the core network action dispatch. The contents move; the
-- string literals in here are NOT an API. HANDLERS is a file-local on
-- purpose — there is no global, no PVP.HANDLERS, no _G shim coming to save you.
--
-- If you want to handle a network action from a mod, use one of:
--
--   PVP.register_mod_action(name, cb)  -- PREFERRED. Pair with the
--                                     -- "moddedAction" envelope on the server:
--                                     --   {action = "moddedAction",
--                                     --    modId = …, modAction = name, …}
--                                     -- Keeps your action names namespaced to
--                                     -- your modId; no collisions with core
--                                     -- or other mods.
--
--   PVP.register_action(name, cb)      -- Escape hatch for legacy server code
--                                     -- that emits flat top-level action
--                                     -- names. Refuses to register over an
--                                     -- existing handler (including core) —
--                                     -- first registration wins, collisions
--                                     -- warn and are dropped. Use the mod API
--                                     -- above if you can.
-- ─────────────────────────────────────────────────────────────────────────────

local json = require("json")

Client = {}

function Client.send(msg)
	msg = json.encode(msg)
	if msg ~= '{"action":"keepAliveAck"}' then
		sendTraceMessage(string.format("Client sent message: %s", msg), "MULTIPLAYER")
	end
	love.thread.getChannel("uiToNetwork"):push(msg)
end

-- Server to Client
function PVP.ACTIONS.set_username(username)
	PVP.LOBBY.username = username or "Guest"
	if PVP.LOBBY.connected then
		Client.send({
			action = "username",
			username = PVP.LOBBY.username .. "~" .. PVP.LOBBY.blind_col,
			modHash = PVP.MOD_STRING,
		})
	end
end

function PVP.ACTIONS.set_blind_col(num)
	PVP.LOBBY.blind_col = num or 1
end

-- Stops both ante timers and drops a held-back timer start.
local function stop_timers()
	PVP.GAME.timer_started = false
	PVP.GAME.nemesis_timer_started = false
	PVP.GAME.timer_threshold_pending = false
end

-- Reconnection state (persists across connections)
local reconnectToken = nil
local lastLobbyCode = nil

local function action_connected()
	PVP.LOBBY.connected = true
	PVP.UI.update_connection_status()
	Client.send({
		action = "username",
		username = PVP.LOBBY.username .. "~" .. PVP.LOBBY.blind_col,
		modHash = PVP.MOD_STRING,
	})

	-- If we have reconnect info, attempt to rejoin the lobby
	if reconnectToken and lastLobbyCode then
		Client.send({
			action = "rejoinLobby",
			code = lastLobbyCode,
			reconnectToken = reconnectToken,
		})
	end
end

local function action_joinedLobby(p)
	local code, type, token = p.code, p.type, p.reconnectToken
	PVP.LOBBY.code = code
	PVP.LOBBY.type = type
	PVP.LOBBY.ready_to_start = false
	-- Store reconnect info for potential future reconnection
	if token then reconnectToken = token end
	lastLobbyCode = code
	PVP.ACTIONS.sync_client()
	PVP.ACTIONS.lobby_info()
	PVP.UI.update_connection_status()
end

local function action_rejoinedLobby(p)
	local code, type, token = p.code, p.type, p.reconnectToken
	PVP.LOBBY.code = code
	PVP.LOBBY.type = type
	-- Update reconnect token
	reconnectToken = token
	lastLobbyCode = code
	PVP.self_reconnect_countdown = nil
	stop_timers()
	PVP.ACTIONS.sync_client()
	PVP.ACTIONS.lobby_info()
	PVP.UI.update_connection_status()
	sendWarnMessage("Reconnected to lobby!", "MULTIPLAYER")
	G.FUNCS.exit_overlay_menu()
	PVP.UI.UTILS.overlay_message("Reconnected to lobby!")
end

-- Countdown state for disconnect overlays
PVP.enemy_disconnect_countdown = nil
PVP.self_reconnect_countdown = nil

-- Shared timeout handler for both countdowns
local function handle_reconnect_timeout(message)
	G.FUNCS.exit_overlay_menu()
	PVP.LOBBY.connected = false
	if PVP.LOBBY.code then PVP.LOBBY.code = nil end
	reconnectToken = nil
	lastLobbyCode = nil
	PVP.UI.update_connection_status()
	if G.STAGE ~= G.STAGES.MAIN_MENU then
		PVP.reset_game_states()
		G.FUNCS.go_to_menu()
	end
	PVP.UI.UTILS.overlay_message(message)
end

-- Hook into Game.update to tick countdown displays
local _disconnect_gupdate = Game.update
function Game:update(dt)
	if PVP.enemy_disconnect_countdown then
		local remaining = math.max(0, math.ceil(PVP.enemy_disconnect_countdown.end_time - love.timer.getTime()))
		PVP.enemy_disconnect_countdown.display = remaining .. "s remaining"
		-- No client-side timeout needed: the server sends stopGame
		-- when the grace period expires, which handles the cleanup
	end
	if PVP.self_reconnect_countdown then
		local remaining = math.max(0, math.ceil(PVP.self_reconnect_countdown.end_time - love.timer.getTime()))
		PVP.self_reconnect_countdown.display = remaining .. "s remaining"
		if remaining <= 0 then
			PVP.self_reconnect_countdown = nil
			handle_reconnect_timeout("Reconnection failed.\nReturning to main menu.")
		end
	end
	return _disconnect_gupdate(self, dt)
end

local function action_enemyDisconnected(p)
	local timeout = p.timeout or 60
	sendWarnMessage("Opponent disconnected, waiting for reconnection...", "MULTIPLAYER")

	stop_timers()

	PVP.enemy_disconnect_countdown = {
		end_time = love.timer.getTime() + timeout,
		display = timeout .. "s remaining",
	}

	PVP.UI.UTILS.overlay_message_countdown(
		"Opponent disconnected,\nwaiting for reconnection...",
		PVP.enemy_disconnect_countdown,
		true
	)
end

local function action_enemyReconnected()
	PVP.enemy_disconnect_countdown = nil
	sendWarnMessage("Opponent reconnected!", "MULTIPLAYER")
	G.FUNCS.exit_overlay_menu()
	PVP.UI.UTILS.overlay_message("Opponent reconnected!")
end

local function action_lobbyInfo(p)
	local host, hostHash, hostCached = p.host, p.hostHash, p.hostCached
	local guest, guestHash, guestCached, guestReady = p.guest, p.guestHash, p.guestCached, p.guestReady
	local is_host = p.isHost
	PVP.LOBBY.players = {}
	PVP.LOBBY.is_host = is_host
	local function parseName(name)
		local username, col_str = string.match(name, "([^~]+)~(%d+)")
		username = username or "Guest"
		local col = tonumber(col_str) or 1
		col = math.max(1, math.min(col, 25))
		return username, col
	end
	local hostName, hostCol = parseName(host)
	local hostConfig, hostMods = PVP.UTILS.parse_Hash(hostHash)
	PVP.LOBBY.host = {
		username = hostName,
		blind_col = hostCol,
		hash_str = hostMods,
		hash = hash(hostMods),
		cached = hostCached,
		config = hostConfig,
	}

	if guest ~= nil then
		local guestName, guestCol = parseName(guest)
		local guestConfig, guestMods = PVP.UTILS.parse_Hash(guestHash)
		PVP.LOBBY.guest = {
			username = guestName,
			blind_col = guestCol,
			hash_str = guestMods,
			hash = hash(guestMods),
			cached = guestCached,
			config = guestConfig,
		}
	else
		PVP.LOBBY.guest = {}
	end

	-- TODO: This should check for player count instead
	-- once we enable more than 2 players
	PVP.LOBBY.ready_to_start = guest ~= nil and guestReady

	if PVP.LOBBY.is_host then PVP.ACTIONS.lobby_options() end

	if G.STAGE == G.STAGES.MAIN_MENU then PVP.ACTIONS.update_player_usernames() end

	-- Re-arm the mismatch modal when all mismatches clear (opponent left or was replaced).
	if #PVP.UTILS.version_mismatches() == 0 then PVP._version_mismatch_shown = false end
end

local function action_error(p)
	local message = p.message
	sendWarnMessage(message, "MULTIPLAYER")

	PVP.UI.UTILS.overlay_message(message)
end

local function action_keep_alive()
	Client.send({
		action = "keepAliveAck",
	})
end

local function action_disconnected()
	PVP.LOBBY.connected = false
	PVP.self_reconnect_countdown = nil
	if PVP.LOBBY.code then PVP.LOBBY.code = nil end
	-- Clear reconnect state since all reconnection attempts failed
	reconnectToken = nil
	lastLobbyCode = nil
	PVP.UI.update_connection_status()
end

local function action_reconnecting()
	-- Only show if we were in a lobby and don't already have a countdown running
	if reconnectToken and lastLobbyCode and not PVP.self_reconnect_countdown then
		PVP.LOBBY.connected = false
		stop_timers()
		PVP.UI.update_connection_status()
		sendWarnMessage("Connection lost, attempting to reconnect...", "MULTIPLAYER")

		PVP.self_reconnect_countdown = {
			end_time = love.timer.getTime() + 60,
			display = "60s remaining",
		}

		PVP.UI.UTILS.overlay_message_countdown(
			"Connection lost,\nattempting to reconnect...",
			PVP.self_reconnect_countdown,
			true
		)
	end
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
	if seed then
		math.randomseed(pseudohash(seed .. "_mp_random_" .. salt))
	end
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
	sendDebugMessage(string.format("Game starting — %s", os.date("%Y-%m-%dT%H:%M:%S%z")), "MULTIPLAYER")
	-- Clear any stale practice state so it can't leak into real PVP
	PVP.SP.practice = false

	PVP.reset_game_states()
	-- Snapshot who started this match: the end screen lists them even after they leave.
	local start_lobby = MPAPI.get_current_lobby()
	PVP._match_players = PVP.MATCH_PLAYERS.snapshot(start_lobby and start_lobby:get_players())
	-- Stamp the run start (drives the pause menu's seed-change window) and clear any
	-- pending seed-change votes from a previous run/reseed.
	PVP._run_started_at = love.timer.getTime()
	if PVP.lobby and PVP.lobby.seed_votes then
		PVP.lobby.seed_votes:reset()
	end
	if PVP.lobby and PVP.lobby.draw_votes then
		PVP.lobby.draw_votes:reset()
	end
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
	local first_player = p.firstPlayer
	-- Reset the stored opponent score each blind so the first frame after we
	-- play (which lifts the "???" mask) shows 0, not last blind's stale score.
	PVP.GAME.enemy.score = PVP.Score.ZERO
	PVP.GAME.enemy.score_ease = nil
	PVP.GAME.enemy.real_score = PVP.Score.ZERO
	PVP.GAME.enemy.score_text = PVP.Score.ZERO
	-- Re-mask the opponent's score until the first enemyInfo of the new blind.
	PVP.GAME.enemy.info_received = false
	-- The opponent's own starting hands (they differ with vouchers and jokers); ours
	-- stand in when the host did not relay theirs. Shown until their first real update.
	PVP.GAME.enemy.hands = p.startingHands or PVP.OPPONENT_SIGNALS.starting_hands(G.GAME.round_resets)
	-- Royale's live target and the Manhunt Runner's live target are re-broadcast
	-- fresh each blind by the host (pvp_api/referee.lua), so clear the stale value
	-- here too (a no-op for 1v1/Nemesis, which don't use these fields). Teams'
	-- team_card_target_id is NOT reset here -- it re-picks once per ante, the same
	-- cadence as Nemesis pairing, not once per blind.
	PVP.GAME.royale_target_id = nil
	PVP.GAME.royale_target_safe = nil
	if PVP.UI.refresh_enemy_score_label then
		PVP.UI.refresh_enemy_score_label()
	end
	PVP.GAME.manhunt_target_id = nil
	if PVP.CURRENT_LOBBY then PVP.mirror_players(PVP.CURRENT_LOBBY) end
	PVP.GAME.ready_blind = false
	PVP.GAME.pvp_reached = false
	stop_timers()
	PVP.GAME.timer_consumed = false
	PVP.GAME.timer = PVP.UTILS.pvp_timer_base()
	PVP.GAME.pvp_reached_first = (PVP.LOBBY.is_host and "host" or "guest") == first_player
	PVP.UI.start_pvp_countdown(begin_pvp_blind)
end

-- (action_enemy_info was removed: the opponent score/hands/skips/lives DISPLAY is now synced
-- by the nemesis blind's calculate/receive — see objects/blinds/nemesis.lua.)

local function action_stop_game()
	PVP.enemy_disconnect_countdown = nil
	if G.STAGE ~= G.STAGES.MAIN_MENU then
		G.FUNCS.go_to_menu()
		PVP.UI.update_connection_status()
		PVP.reset_game_states()
	end
	PVP.RLOG.end_run({ result = "stop" })
	PVP.UTILS.emit_log_checksum()
end

local function action_end_pvp(p)
	local lost, pvpTimerLost = p.lost, p.pvpTimerLost
	if lost and pvpTimerLost then
		if G.GAME.current_round.hands_left > 0 then
            stop_use()
			SMODS.calculate_context({ mp_pvp_loss = true, mp_hands_left = G.GAME.current_round.hands_left })
		end
	end
	PVP.GAME.end_pvp = true
	PVP.GAME.timer = PVP.UTILS.timer_base()
	PVP.GAME.timer_consumed = false
	stop_timers()
	PVP.GAME.ready_blind = false
	PVP.GAME.pvp_reached = false
    PVP.GAME.pvp_reached_first = false
	PVP.GAME.score = nil
	-- The PvP is over: clear the referee's lives blocker now, not at the next blind
	-- select, so an ante timer running out on the cash out or in the shop costs a life.
	Client.send({ action = "newRound" })
end

local function action_player_info(p)
	local lives = p.lives
	if PVP.GAME.lives ~= lives then
		if PVP.GAME.lives ~= 0 and PVP.LOBBY.config.gold_on_life_loss then
			PVP.GAME.comeback_bonus_given = false
			PVP.GAME.comeback_bonus = PVP.GAME.comeback_bonus + 1
		end
		PVP.UI.ease_lives(lives - PVP.GAME.lives, true)
		if PVP.LOBBY.config.no_gold_on_round_loss and (G.GAME.blind and G.GAME.blind.dollars) then
			G.GAME.blind.dollars = 0
		end
	end
	PVP.GAME.lives = lives
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
	PVP.UTILS.emit_log_checksum()
	PVP.report_roster_result()
	-- pvp_win can fire while the winner is still mid-HAND_PLAYED (last hand
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
	PVP.UTILS.emit_log_checksum()
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
	PVP.UTILS.emit_log_checksum()
	PVP.report_roster_result()
end

local function action_lobby_options(options)
	local different_decks_before = PVP.LOBBY.config.different_decks
	for k, v in pairs(options) do
		if k == "ruleset" then
			if not PVP.Rulesets[v] then
				G.FUNCS.mp_pvp_leave_lobby()
				PVP.UI.UTILS.overlay_message(localize({
					type = "variable",
					key = "k_failed_to_join_lobby",
					vars = { localize("k_ruleset_not_found") },
				}))
				return
			end
			local disabled = PVP.Rulesets[v].is_disabled()
			if disabled then
				G.FUNCS.mp_pvp_leave_lobby()
				PVP.UI.UTILS.overlay_message(
					localize({ type = "variable", key = "k_failed_to_join_lobby", vars = { disabled } })
				)
				return
			end
			PVP.LOBBY.config.ruleset = v
			goto continue
		end
		if k == "gamemode" then
			PVP.LOBBY.config.gamemode = v
			goto continue
		end
		if k == "modifier_layers" then
			PVP.LOBBY.config.modifier_layers = v
			PVP.modifiers_parse(v)
			goto continue
		end

		local parsed_v = v
		if v == "true" then
			parsed_v = true
		elseif v == "false" then
			parsed_v = false
		end

		if
			k == "starting_lives"
			or k == "pvp_start_round"
			or k == "timer_base_seconds"
			or k == "timer_increment_seconds"
			or k == "pvp_countdown_seconds"
			or k == "timer_forgiveness"
		then
			parsed_v = tonumber(v)
		end

		PVP.LOBBY.config[k] = parsed_v
		if PVP.UI.update_lobby_option_toggle then PVP.UI.update_lobby_option_toggle(k) end
		::continue::
	end
	if different_decks_before ~= PVP.LOBBY.config.different_decks then
		G.FUNCS.exit_overlay_menu() -- throw out guest from any menu.
	end
	PVP.ACTIONS.update_player_usernames() -- render new DECK button state
end

local function action_speedrun()
	SMODS.calculate_context({ mp_speedrun = true })
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

local function action_version()
	PVP.ACTIONS.version()
end

function G.FUNCS.load_end_game_jokers()
	local card_area_save, success, err

	if not PVP.end_game_jokers or not PVP.end_game_jokers_payload then return end

	card_area_save, err = MPAPI.decode(PVP.end_game_jokers_payload)
	if not card_area_save then
		sendDebugMessage(string.format("Failed to unpack enemy jokers: %s", err), "MULTIPLAYER")
		return
	end

	-- Avoid crashing if the load function ends up indexing a nil value
	success, err = pcall(PVP.end_game_jokers.load, PVP.end_game_jokers, card_area_save)
	if not success then
		sendDebugMessage(string.format("Failed to load enemy jokers: %s", err), "MULTIPLAYER")
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
		sendTraceMessage(string.format("Received end game jokers: %s", jokers_str), "MULTIPLAYER")
	end
end

local function action_receive_end_game_jokers(p)
	PVP.end_game_jokers_payload = p.keys
	PVP.end_game_jokers_received = true
	G.FUNCS.load_end_game_jokers()
end

local function action_get_end_game_jokers()
	if not G.jokers or not G.jokers.cards then
		Client.send({
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
	sendTraceMessage(string.format("Sending end game jokers: %s", jokers_str), "MULTIPLAYER")

	local jokers_save = G.jokers:save()
	local jokers_encoded = MPAPI.encode(jokers_save)

	Client.send({
		action = "receiveEndGameJokers",
		keys = jokers_encoded,
	})
end

local function action_get_nemesis_deck()
	local deck_str = ""
	for _, card in ipairs(G.playing_cards) do
		deck_str = deck_str .. ";" .. PVP.UTILS.card_to_string(card)
	end
	Client.send({
		action = "receiveNemesisDeck",
		cards = deck_str,
	})
end

local function action_send_game_stats()
	if not PVP.GAME.stats then
		Client.send({
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

	Client.send(stats)
end

function G.FUNCS.load_nemesis_deck()
	if not PVP.nemesis_deck_string or not PVP.nemesis_deck or not PVP.nemesis_cards or not PVP.LOBBY.code then return end

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
			sendDebugMessage(string.format("Invalid playing card key: %s", front_key), "MULTIPLAYER")
			goto continue
		end
		if not enhancement or (enhancement ~= "none" and not G.P_CENTERS[enhancement]) then
			sendDebugMessage(string.format("Invalid enhancement: %s", enhancement), "MULTIPLAYER")
			enhancement = "none"
		end
		if not edition or (edition ~= "none" and not G.P_CENTERS["e_" .. edition]) then
			sendDebugMessage(string.format("Invalid edition: %s", edition), "MULTIPLAYER")
			edition = "none"
		end
		if not seal or (seal ~= "none" and not G.P_SEALS[seal]) then
			sendDebugMessage(string.format("Invalid seal: %s", seal), "MULTIPLAYER")
			seal = "none"
		end

		-- Create the card
		local card = create_playing_card({
			front = G.P_CARDS[front_key],
			center = enhancement ~= "none" and G.P_CENTERS[enhancement] or nil,
		}, PVP.nemesis_deck, true, true, nil, false)
		if edition ~= "none" then card:set_edition({ [edition] = true }, true, true) end
		if seal ~= "none" then card:set_seal(seal, true, true) end

		-- Remove the card from G.playing_cards and insert into PVP.nemesis_cards
		table.remove(G.playing_cards, #G.playing_cards)
		table.insert(PVP.nemesis_cards, card)

		::continue::
	end
end

local function action_receive_nemesis_deck(p)
	PVP.nemesis_deck_string = p.cards
	PVP.nemesis_deck_received = true
	G.FUNCS.load_nemesis_deck()
end

-- Dual-call: dispatched from network (fromNemesis defaults to true) or self-triggered
-- by PVP.ACTIONS.start_ante_timer (passes fromNemesis = false explicitly).
local function action_start_ante_timer(p)
	if p.isPvP and (PVP.GAME.end_pvp or not PVP.is_pvp_boss() or G.GAME.current_round.hands_left <= 0) then return end

	local time = p.time
	local from_nemesis = p.fromNemesis
	if from_nemesis == nil then from_nemesis = true end

	local option = PVP.config.timersfx or 1
	local timersfx = (option == 1) or (option == 2 and G.timer_ante ~= G.GAME.round_resets.ante)
	G.timer_ante = G.GAME.round_resets.ante

	if timersfx then
		for i = 1, 3 do
			local wait_time = (0.15 * (i - 1))
			G.E_MANAGER:add_event(Event({
				blocking = false,
				blockable = false,
				trigger = "after",
				delay = G.SETTINGS.GAMESPEED * wait_time,
				func = function()
					play_sound("timpani", 0.55 + 0.25 * i, 0.7)
					play_sound("generic1", 0.75 + 0.25 * i, 0.7)
					return true
				end,
			}))
		end
	end
	-- Default timer is server-synced; pressure/no-anim/pvp timers run locally.
	if not PVP.timer_is_local() then
		if type(time) == "string" then time = tonumber(time) end
		if time then PVP.GAME.timer = time end
	end
	if from_nemesis then
		PVP.GAME.nemesis_timer_started = true
	else
		PVP.GAME.timer_started = true
	end
end

local function action_pause_ante_timer(p)
	local time = p.time
	local from_nemesis = p.fromNemesis
	if from_nemesis == nil then from_nemesis = true end

	-- Default timer is server-synced; pressure/no-anim/pvp timers run locally.
	if not PVP.timer_is_local() then
		if type(time) == "string" then time = tonumber(time) end
		if time then PVP.GAME.timer = time end
	end
	if from_nemesis then
		PVP.GAME.nemesis_timer_started = false
	else
		PVP.GAME.timer_started = false
	end
end

local function action_modded_action(p)
	local registry = PVP.MOD_ACTIONS[p.modId]
	if registry and registry[p.modAction] then registry[p.modAction](p) end
end

-- #region Client to Server
function PVP.ACTIONS.create_lobby(gamemode)
	Client.send({
		action = "createLobby",
		gameMode = gamemode,
	})
end

function PVP.ACTIONS.join_lobby(code)
	Client.send({
		action = "joinLobby",
		code = code,
	})
end

function PVP.ACTIONS.ready_lobby()
	Client.send({
		action = "readyLobby",
	})
end

function PVP.ACTIONS.unready_lobby()
	Client.send({
		action = "unreadyLobby",
	})
end

function PVP.ACTIONS.lobby_info()
	Client.send({
		action = "lobbyInfo",
	})
end

function PVP.ACTIONS.leave_lobby()
	-- Clear reconnect state on voluntary leave
	reconnectToken = nil
	lastLobbyCode = nil
	Client.send({
		action = "leaveLobby",
	})
	PVP.UTILS.emit_log_checksum()
end

function PVP.ACTIONS.start_game()
	Client.send({
		action = "startGame",
	})
end

function PVP.ACTIONS.ready_blind(e)
	PVP.GAME.next_blind_context = e
	Client.send({
		action = "readyBlind",
		startingHands = PVP.OPPONENT_SIGNALS.starting_hands(G.GAME.round_resets),
	})
end

function PVP.ACTIONS.unready_blind()
	Client.send({
		action = "unreadyBlind",
	})
end

function PVP.ACTIONS.stop_game()
	Client.send({
		action = "stopGame",
	})
end

-- Tells the referee how this client ended the current non-PvP blind. A failure
-- is sent before failRound / failTimer so the referee knows which blind a death was on.
-- `blind` (optional) names the blind when it is no longer the one on deck, as
-- after a skip.
function PVP.ACTIONS.blind_result(beaten, blind)
	local lobby = MPAPI.get_current_lobby()
	local ante = G.GAME.round_resets.ante
	blind = blind or G.GAME.blind_on_deck
	PVP.GAME.own_blind_results = PVP.GAME.own_blind_results or {}
	PVP.PendingDeath.record(PVP.GAME.own_blind_results, PVP.PendingDeath.SELF, PVP.PendingDeath.blind_key(ante, blind), beaten)
	if lobby then
		Client.send({
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
	PVP.ACTIONS.blind_result(false)
	Client.send({
		action = "failRound",
	})
end

function PVP.ACTIONS.version()
	Client.send({
		action = "version",
		version = MULTIPLAYER_VERSION,
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
	Client.send({
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
	if PVP.Score.greater(score_text, PVP.GAME.highest_score) then
		PVP.GAME.highest_score = score_text
	end
	-- §17.10: the end-of-run roster's "highest PvP-blind score" needs the
	-- PvP-blind-only figure, not the any-blind one tracked just above.
	if PVP.is_pvp_boss() and PVP.Score.greater(score_text, PVP.GAME.highest_pvp_score) then
		PVP.GAME.highest_pvp_score = score_text
	end

	-- Stop PvP timers according to score
	if PVP.is_pvp_boss() and PVP.is_layer_active("pvp_timer") then
		if PVP.Score.greater(score_text, PVP.GAME.enemy.score) then
			PVP.GAME.nemesis_timer_started = false
        elseif PVP.Score.equal(score_text, PVP.GAME.enemy.score) and PVP.GAME.pvp_reached_first then
            PVP.GAME.nemesis_timer_started = false
		else
			PVP.GAME.timer_started = false
		end
	end

	Client.send({
		action = "playHand",
		score = score_text,
		handsLeft = hands_left,
	})
end

function PVP.ACTIONS.lobby_options()
	---@type table<string, any>
	local msg = {
		action = "lobbyOptions",
	}
	for k, v in pairs(PVP.LOBBY.config) do
		msg[tostring(k)] = v
	end
	Client.send(msg)
end

function PVP.ACTIONS.set_ante(ante)
	Client.send({
		action = "setAnte",
		ante = ante,
	})
end

function PVP.ACTIONS.new_round()
	PVP.GAME.duplicate_end = false
	PVP.GAME.round_ended = false
	Client.send({
		action = "newRound",
	})
end

function PVP.ACTIONS.set_furthest_blind(furthest_blind)
	Client.send({
		action = "setFurthestBlind",
		furthestBlind = furthest_blind,
	})
end

function PVP.ACTIONS.skip(skips)
	Client.send({
		action = "skip",
		skips = skips,
	})
end

function PVP.ACTIONS.get_end_game_jokers()
	Client.send({
		action = "getEndGameJokers",
	})
end

function PVP.ACTIONS.get_nemesis_deck()
	Client.send({
		action = "getNemesisDeck",
	})
end

function PVP.ACTIONS.send_game_stats()
	Client.send({
		action = "sendGameStats",
	})
	action_send_game_stats()
end

function PVP.ACTIONS.request_nemesis_stats()
	Client.send({
		action = "endGameStatsRequested",
	})
end

function PVP.ACTIONS.announce_ante_timer(time)
	local is_pvp = PVP.is_pvp_boss() and PVP.is_layer_active("pvp_timer")
	Client.send({
		action = "startAnteTimer",
		time = time,
		isPvP = is_pvp or nil,
	})
end

-- Above the ruleset's timer threshold the opponent is told only when the timer
-- falls to it (ui/game/timer.lua's Game:update).
function PVP.ACTIONS.start_ante_timer()
	PVP.GAME.timer_threshold_pending = PVP.UTILS.timer_start_held_back(PVP.GAME.timer)
	if not PVP.GAME.timer_threshold_pending then
		PVP.ACTIONS.announce_ante_timer(PVP.GAME.timer)
	end
	action_start_ante_timer({ time = PVP.GAME.timer, fromNemesis = false })
end

function PVP.ACTIONS.pause_ante_timer()
	PVP.GAME.timer_threshold_pending = false
	Client.send({
		action = "pauseAnteTimer",
		time = PVP.GAME.timer,
	})
	action_pause_ante_timer({ time = PVP.GAME.timer, fromNemesis = false })
end

function PVP.ACTIONS.fail_timer()
	-- Out of time on the cash out after the Boss: the ante has gone up but the Boss is
	-- still on deck until cash_out resets the blinds. The Boss is the PvP, which never
	-- reports a result, so a pending death on it would wait forever. Use the next Small Blind.
	local boss_cash_out = G.GAME.blind_on_deck == "Boss" and G.GAME.round_resets.blind_states.Boss == "Defeated"
	PVP.ACTIONS.blind_result(false, boss_cash_out and "Small" or nil)
	Client.send({
		action = "failTimer",
	})
end
function PVP.ACTIONS.fail_pvp_timer()
	Client.send({
		action = "failPvPTimer",
	})
end

function PVP.ACTIONS.sync_client()
	Client.send({
		action = "syncClient",
		isCached = _RELEASE_MODE,
	})
end

-- (action_stream_log_lines / action_submit_log_hashes were removed: PVP.RLOG's
-- live transport now broadcasts each event directly via the pvp_log_event
-- MPAPI ActionType -- see pvp_api/replay_log_actions.lua and
-- lib/replay_log.lua. These TCP-era Client.send actions were already silently
-- dropped by pvp_api/net.lua's router -- unlisted actions are "owned by the
-- API now, or deferred" per its own comment -- so nothing called them.)

function PVP.ACTIONS.modded(modId, modAction, params, target)
	local msg = {
		action = "moddedAction",
		modId = modId,
		modAction = modAction,
	}
	if params then
		for k, v in pairs(params) do
			msg[k] = v
		end
	end
	if target then msg.target = target end
	Client.send(msg)
end

-- #endregion Client to Server

-- Utils
function PVP.ACTIONS.connect()
	Client.send({
		action = "connect",
	})
end

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

local last_game_seed = nil

local function noop() end

local HANDLERS = {
	connected = action_connected,
	version = action_version,
	disconnected = action_disconnected,
	reconnecting = action_reconnecting,
	joinedLobby = action_joinedLobby,
	rejoinedLobby = action_rejoinedLobby,
	enemyDisconnected = action_enemyDisconnected,
	enemyReconnected = action_enemyReconnected,
	lobbyInfo = action_lobbyInfo,
	startGame = action_start_game,
	startBlind = action_start_blind,
	stopGame = action_stop_game,
	endPvP = action_end_pvp,
	playerInfo = action_player_info,
	winGame = action_win_game,
	loseGame = action_lose_game,
	drawGame = action_draw_game,
	lobbyOptions = action_lobby_options,
	enemyLocation = enemyLocation,
	speedrun = action_speedrun,
	getEndGameJokers = action_get_end_game_jokers,
	receiveEndGameJokers = action_receive_end_game_jokers,
	getNemesisDeck = action_get_nemesis_deck,
	receiveNemesisDeck = action_receive_nemesis_deck,
	endGameStatsRequested = action_send_game_stats,
	nemesisEndGameStats = noop, -- logged only, no handler
	startAnteTimer = action_start_ante_timer,
	pauseAnteTimer = action_pause_ante_timer,
	moddedAction = action_modded_action,
	error = action_error,
	keepAlive = action_keep_alive,
}

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

function PVP.register_action(name, cb)
	if HANDLERS[name] then
		sendWarnMessage(
			"PVP.register_action: '" .. name .. "' already has a handler; refusing to register. Use PVP.register_mod_action if possible.",
			"MULTIPLAYER"
		)
		return
	end
	HANDLERS[name] = cb
end

local network_to_ui_channel = love.thread.getChannel("networkToUi")

-- Pops and decodes the next queued network message, if any:
--   nil                        no message queued (loop should stop)
--   "legacy_server", raw_msg   the pre-JSON "action:..." wire format (an outdated
--                              server) -- caller reports+disconnects and stops
--                              draining this frame's queue entirely
--   "invalid", raw_msg         message failed to json-decode
--   "ok", parsedAction         successfully decoded
local function pull_next_network_message()
	local msg = network_to_ui_channel:pop()
	if not msg then
		return nil
	end
	if string.sub(msg, 1, 1) == "a" then
		return "legacy_server", msg
	end
	local ok, parsedAction = pcall(json.decode, msg)
	if ok then
		return "ok", parsedAction
	end
	return "invalid", msg
end

local game_update_ref = Game.update
---@diagnostic disable-next-line: duplicate-set-field
function Game:update(dt)
	game_update_ref(self, dt)

	repeat
		local kind, payload = pull_next_network_message()
		if kind == "legacy_server" then
			if payload ~= "action:keepAlive" then
				local networkToUiChannel = love.thread.getChannel("networkToUi")
				networkToUiChannel:push(json.encode({
					action = "error",
					message = "Attempting to connect to outdated server",
				}))
				networkToUiChannel:push('{"action":"disconnected"}')
			end
			return
		elseif kind == "ok" then
			local parsedAction = payload
			if not ((parsedAction.action == "keepAlive") or (parsedAction.action == "keepAliveAck")) then
				local log = string.format("Client got %s message: ", parsedAction.action)
				for k, v in pairs(parsedAction) do
					if parsedAction.action == "startGame" and k == "seed" then
						last_game_seed = v
					else
						log = log .. string.format(" (%s: %s) ", k, v)
					end
				end
				if
					(parsedAction.action == "receiveEndGameJokers" or parsedAction.action == "stopGame")
					and last_game_seed
				then
					log = log .. string.format(" (seed: %s) ", last_game_seed)
				end
				sendTraceMessage(log, "MULTIPLAYER")
			end

			local handler = HANDLERS[parsedAction.action]
			if handler then handler(parsedAction) end
		elseif kind == "invalid" then
			sendWarnMessage("Invalid server response: " .. payload, "MULTIPLAYER")
		end
	until not kind
end
