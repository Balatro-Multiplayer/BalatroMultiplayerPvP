-- Card-info provider for MPAPI's Lobby Info overlay (see
-- BalatroMultiplayerAPI/api/card_info_providers.lua): every lobby shows the
-- player's lives, ranked lobbies also show Elo (or placement progress for a
-- player still in their placement games, whose rating isn't shown yet).
--
-- Cached per (gamemode, player) since MPAPI.matchmaking.get_rating is an
-- async network call and hover callbacks must return synchronously: the
-- first hover with no cache entry fires the lookup in the background and
-- shows a placeholder immediately, a later hover shows the resolved value.
-- The cache belongs to one lobby, so the next match reads ratings afresh.
PVP._rating_cache = PVP._rating_cache or {}

-- Matches the server's PLACEMENT_GAMES, for a server that doesn't send it.
local DEFAULT_PLACEMENT_GAMES = 5

local function text_row(text)
	return { n = G.UIT.R, config = { align = "cm", padding = 0.03 }, nodes = {
		{ n = G.UIT.T, config = { text = text, scale = 0.35, colour = G.C.UI.TEXT_DARK } },
	} }
end

local function elo_row(lobby, player_data)
	local meta = lobby:get_metadata() or {}
	local gamemode = meta.gamemode
	if not gamemode then
		return text_row("Elo: N/A")
	end

	if PVP._rating_cache_lobby ~= lobby.code then
		PVP._rating_cache = {}
		PVP._rating_cache_lobby = lobby.code
	end

	local cache_key = gamemode .. ":" .. player_data.id
	local cached = PVP._rating_cache[cache_key]

	if cached == nil then
		PVP._rating_cache[cache_key] = false -- in-flight marker, avoids re-firing on every hover
		MPAPI.matchmaking.get_rating(PVP.id, gamemode, nil, player_data.id, function(err, data)
			if err then
				PVP._rating_cache[cache_key] = nil -- allow a retry on the next hover
				return
			end
			PVP._rating_cache[cache_key] = data or { rating = nil }
		end)
		return text_row("Elo: ...")
	end

	if cached == false then
		return text_row("Elo: ...")
	end

	if cached.isPlacement or not cached.rating then
		local total = tonumber(cached.placementGames) or DEFAULT_PLACEMENT_GAMES
		local played = math.min(tonumber(cached.gamesPlayed) or 0, total)
		return text_row(localize({ type = "variable", key = "k_pvp_placement_progress", vars = { played, total } }))
	end

	return text_row("Elo: " .. tostring(math.floor(cached.rating + 0.5)))
end

local function lives_row(player_data)
	local lives = PVP.lives_of(player_data.id, {
		ref_players = PVP.REF and PVP.REF.players,
		self_id = PVP.self_player_id(),
		own_lives = PVP.GAME and PVP.GAME.lives,
		cache = PVP._player_lives_cache,
		starting_lives = PVP.LOBBY.config.starting_lives,
	})
	return text_row(tostring(lives) .. " " .. localize("k_lives"))
end

MPAPI.register_card_info_provider(PVP.id, function(lobby, player_data)
	local rows = { lives_row(player_data) }
	local meta = lobby:get_metadata() or {}
	if meta.kind == PVP.LobbyAccess.RANKED then
		rows[#rows + 1] = elo_row(lobby, player_data)
	end
	return rows
end)
