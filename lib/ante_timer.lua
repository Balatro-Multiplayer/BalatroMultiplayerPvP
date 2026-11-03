-- An Ante timer that runs out on the timered player costs a life and starts again by
-- itself on the same opponent. It stops when the PvP blind starts (which clears the
-- timer flags) or when that life was the player's last.

PVP.AnteTimer = {}

-- Runs on the timered side when its copy of the Ante timer reaches 0.
function PVP.AnteTimer.on_run_out()
	local lives_left = PVP.GAME.lives
	if PVP.GAME.timers_forgiven < PVP.LOBBY.config.timer_forgiveness then
		PVP.GAME.timers_forgiven = PVP.GAME.timers_forgiven + 1
	else
		PVP.ACTIONS.fail_timer()
		lives_left = lives_left - 1
	end
	if lives_left <= 0 then return end
	PVP.GAME.timer = PVP.UTILS.timer_base()
	PVP.GAME.timer_consumed = false
	PVP.ACTIONS.announce_ante_timer_restart(PVP.GAME.timer)
end

-- Runs on the waiting side when the timered side restarted. A restart that arrives
-- after the waiting side stopped its timer (the PvP blind began) is dropped.
-- `resume`: the timered side sends it to a player who rejoined, who has no timer yet.
function PVP.AnteTimer.receive_restart(time, resume)
	local running = PVP.GAME.timer_started or PVP.GAME.nemesis_timer_started
	if not (running or resume) then return end
	if not running then PVP.GAME.timer_started = true end
	PVP.GAME.timer = time
	PVP.GAME.timer_consumed = false
end

-- Runs when the opponent comes back from a disconnect: tells it the timer it missed.
function PVP.AnteTimer.on_opponent_back()
	if PVP.GAME.nemesis_timer_started then
		PVP.ACTIONS.announce_ante_timer_restart(PVP.GAME.timer, true)
	elseif PVP.GAME.timer_started then
		PVP.ACTIONS.announce_ante_timer(PVP.GAME.timer)
	end
end
