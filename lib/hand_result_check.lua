-- The replay's hand_result integrity check. The driver dispatches a recorded hand_result right
-- after the play, while the hand is still scoring, so G.GAME.chips still holds the earlier total
-- until the scoring ends. The check therefore waits for the chips to match, and warns only when
-- they never do. It reads G.GAME.chips, not PVP.GAME.score: the live client records its chips, and
-- a playback never sets PVP.GAME.score (the play_hand report does not run in practice mode).
-- `wait_for(predicate, callback)` is the mod's own one-shot condition poll.
PVP.HAND_RESULT_CHECK_TIMEOUT_SECONDS = 10

local function scored_chips()
	return PVP.Score.from_game_value(G.GAME and G.GAME.chips or 0)
end

function PVP.check_hand_result_when_scored(recorded, wait_for)
	local deadline = love.timer.getTime() + PVP.HAND_RESULT_CHECK_TIMEOUT_SECONDS
	wait_for(function()
		return PVP.Score.equal(recorded, scored_chips()) or love.timer.getTime() >= deadline
	end, function()
		local real = scored_chips()
		if not PVP.Score.equal(recorded, real) then
			MPAPI.sendWarnMessage("playback hand_result mismatch: recorded=" .. recorded .. " real=" .. real)
		end
	end)
end
