-- Lives of one player as this client best knows them. Pure: every source is
-- passed in. The cache of the server's pvp.lives state is the only source, for
-- this client too; a player without an entry is unknown (nil), never a guess.
function PVP.lives_of(player_id, sources)
	return sources.cache and sources.cache[player_id]
end

-- A lives count for people; an unknown one shows as "???", like the opponent's score.
function PVP.lives_text(lives)
	if lives == nil then
		return "???"
	end
	return tostring(lives)
end

-- The opponent lives the HUD shows beside your own. Pure: `sources` is
-- PVP.lives_of's, plus player_ids (the lobby's players) and nemesis_id (your
-- nemesis this ante, or nil). With a nemesis it is your nemesis's lives;
-- otherwise (other gamemodes, a bye, before the first pairing) it is the
-- highest lives of the other players. nil when none is known.
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
	return highest
end

-- Whether a player is out of the run (0 or fewer lives). nil when the server's cache has no
-- entry for them: unknown is neither alive nor out.
function PVP.lives_out(cache, player_id)
	local lives = PVP.lives_of(player_id, { cache = cache })
	if lives == nil then
		return nil
	end
	return lives <= 0
end

-- The Defensive Joker's chips: `chips` for each life the enemy has over you, never below 0.
-- 0 when either count is unknown.
function PVP.defensive_bonus(enemy_lives, own_lives, chips)
	if enemy_lives == nil or own_lives == nil then
		return 0
	end
	return math.max((enemy_lives - own_lives) * chips, 0)
end
