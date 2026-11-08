-- All of PvP's state, grouped by how long it lives:
--   PVP.CLIENT  while the game is open
--   PVP.LOBBY   while the player is in a lobby (PVP.end_session clears it)
--   PVP.GAME    one match (PVP.reset_game_states, from action_start_game)
-- Declare a field here before using it, even when it starts out nil; the
-- state_declared_test fails on a field that isn't.

-- The player, whatever lobby they are in. Saved in the mod config.
PVP.CLIENT = {
	username = "Guest",
	blind_col = 1,
}

PVP.LOBBY = {
	-- Where the player is.
	connected = false,
	code = nil,
	type = "",
	is_host = false,
	ready_to_start = false,
	-- Who else is here: { username, blind_col, id } for the 1v1 slots, the
	-- whole lobby's player id -> role for the rest.
	host = {},
	guest = {},
	roster = nil,
	team_id = nil,
	players = nil, -- Legacy server lobbyInfo only.
	-- The deck this player plays. Copied from the host's (config.back etc.)
	-- unless different_decks is on (G.FUNCS.copy_host_deck).
	deck = {
		back = "Red Deck",
		sleeve = "sleeve_casl_none",
		stake = 1,
		challenge = "",
		cocktail = nil,
		cocktail_recipe = nil,
	},
	config = {}, -- PVP.reset_lobby_config
}

-- The lobby settings the host shares through the lobby metadata
-- (PVP.pvp_lobby_metadata), and their types. These are the only metadata keys
-- that set PVP.LOBBY.config; every other config value comes from the defaults
-- below, the ruleset, or the gamemode.
PVP.SHARED_LOBBY_SETTINGS = {
	gamemode = "string",
	ruleset = "string",
	starting_lives = "number",
	pvp_start_round = "number",
	manhunt_hunter_lives = "number",
	trap_cards = "boolean",
	stake = "number",
}

function PVP.reset_lobby_config(persist_ruleset_and_gamemode)
	PVP.match_log("debug", "Resetting lobby options")
	PVP.LOBBY.config = {
		-- Shared by the host (PVP.SHARED_LOBBY_SETTINGS).
		ruleset = persist_ruleset_and_gamemode and PVP.LOBBY.config.ruleset or "ruleset_mp_expanded",
		gamemode = persist_ruleset_and_gamemode and PVP.LOBBY.config.gamemode or "gamemode_mp_attrition",
		starting_lives = 4,
		pvp_start_round = 2,
		-- Manhunt only: each Hunter's individual life count (Runner is always
		-- fixed at 1, not configurable -- see PVP.referee_reset).
		manhunt_hunter_lives = 7,
		-- Private lobbies only: the host's Lobby Options switch for the "traps" modifier.
		trap_cards = false,

		-- The host's deck. Everyone plays it unless different_decks is on.
		back = "Red Deck",
		sleeve = "sleeve_casl_none",
		stake = 1,
		challenge = "",
		cocktail = "",

		-- Rules. Every client starts from these; a ranked or private lobby's
		-- ruleset forces some of them the same way on every client
		-- (PVP.force_lobby_options).
		gold_on_life_loss = true,
		no_gold_on_round_loss = false,
		death_on_round_loss = true,
		the_order = true,
		multiplayer_jokers = true,
		preview_disabled = false,
		legacy_smallworld = false,
		timer = true,
		timer_base_seconds = 150,
		timer_increment_seconds = 60,
		timer_forgiveness = 0,
		pvp_countdown_seconds = 3,
		different_seeds = false,
		custom_seed = "random",
		different_decks = false,
		random_loadout = false,

		-- Worked out on every client from the lobby's gamemode and ruleset
		-- (pvp_api/lobby_bridge.lua), never chosen by the host.
		team_based = nil,
		manhunt = nil,
		nemesis_pairing = nil,
		modifier_layers = nil,

		-- Read with a fallback to the ruleset's or a layer's value. Nothing sets
		-- these since the legacy server's lobbyOptions went away.
		normal_bosses = nil,
		disable_live_and_timer_hud = nil,
		preview_calculate_cost = nil,
		preview_calculate_delay = nil,
		pvp_timer_base_seconds = nil,
		timer_hand_played_increment_seconds = nil,
		pvp_timer_hand_played_increment_seconds = nil,
	}
end

local function coerce(value, kind)
	if kind == "number" then return tonumber(value) end
	if kind == "boolean" and type(value) == "string" then return value == "true" end
	return value
end

-- Lobby metadata keys that aren't settings: pvp_api/lobby_bridge.lua reads
-- deck, kind, queue_mode and cocktail_recipe itself, and keys starting with "_"
-- belong to MPAPI or the referee.
local NOT_SETTINGS = { deck = true, kind = true, queue_mode = true, cocktail_recipe = true }
local warned = {}

-- Copies one lobby metadata entry into PVP.LOBBY.config. An unknown key is
-- still copied, with a warning, until we know no live lobby sends one.
function PVP.apply_lobby_setting(key, value)
	local kind = PVP.SHARED_LOBBY_SETTINGS[key]
	if kind then
		PVP.LOBBY.config[key] = coerce(value, kind)
		return
	end
	if NOT_SETTINGS[key] or tostring(key):sub(1, 1) == "_" then return end
	if not warned[key] then
		warned[key] = true
		sendWarnMessage("Lobby metadata has an unknown setting: " .. tostring(key), "MULTIPLAYER")
	end
	PVP.LOBBY.config[key] = value
end

PVP.GAME = {} -- PVP.reset_game_states

function PVP.reset_game_states()
	PVP.match_log("debug", "Resetting game states")
	-- §17.10: fresh per-match roster collection -- must not carry over from
	-- whatever match (if any) this player was previously in.
	PVP._collected_results = {}
	-- Players who started the match (lib/match_players.lua); set by action_start_game.
	PVP._match_players = nil
	PVP.GAME = {
		-- Lives and progress.
		lives = 0,
		timers_forgiven = 0,
		comeback_bonus = 0,
		comeback_bonus_given = true,
		furthest_blind = 0,
		highest_score = PVP.Score.ZERO,
		-- §17.10: PVP.GAME.highest_score above tracks the best SINGLE-BLIND
		-- score of any kind (updated unconditionally in every play_hand,
		-- including plain Small/Big/Boss blinds) -- not what the end-of-run
		-- roster needs ("highest PvP-blind score"). Tracked separately here,
		-- only updated while PVP.is_pvp_boss() is true.
		highest_pvp_score = PVP.Score.ZERO,
		antes_keyed = {},
		skips_before_pvp = 0,
		skips_difference = 0,
		spent_total = 0,
		spent_before_shop = 0,
		stats = {
			reroll_count = 0,
			reroll_cost_total = 0,
			-- Add more stats here in the future
		},

		-- Ante timer.
		ante_key = tostring(math.random()),
		timer = PVP.UTILS.timer_base(),
		timer_started = false,
		nemesis_timer_started = false,
		timer_threshold_pending = false,
		timer_consumed = false,

		-- The current blind.
		score = nil, -- This player's latest hand score (PVP.ACTIONS.play_hand).
		round_sync = nil, -- pvp_api/round_sync.lua
		own_blind_results = nil, -- This player's beaten blinds (PVP.PendingDeath.record).
		round_ended = false,
		duplicate_end = false,
		next_blind_context = nil,
		pvp_reached = false,
		pvp_reached_first = false,
		pvp_countdown = 0,
		pvp_countdown_in_progress = nil,

		-- Set by one event, then consumed and cleared by a Game:update_* hook
		-- (ui/game/game_state.lua) or a button.
		end_pvp = false,
		prevent_eval = false,
		ready_blind = false,
		ready_blind_text = localize("b_ready"),

		-- Who this player's multiplayer jokers and PvP blind target, per gamemode.
		royale_target_id = nil,
		royale_target_safe = nil,
		nemesis_partner_id = nil,
		nemesis_pairing_received = false,
		manhunt_target_id = nil,
		team_card_target_id = nil,
		team_lives = nil, -- Team id -> lives.

		-- How the match ended for this player.
		won = false,
		draw = false,
		contested = false,
		eliminated = false,
		pending_death = nil, -- { player_id, opponent_id, blind_key }
		pending_deaths = nil, -- Player id -> blind key.
		pending_death_screen = false,
		team_pending = nil, -- { team_id, blind_key }
		result_held = false,
		result_handled = false,

		-- Where this player is, as "<loc key>-<blind>" (PVP.ACTIONS.set_location).
		location = "loc_selecting",
		location_type = nil,
		location_blind = nil,
		location_full = nil,

		-- Joker memory.
		asteroids = 0,
		pizza_discards = 0,
		pincher_index = -3,
		pincher_unlock = false,
		misprint_display = "",

		-- lovely/ce.toml's money check.
		real_money = 0,
		ce_cache = false,

		-- The opponent this player faces.
		enemy = {
			lives = PVP.LOBBY.config.starting_lives,
			highest_score = PVP.Score.ZERO,
			skips = 0,
			skips_before_pvp = 0,
			skips_from = nil, -- Player id the skips count came from.
			skips_resync = nil, -- True after a rejoin until the next skips update.
			-- Their shop, for Taxes and Penny Pincher (lib/opponent_record.lua).
			sells = 0,
			sells_per_ante = {},
			spent_in_shop = {},
			-- Their current blind.
			score = PVP.Score.ZERO,
			real_score = PVP.Score.ZERO,
			score_text = PVP.Score.ZERO,
			score_ease = nil, -- The blind HUD's score count-up in progress.
			score_label = nil,
			hands = 4,
			hands_text = "4",
			-- Whether an enemyInfo message has arrived this blind.
			info_received = false,
			-- Where they are.
			location = localize("loc_selecting"),
			location_type = nil,
			location_blind = nil,
			location_full = nil,
			-- " (catching up)" while the target is replaying its run after a crash, else "".
			catching_up_text = "",
		},
	}
end
