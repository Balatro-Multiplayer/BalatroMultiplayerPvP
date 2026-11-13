-- Verified private lobbies. A player is "verified" when the server reports their
-- standing as verified (launched with the launcher on a ranked profile). A private
-- lobby is "verified" when every player in it is verified and its settings match a
-- standard ranked match (the Expanded ruleset). Only the Deck Mode may differ: a
-- host-picked deck or the Draft are both fine.
--
-- Cosmetic only, and not stored anywhere: every client works the verdict out from
-- the lobby's metadata (ruleset, the host's changes) and its players, so the badge
-- follows each lobby change on its own (PVP.is_verified_lobby).

-- The standard ranked (Expanded) settings. A missing config value counts as false.
PVP.VERIFIED_DEFAULTS = {
	ruleset = "ruleset_mp_expanded",
	starting_lives = 4,
	pvp_start_round = 2,
	gold_on_life_loss = true,
	no_gold_on_round_loss = false,
	death_on_round_loss = true,
	the_order = true,
	normal_bosses = false,
	preview_disabled = false,
	smallerworld = false,
	trap_cards = false,
	timer = true,
	timer_base_seconds = 150,
	timer_increment_seconds = 60,
	pvp_countdown_seconds = 3,
	different_seeds = false,
	different_decks = false,
	random_loadout = false,
	custom_seed = "random",
}

local NEMESIS_GAMEMODE = "gamemode_mp_attrition"

local function normalized(key, value)
	local want = PVP.VERIFIED_DEFAULTS[key]
	if type(want) == "boolean" then
		return value == true
	end
	if key == "custom_seed" and (value == nil or value == "") then
		return "random"
	end
	return value
end

-- Whether a lobby player (an MPAPI player_data) is verified.
function PVP.player_is_verified(player)
	if not player then
		return false
	end
	if player.standing == MPAPI.Standing.VERIFIED then
		return true
	end
	-- The local account's own launcher verdict may land before its standing echoes back.
	local is_self = PVP.self_player_id and player.id == PVP.self_player_id()
	return is_self and MPAPI.is_launcher_verified() == true or false
end

-- Pure check. Returns true, {} when the lobby is verified, else false and the
-- list of what failed (setting keys, "players", "gamemode").
function PVP.verified_lobby_check(config, players)
	local failed = {}
	if #players == 0 then
		failed[#failed + 1] = "players"
	end
	for _, player in ipairs(players) do
		if not PVP.player_is_verified(player) then
			failed[#failed + 1] = "players"
			break
		end
	end
	if config.gamemode ~= NEMESIS_GAMEMODE then
		failed[#failed + 1] = "gamemode"
	end
	local keys = {}
	for key in pairs(PVP.VERIFIED_DEFAULTS) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		if normalized(key, config[key]) ~= PVP.VERIFIED_DEFAULTS[key] then
			failed[#failed + 1] = key
		end
	end
	return #failed == 0, failed
end

-- The lobby's settings as the checks above read them: the ruleset, the gamemode,
-- the Trap cards layer, and each option as PVP.setting resolves it.
function PVP.verified_lobby_config()
	local meta = PVP.lobby_metadata()
	local config = { ruleset = meta.ruleset, gamemode = meta.gamemode, trap_cards = PVP.lobby_has_layer("traps") }
	for key in pairs(PVP.VERIFIED_DEFAULTS) do
		if config[key] == nil then
			config[key] = PVP.setting(key)
		end
	end
	config.deck_mode = PVP.setting("deck_mode")
	return config
end

-- Whether to show the Verified Lobby badge in the current private lobby.
function PVP.is_verified_lobby()
	local lobby = MPAPI.get_current_lobby()
	if not lobby or PVP._pvp_kind ~= PVP.LobbyAccess.PRIVATE then
		return false
	end
	return (PVP.verified_lobby_check(PVP.verified_lobby_config(), lobby:get_players()))
end

-- Host: put the lobby on the standard ranked ruleset with none of the host's
-- changes left, which is the verified settings. Only the Deck Mode (Select or
-- Draft) is kept, and the deck and stake picks are left alone.
function PVP.apply_verified_defaults(lobby)
	local options = { deck_mode = PVP.setting("deck_mode") }
	PVP.set_lobby_ruleset(lobby, PVP.VERIFIED_DEFAULTS.ruleset, { options = options, layers = {} })
end
