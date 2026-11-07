-- The replay's hand_result integrity check. The driver dispatches a recorded hand_result right
-- after the play, while the hand is still scoring, so PVP.GAME.score still holds the earlier
-- hand's score until the scoring ends. The check therefore waits for the score to match, and warns
-- only when it never does. `wait_for(predicate, callback)` is the mod's own one-shot condition poll.
PVP.HAND_RESULT_CHECK_TIMEOUT_SECONDS = 10

function PVP.check_hand_result_when_scored(recorded, wait_for)
	local deadline = love.timer.getTime() + PVP.HAND_RESULT_CHECK_TIMEOUT_SECONDS
	wait_for(function()
		return PVP.Score.equal(recorded, PVP.GAME.score) or love.timer.getTime() >= deadline
	end, function()
		if not PVP.Score.equal(recorded, PVP.GAME.score) then
			MPAPI.sendWarnMessage('playback hand_result mismatch: recorded=' .. recorded .. ' real=' .. PVP.Score.or_zero(PVP.GAME.score))
		end
	end)
end
