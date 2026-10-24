-- What the player hears and sees of the opponent: lives, blind start, starting hands.
PVP.OPPONENT_SIGNALS = {}

function PVP.OPPONENT_SIGNALS.lives_dropped(old_lives, new_lives)
	return old_lives ~= nil and new_lives ~= nil and new_lives < old_lives
end

function PVP.OPPONENT_SIGNALS.starting_hands(round_resets)
	return (round_resets and round_resets.hands) or 0
end

function PVP.OPPONENT_SIGNALS.play_life_lost()
	play_sound("holo1", 0.865, 0.9)
	play_sound("gong", 0.765, 0.4)
end

function PVP.OPPONENT_SIGNALS.play_blind_start()
	play_sound("generic1", 0.865, 0.6)
end
