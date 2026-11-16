-- Utilities for checking states and formatting display.

function FN.PRE.is_enough_to_win(chips)
	if
		G.GAME.blind
		and (G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.DRAW_TO_HAND or G.STATE == G.STATES.PLAY_TAROT)
	then
		return (G.GAME.chips + chips >= G.GAME.blind.chips)
	else
		return false
	end
end

function FN.PRE.format_number(num)
	if not num or type(num) ~= "number" then return num or "" end
	return number_format(num) -- Default Balatro function.
end

-- Formats as '+$5' or '+$1.33' (expected money can be fractional)
function FN.PRE.format_dollars(n)
	local digits = string.format("%.2f", math.abs(n)):gsub("%.?0+$", "")
	return (n < 0 and "-$" or "+$") .. digits
end

function FN.PRE.get_dollar_colour(n)
	if n == 0 then
		return HEX("7e7667")
	elseif n > 0 then
		return G.C.MONEY
	elseif n < 0 then
		return G.C.RED
	end
end

function FN.PRE.get_sign_str(n)
	if n >= 0 then
		return "+"
	else
		return "" -- Negative numbers already have a sign
	end
end

function FN.PRE.enabled()
	return G.SETTINGS.FN.preview_score or G.SETTINGS.FN.preview_dollars
end
