-- Who started the match. The end screen lists these players, not whoever is
-- still in the lobby, so a player who left or forfeited keeps their entry (and
-- their jokers, if their roster arrived before they went).
-- Pure data helpers: no game globals, so they run under a plain luajit stub.

PVP.MATCH_PLAYERS = {}

PVP.MATCH_PLAYERS.State = { ROSTER = "roster", LEFT = "left", PLAYING = "playing" }

-- Plain copy of the lobby members at match start: {id, displayName} each.
function PVP.MATCH_PLAYERS.snapshot(lobby_players)
	local snap = {}
	for _, p in ipairs(lobby_players or {}) do
		snap[#snap + 1] = { id = p.id, displayName = p.displayName }
	end
	return snap
end

-- State.ROSTER: their jokers are known (the final roster, or for a player who is
-- gone, the last interim roster seen). State.LEFT: no roster and no longer in
-- the lobby. State.PLAYING: still here, no final roster yet. A roster that arrived
-- before the player left wins over State.LEFT. An interim roster (sent when the
-- player left the shop) never marks a present player as done.
function PVP.MATCH_PLAYERS.state(player_id, present_ids, result)
	local has_jokers = result and result.jokers
	if has_jokers and not result.interim then
		return PVP.MATCH_PLAYERS.State.ROSTER
	end
	if present_ids and present_ids[player_id] then
		return PVP.MATCH_PLAYERS.State.PLAYING
	end
	if has_jokers then
		return PVP.MATCH_PLAYERS.State.ROSTER
	end
	return PVP.MATCH_PLAYERS.State.LEFT
end

-- Set of ids of the players now in the lobby.
function PVP.MATCH_PLAYERS.present_set(lobby_players)
	local set = {}
	for _, p in ipairs(lobby_players or {}) do
		set[p.id] = true
	end
	return set
end
