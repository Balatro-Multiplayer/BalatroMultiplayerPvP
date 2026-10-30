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

-- The opponent lives the HUD shows beside your own. Pure: `sources` is
-- PVP.lives_of's, plus player_ids (the lobby's players) and nemesis_id (your
-- nemesis this ante, or nil). With a nemesis it is your nemesis's lives;
-- otherwise (other gamemodes, a bye, before the first pairing) it is the
-- highest lives of the other players.
function PVP.shown_opponent_lives(sources)
	if sources.nemesis_id then
		return PVP.lives_of(sources.nemesis_id, sources)
	end
	local highest = nil
	for _, id in ipairs(sources.player_ids or {}) do
		local lives = id ~= sources.self_id and tonumber(PVP.lives_of(id, sources)) or nil
		if lives and (highest == nil or lives > highest) then
			highest = lives
		end
	end
	return highest or sources.starting_lives
end
