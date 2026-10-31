-- Card-info provider for MPAPI's Lobby Info overlay (see
-- BalatroMultiplayerAPI/api/card_info_providers.lua): every lobby shows the
-- player's lives, ranked lobbies also show Elo, and during a run the
-- player's skips and best PvP score where known (see run_rows).
--
-- Cached per (gamemode, player) since MPAPI.matchmaking.get_rating is an
-- async network call and hover callbacks must return synchronously: the
-- first hover with no cache entry fires the lookup in the background and
-- shows a placeholder immediately, a later hover shows the resolved value.
PVP._rating_cache = PVP._rating_cache or {}

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

	return text_row("Elo: " .. tostring(cached.rating or "Placement"))
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

-- Skips and best PvP score: our own come from G.GAME/PVP.GAME. An opponent's
-- only exist as PVP.GAME.enemy, which is never reset when the target changes,
-- so it is that player's own numbers only in a two-player, non-Teams lobby.
-- Anyone else gets no rows rather than another player's numbers.
local function run_rows(lobby, player_data, rows)
	if G.STAGE ~= G.STAGES.RUN or not PVP.GAME or PVP.is_practice_mode() then return end
	local skips, best_score
	if player_data.id == PVP.self_player_id() then
		skips, best_score = G.GAME.skips, PVP.GAME.highest_pvp_score
	elseif #lobby:get_players() == 2 and not PVP.LOBBY.config.team_based then
		skips, best_score = PVP.GAME.enemy.skips, PVP.GAME.enemy.highest_score
	else
		return
	end
	rows[#rows + 1] = text_row(tostring(skips or 0) .. " " .. localize("k_skips"))
	rows[#rows + 1] = text_row(localize("k_best_pvp_score") .. ": " .. PVP.Score.display(best_score))
end

MPAPI.register_card_info_provider(PVP.id, function(lobby, player_data)
	local rows = { lives_row(player_data) }
	run_rows(lobby, player_data, rows)
	local meta = lobby:get_metadata() or {}
	if meta.kind == PVP.LobbyAccess.RANKED then
		rows[#rows + 1] = elo_row(lobby, player_data)
	end
	return rows
end)
