-- Verified private lobbies. A player is "verified" when the server reports their
-- standing as verified (launched with the launcher on a ranked profile). A private
-- lobby is "verified" when every player in it is verified and its settings match a
-- standard ranked match (the Expanded ruleset). Only the Deck Mode may differ: a
-- host-picked deck or the Draft are both fine.
--
-- Cosmetic only: the host's client computes the flag and publishes it in the lobby
-- metadata (PVP.pvp_lobby_metadata), so every client shows the same badge. It is
-- recomputed on every lobby change (PVP.refresh_verified_lobby).

-- The standard ranked (Expanded) settings. A missing config value counts as false.
PVP.VERIFIED_DEFAULTS = {
	ruleset = "ruleset_mp_expanded",
	starting_lives = 4,
	pvp_start_round = 2,
	gold_on_life_loss = true,
	no_gold_on_round_loss = false,
	death_on_round_loss = true,
	the_order = true,
	multiplayer_jokers = true,
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

-- The verdict for the current private lobby, read from live state (host only
-- computes it; guests read the mirrored PVP.LOBBY.config.verified_lobby).
function PVP.compute_verified_lobby(lobby)
	lobby = lobby or MPAPI.get_current_lobby()
	if not lobby then
		return false
	end
	return (PVP.verified_lobby_check(PVP.LOBBY.config, lobby:get_players()))
end

-- Whether to show the Verified Lobby badge (the host's published verdict).
function PVP.is_verified_lobby()
	return PVP.LOBBY.config.verified_lobby == true and PVP._pvp_kind == PVP.LobbyAccess.PRIVATE
end

-- Host: republish the metadata when the verdict moved, e.g. a player joined, left or
-- changed standing. Settings changes republish on their own and carry the new verdict.
function PVP.refresh_verified_lobby(lobby)
	lobby = lobby or MPAPI.get_current_lobby()
	if not (lobby and lobby.is_host) or PVP._pvp_kind ~= PVP.LobbyAccess.PRIVATE then
		return
	end
	local now = PVP.compute_verified_lobby(lobby)
	if now ~= (PVP.LOBBY.config.verified_lobby == true) then
		lobby:set_metadata(PVP.pvp_lobby_metadata(PVP._pvp_gamemode, PVP._pvp_kind))
	end
end

-- Host: put every setting that matters to verification at the standard ranked value.
-- The deck and stake picks are left alone.
function PVP.apply_verified_defaults()
	for key, value in pairs(PVP.VERIFIED_DEFAULTS) do
		PVP.LOBBY.config[key] = value
	end
	PVP.LOBBY.config.gamemode = NEMESIS_GAMEMODE
end
