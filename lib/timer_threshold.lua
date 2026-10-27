-- A ruleset's timer_display_threshold (MLBa) hides the ante timer above it:
-- the timer shows the threshold until it falls to it, and the opponent is told
-- the timer started only then. 0 or nil means no threshold.

function PVP.UTILS.timer_display_threshold()
	return PVP.current_ruleset().timer_display_threshold or 0
end

function PVP.UTILS.timer_start_held_back(timer)
	local threshold = PVP.UTILS.timer_display_threshold()
	return threshold > 0 and timer > threshold
end

-- `running`: either player started the timer this ante.
function PVP.UTILS.timer_display_text(timer, running)
	if not running and PVP.UTILS.timer_start_held_back(timer) then
		return string.format("%d", PVP.UTILS.timer_display_threshold())
	end
	-- Whole seconds from 10 up; 9.95 keeps a rounded "10.0" from showing.
	if timer > 9.95 then
		return string.format("%d", timer)
	end
	return string.format("%.1f", timer)
end
