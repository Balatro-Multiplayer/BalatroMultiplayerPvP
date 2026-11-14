-- What the player hears and sees of the opponent: lives.
PVP.OPPONENT_SIGNALS = {}

function PVP.OPPONENT_SIGNALS.lives_dropped(old_lives, new_lives)
	return old_lives ~= nil and new_lives ~= nil and new_lives < old_lives
end

function PVP.OPPONENT_SIGNALS.play_life_lost()
	play_sound("holo1", 0.865, 0.9)
	play_sound("gong", 0.765, 0.4)
end
