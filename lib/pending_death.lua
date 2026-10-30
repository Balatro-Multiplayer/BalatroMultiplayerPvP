-- Pure rules for a pending death in a match of 2 players or more.
--
-- A player who loses their last life on a non-PvP blind X does not end the
-- match at once. The opponent must beat the same blind X. Beating it (or
-- skipping it, which the client reports as beaten) wins the match for the
-- opponent. Failing it wins for the opponent too if they still have lives
-- left, and is a draw if it cost their last one. Leaving before beating it
-- makes the dead player the winner. No game state, broadcasts or UI here: the
-- referee (pvp_api/referee.lua) feeds this module and acts on the answer.

PVP.PendingDeath = {
	Outcome = { PENDING = "pending", WIN = "win", DRAW = "draw" },
	BlindResult = { BEATEN = "beaten", FAILED = "failed" },
}
local PD = PVP.PendingDeath

-- The key under which a client files its own blind results (PVP.GAME.own_blind_results).
PD.SELF = "me"

-- One non-PvP blind: its ante and its slot ("Small", "Big" or "Boss").
function PD.blind_key(ante, blind)
	return tostring(ante) .. ":" .. tostring(blind)
end

-- results[player_id][blind_key] = BlindResult. A failure is final: failing a
-- blind (a lost life, a timer) is not undone by beating it afterwards.
function PD.record(results, player_id, blind_key, beaten)
	results[player_id] = results[player_id] or {}
	if results[player_id][blind_key] == PD.BlindResult.FAILED then
		return results
	end
	results[player_id][blind_key] = beaten and PD.BlindResult.BEATEN or PD.BlindResult.FAILED
	return results
end

-- pending = { player_id, blind_key }: the dead player and the blind they died on.
-- opponent = { present, lives }: whether the opponent is still in the match and
-- their lives left. Returns outcome, winner_id (winner_id only for a win).
function PD.decide(pending, opponent_id, results, opponent)
	local result = results[opponent_id] and results[opponent_id][pending.blind_key]
	if result == PD.BlindResult.BEATEN then
		return PD.Outcome.WIN, opponent_id
	end
	if opponent.lives <= 0 then
		return PD.Outcome.DRAW, nil
	end
	if result == PD.BlindResult.FAILED then
		-- Failing the blind costs a life; one who still has lives left wins.
		return PD.Outcome.WIN, opponent_id
	end
	if not opponent.present then
		return PD.Outcome.WIN, pending.player_id
	end
	return PD.Outcome.PENDING, nil
end

-- Matches of 3 or more players (Royale, Nemesis pairing). Several pending
-- deaths can exist at once, one per dead player.
-- pending = { player_id, blind_key, out_before } where out_before[id] is true for
-- every player already out of lives when this one died.
function PD.find_pending(pendings, player_id)
	for _, pending in ipairs(pendings) do
		if pending.player_id == player_id then
			return pending
		end
	end
	return nil
end

-- Adds a pending death for player_id once. Returns the list.
function PD.add_pending(pendings, player_id, blind_key, out_before)
	if not PD.find_pending(pendings, player_id) then
		pendings[#pendings + 1] = { player_id = player_id, blind_key = blind_key, out_before = out_before or {} }
	end
	return pendings
end

local function has_result(results, player_id, blind_key)
	return results[player_id] ~= nil and results[player_id][blind_key] ~= nil
end

-- roster[id] = { present, lives }. True when every pending death has heard from
-- every other player: a result for its blind, elimination or leaving.
function PD.many_resolved(pendings, results, roster)
	for _, pending in ipairs(pendings) do
		for id, state in pairs(roster) do
			if
				id ~= pending.player_id
				and state.present
				and state.lives > 0
				and not has_result(results, id, pending.blind_key)
			then
				return false
			end
		end
	end
	return true
end

-- Places for ids once the result is final: places[id], tied players share a
-- place, the next place skips the tied count (1, 2, 2, 4). A player ranks by a
-- key, lower is better. The last survivor starts at 0 and everyone else at 1. A
-- player who died on a blind or failed it moves to 1 plus the number of such
-- blinds, which is where the dead player sits. A player who was out before a
-- death (or left without a result for its blind) drops 2 more for each such death.
function PD.places(ids, pendings, results, roster)
	local keys = {}
	for _, id in ipairs(ids) do
		local state = roster[id] or { present = false, lives = 0 }
		local key = (state.present and state.lives > 0) and 0 or 1
		local involved, dropped = 0, 0
		for _, pending in ipairs(pendings) do
			local result = results[id] and results[id][pending.blind_key]
			if id == pending.player_id or result == PD.BlindResult.FAILED then
				involved = involved + 1
			elseif result == nil and (pending.out_before[id] or not state.present) then
				dropped = dropped + 1
			end
		end
		if involved > 0 then
			key = math.max(key, 1 + involved)
		end
		keys[id] = key + 2 * dropped
	end
	local places = {}
	for _, id in ipairs(ids) do
		local better = 0
		for _, other in ipairs(ids) do
			if keys[other] < keys[id] then
				better = better + 1
			end
		end
		places[id] = 1 + better
	end
	return places
end

-- Manhunt and Teams: a whole side is pending (the Runner, or a team whose shared
-- lives reached 0) on blind_key. The players of the other side must beat the same
-- blind. roster[id] = { present, lives } for the other side only. WIN means the
-- other side wins: any one of its players beat the blind. DRAW means every one of
-- them failed it, is out of lives or has left without beating it.
function PD.decide_team(blind_key, results, roster)
	local open_player = false
	for id, state in pairs(roster) do
		local result = results[id] and results[id][blind_key]
		if result == PD.BlindResult.BEATEN then
			return PD.Outcome.WIN, nil
		end
		if result == nil and state.present and state.lives > 0 then
			open_player = true
		end
	end
	return open_player and PD.Outcome.PENDING or PD.Outcome.DRAW, nil
end
