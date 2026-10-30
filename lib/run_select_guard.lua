-- Steamodded 26.x's run setup screen starts the run when the already-selected stake is clicked
-- again (page `stake_choice`, double_click_advance). Inside BMP contexts (a lobby, Practice mode)
-- a click on a stake must only select it: Play starts the run. The plain singleplayer New Run
-- screen keeps Steamodded's behaviour. Steamodded 1814a has no SMODS.RunSelect: nothing to guard.
local STAKE_PAGE_KEY = "stake_choice"

function PVP.UTILS.blocks_double_click(page_key, in_bmp_context)
	return page_key == STAKE_PAGE_KEY and in_bmp_context == true
end

-- True when the run setup screen belongs to a BMP lobby or Practice mode.
function PVP.UTILS.in_bmp_run_setup()
	return MPAPI.get_current_lobby() ~= nil or PVP.is_practice_mode() or PVP.practice_setup_ruleset() ~= nil
end

-- Returns whether the guard was installed.
function PVP.UTILS.install_run_select_guard(in_bmp_context)
	local select = SMODS and SMODS.RunSelect
	if not (select and select.Functions and select.Functions.double_click_advance) then return false end
	local advance_ref = select.Functions.double_click_advance
	select.Functions.double_click_advance = function(page_def, ...)
		if PVP.UTILS.blocks_double_click(page_def and page_def.key, in_bmp_context()) then return end
		return advance_ref(page_def, ...)
	end
	return true
end
