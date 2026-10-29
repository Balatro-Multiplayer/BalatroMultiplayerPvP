-- Outgoing transport bridge.
--
-- The whole PVP codebase emits network messages through Client.send({action=..., ...})
-- (defined in networking/action_handlers.lua). In the old model those went to the
-- TCP server, which relayed/transformed them to the opponent. Here we override
-- Client.send to translate each legacy message into the equivalent pvp_* ActionType
-- broadcast over the API lobby (see actions.lua). All the per-action LOCAL work in
-- PVP.ACTIONS.* still runs unchanged; only the transport + the server's transforms
-- move here.
--
-- Loaded inside MPAPI.on_loaded, after action_handlers.lua, so this override wins.

-- Only PvP's own lobby: PvP code on vanilla hooks (skip_blind, set_location,
-- ...) can fire while the player sits in another mod's lobby.
local function lobby()
	local current = MPAPI.get_current_lobby()
	if current and current.mod_id == PVP.id then
		return current
	end
	return nil
end

local function broadcast(key, params)
	local l = lobby()
	if l and MPAPI.ActionTypes[key] then
		l:action(MPAPI.ActionTypes[key]):broadcast(params or {})
	end
end

-- Local player's live game state, for payloads the old server used to fill in.
local function my_score_str()
	return PVP.Score.or_zero(PVP.GAME.score)
end
local function my_hands()
	return (G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left) or 0
end
local function my_skips()
	return (G.GAME and G.GAME.skips) or 0
end
local function my_lives()
	return PVP.GAME.lives or 0
end

-- Tell the opponent our hands/skips/lives. Goes through the Nemesis blind's own
-- sync, not MPAPI.calculate_blind: that only reaches the blind we are on now, which
-- is not Nemesis at blind start or skip.
local function relay_enemy_info(payload)
	local nemesis = G.P_BLINDS and G.P_BLINDS.bl_mp_nemesis
	if nemesis then nemesis:sync(payload) end
end

local function gen_seed()
	local cfg = PVP.LOBBY.config
	if cfg.custom_seed and cfg.custom_seed ~= "random" and cfg.custom_seed ~= "" then
		return cfg.custom_seed
	end
	return PVP.generate_seed()
end

-- Map each legacy action to its peer broadcast. Anything not listed (lobby/auth/
-- version/replay-stream actions the API now owns) is silently dropped.
local ROUTES = {
	startGame = function(_msg)
		-- Host generates the shared seed and starts everyone (host included via loopback).
		local seed = gen_seed()
		local stake = PVP.LOBBY.deck.stake or PVP.LOBBY.config.stake or 1
		-- Mirrored into lobby metadata (persisted server-side, returned again in
		-- context.reconnected_lobby.metadata on a crash-relaunch reconnect --
		-- see ui/reconnect_prompt.lua in BalatroMultiplayerAPI): the action
		-- broadcast below only ever reaches clients connected at the moment it
		-- fires.
		local l = lobby()
		if l and l.is_host then
			l:set_metadata({ _mp_pending_seed = seed, _mp_pending_stake = stake })
		end
		broadcast("pvp_start_game", { seed = seed, stake = tostring(stake) })
	end,
	stopGame = function(_msg)
		broadcast("pvp_stop_game", {})
	end,
	readyBlind = function(msg)
		broadcast("pvp_ready_blind", { starting_hands = msg.startingHands })
	end,
	unreadyBlind = function(_msg)
		broadcast("pvp_unready_blind", {})
	end,
	failRound = function(_msg)
		broadcast("pvp_fail_round", {})
	end,
	failTimer = function(_msg)
		broadcast("pvp_fail_timer", {})
	end,
	blindResult = function(msg)
		broadcast("pvp_blind_result", { ante = msg.ante, blind = msg.blind, beaten = msg.beaten })
	end,
	failPvPTimer = function(_msg)
		broadcast("pvp_fail_pvp_timer", {})
	end,
	setLocation = function(msg)
		broadcast("pvp_location", { location = msg.location })
	end,
	playHand = function(msg)
		broadcast("pvp_play_hand", { score = msg.score, handsLeft = msg.handsLeft, skips = my_skips(), lives = my_lives() }) -- referee (host-authoritative)
		-- Score-bearing RLOG event: this is the only point in the codebase
		-- where "my own score after playing" is already computed for the
		-- legacy broadcast, so it doubles as the carbon-log source for this
		-- hand's result. Carbon-only -- no human-line equivalent exists.
		-- Recorded BEFORE calculate_blind: calculate_blind can synchronously
		-- decide this hand ends the match (action_win_game/action_lose_game),
		-- which calls RLOG.end_run and flips RLOG._run_active to false --
		-- recording after that point silently drops the decisive hand's own
		-- result (confirmed live: END/CHK trailer landed right after this
		-- hand's `play` opcode with no `hand_result` in between).
		if PVP.RLOG then PVP.RLOG.record(MPAPI.OPCODE.HAND_RESULT, { tostring(msg.score), msg.handsLeft }) end
		relay_enemy_info({ score = msg.score, handsLeft = msg.handsLeft, skips = my_skips(), lives = my_lives() })
	end,
	setAnte = function(msg)
		broadcast("pvp_set_ante", { ante = msg.ante })
	end,
	newRound = function(_msg)
		broadcast("pvp_new_round", {})
	end,
	setFurthestBlind = function(msg)
		broadcast("pvp_set_furthest_blind", { furthestBlind = msg.furthestBlind })
	end,
	skip = function(msg)
		broadcast("pvp_skip", { skips = msg.skips, score = my_score_str(), handsLeft = my_hands(), lives = my_lives() }) -- referee (host-authoritative)
		-- See playHand's hand_result comment above -- same rationale, for discards:
		-- recorded BEFORE the relay so a match-ending skip still logs.
		if PVP.RLOG then PVP.RLOG.record(MPAPI.OPCODE.HAND_RESULT, { my_score_str(), my_hands() }) end
		relay_enemy_info({ score = my_score_str(), handsLeft = my_hands(), skips = msg.skips, lives = my_lives() })
	end,
	startAnteTimer = function(msg)
		broadcast("pvp_ante_timer", { time = msg.time, isPvP = msg.isPvP })
	end,
	pauseAnteTimer = function(msg)
		broadcast("pvp_pause_ante_timer", { time = msg.time })
	end,
	getEndGameJokers = function(_msg)
		broadcast("pvp_get_end_game_jokers", {})
	end,
	receiveEndGameJokers = function(msg)
		broadcast("pvp_receive_end_game_jokers", msg)
	end,
	getNemesisDeck = function(_msg)
		broadcast("pvp_get_nemesis_deck", {})
	end,
	receiveNemesisDeck = function(msg)
		broadcast("pvp_receive_nemesis_deck", msg)
	end,
	sendGameStats = function(_msg) end, -- local-only (handled by action_send_game_stats)
	endGameStatsRequested = function(_msg)
		broadcast("pvp_end_game_stats_requested", {})
	end,
	nemesisEndGameStats = function(msg)
		broadcast("pvp_nemesis_end_game_stats", msg)
	end,
}

function PVP.net_route(msg)
	if type(msg) ~= "table" or not msg.action then
		return
	end
	local route = ROUTES[msg.action]
	if route then
		route(msg)
	end
	-- Unlisted actions (createLobby/joinLobby/readyLobby/leaveLobby/username/version/
	-- lobbyInfo/lobbyOptions/syncClient) are owned by the API now; drop them.
	-- (streamLogLines/submitLogHashes used to be unlisted here too -- RLOG's
	-- transport now broadcasts directly via the pvp_log_event MPAPI ActionType,
	-- see pvp_api/replay_log_actions.lua, not through this legacy router at all.)
end

-- Replace the socket transport with the peer router. Client is the global table
-- defined in networking/action_handlers.lua.
if Client then
	Client.send = function(msg)
		PVP.net_route(msg)
	end
end
