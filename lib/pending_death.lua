-- Pure rules for a pending death in a 2-player match.
--
-- A player who loses their last life on a non-PvP blind X does not end the
-- match at once. The opponent must beat the same blind X. Beating it wins the
-- match for the opponent. Failing it is a draw. Leaving before beating it
-- makes the dead player the winner. No game state, broadcasts or UI here: the
-- referee (pvp_api/referee.lua) feeds this module and acts on the answer.

PVP.PendingDeath = {
	Outcome = { PENDING = "pending", WIN = "win", DRAW = "draw" },
	BlindResult = { BEATEN = "beaten", FAILED = "failed" },
}
local PD = PVP.PendingDeath

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
	if result == PD.BlindResult.FAILED or opponent.lives <= 0 then
		return PD.Outcome.DRAW, nil
	end
	if not opponent.present then
		return PD.Outcome.WIN, pending.player_id
	end
	return PD.Outcome.PENDING, nil
end
