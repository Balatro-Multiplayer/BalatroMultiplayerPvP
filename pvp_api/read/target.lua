-- Who the match points me at, read from the view's run.targets. Pure: plain values in, plain values out,
-- no game and no net. pvp_api/ui/target.lua is the shell that hands it the view. With no view, no run or no
-- targets in it the answer is nil / empty: unknown is never read as "nobody" or as a bye.
local reader = {}
PVP.READ.target = reader

local function targets_of(view)
	local run = PVP.READ.view.run(view)
	return run and run.targets
end

-- The player my score and my cards point at, or nil. Teams reads the card target; every other mode
-- reads the opponent.
function reader.target_id(view, team_based)
	local targets = targets_of(view)
	local ids = targets and (team_based and targets.cardTargets or targets.opponents)
	return type(ids) == "table" and ids[1] or nil
end

-- Every player a card of mine reaches: one in most modes, every hunter for a Manhunt Runner. Empty
-- while unknown.
function reader.card_target_ids(view)
	local targets = targets_of(view)
	local ids = {}
	for _, id in ipairs(targets and targets.cardTargets or {}) do
		ids[#ids + 1] = id
	end
	return ids
end

local DECIDED_BOSS = {
	["no pvp this ante"] = true,
	["bye"] = true,
	["plays"] = true,
}

-- The server's own answer about my Boss (targets.myBoss): "no pvp this ante", "bye" or "plays", or "unknown"
-- while unknown or there is no view. An empty opponent list is not a bye: a partner who is out empties it
-- too. The answer is about the ante the server has me on, so it is unknown while that is not the ante
-- the game is building.
function reader.boss_of(view, game_ante)
	local run = PVP.READ.view.run(view)
	local mine = run and type(run.players) == "table" and run.players[view.me]
	if not (type(mine) == "table" and mine.ante ~= nil and mine.ante == game_ante) then return "unknown" end
	local targets = targets_of(view)
	local boss = targets and targets.myBoss
	if DECIDED_BOSS[boss] then return boss end
	return "unknown"
end

-- The localization key of the enemy-score label. Royale tells me what the shown target's score means:
-- "Leading" while I am above the cut, "Beat" while I am below it. Every other mode, and Royale with no
-- target or with no cut ("no cut", or none sent), keeps the plain label.
function reader.score_label_key(view, royale)
	local targets = targets_of(view)
	local cut = royale and targets and reader.target_id(view, false) and targets.cut
	if cut == "above the cut" then return "k_royale_leading" end
	if cut == "below the cut" then return "k_royale_beat" end
	return "k_enemy_score"
end

return reader
