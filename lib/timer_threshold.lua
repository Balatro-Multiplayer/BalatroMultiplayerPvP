-- A ruleset's timer_display_threshold (MLBa) hides the ante timer above it: until the
-- time falls to it, the timed player's box is idle and shows the threshold, or their own
-- time when that is lower (lib/timer_view.lua holds that rule). 0 or nil means no threshold.

function PVP.UTILS.timer_display_threshold()
	return PVP.current_ruleset().timer_display_threshold or 0
end

-- `running`: the timer box counts (lib/timer_view.lua's `running`).
-- `pvp_allowance`: the box is the PvP allowance, which the ante display threshold never clamps.
function PVP.UTILS.timer_display_text(timer, running, pvp_allowance)
	local threshold = PVP.UTILS.timer_display_threshold()
	if not running and not pvp_allowance and threshold > 0 and timer > threshold then
		return string.format("%d", threshold)
	end
	-- Whole seconds from 10 up; 9.95 keeps a rounded "10.0" from showing.
	if timer > 9.95 then return string.format("%d", timer) end
	return string.format("%.1f", timer)
end
