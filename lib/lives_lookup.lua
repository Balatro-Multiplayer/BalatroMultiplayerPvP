-- Lives of one player as this client best knows them. Pure: every source is
-- passed in. Order: the host referee, then this client's own counter, then
-- the cache of pvp_player_lives deltas that reached this client, then the
-- lobby's starting lives.
function PVP.lives_of(player_id, sources)
	local ref_player = sources.ref_players and sources.ref_players[player_id]
	if ref_player and ref_player.lives then
		return ref_player.lives
	end
	if player_id == sources.self_id and sources.own_lives then
		return sources.own_lives
	end
	local cached = sources.cache and sources.cache[player_id]
	if cached ~= nil then
		return cached
	end
	return sources.starting_lives
end

-- The cache of pvp_player_lives broadcasts, after one more arrives. Pure: returns
-- a new table. The host sends every change to every client, so the cache holds
-- all players. A "*all*" broadcast is a match start: it replaces the cache, so a
-- rematch in the same lobby does not show the last match's lives.
function PVP.lives_cache_after(cache, params, player_ids)
	local lives = tonumber(params.lives)
	local updated = {}
	if params.player_id == "*all*" then
		for _, id in ipairs(player_ids) do
			updated[id] = lives
		end
		return updated
	end
	for id, value in pairs(cache or {}) do
		updated[id] = value
	end
	if params.player_id then
		updated[params.player_id] = lives
	end
	return updated
end
