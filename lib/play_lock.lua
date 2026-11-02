-- Ignores a second Play until the first hand has been played, inside a PvP
-- session only. Vanilla only stops a second play once the first hand's cards
-- reach G.play, which can take a while when the event queue is busy. A second
-- click before then plays the same cards again, and both hands score from the
-- same chips, so one hand's score is lost. The lock lifts when the first play's
-- events have run, after 10s, or when a new run starts (leaving clears the
-- event queue, unlock included).
PVP.PlayLock = { LIMIT = 10 }
local PL = PVP.PlayLock

local pending = nil

function PL.reset()
	pending = nil
end

-- Runs play(...) unless a lock holds it back. Returns false when the play was
-- dropped, true when it ran. The lock is set only after play returns, so a play
-- that raises cannot leave it stuck.
function PL.run(play, ...)
	if not PVP.in_session() then
		play(...)
		return true
	end
	if pending and pending.game == G.GAME and love.timer.getTime() - pending.at < PL.LIMIT then
		return false
	end
	pending = nil
	play(...)
	local lock = { game = G.GAME, at = love.timer.getTime() }
	pending = lock
	G.E_MANAGER:add_event(Event({
		func = function()
			if pending == lock then
				pending = nil
			end
			return true
		end,
	}))
	return true
end
