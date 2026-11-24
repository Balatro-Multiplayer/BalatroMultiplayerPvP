-- The opponent lives the HUD shows beside your own: the view's lives, or "?" while they are unknown.
function PVP.UTILS.opponent_lives_text(lives)
	if lives == nil then return "?" end
	return lives
end
