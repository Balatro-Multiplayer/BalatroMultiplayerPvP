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
