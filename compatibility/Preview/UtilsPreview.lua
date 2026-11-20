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

-- Formats as '+$5', or '~$1.33' when luck is involved (expected money can be fractional)
function FN.PRE.format_dollars(n, lucky)
	local digits = string.format("%.2f", math.abs(n)):gsub("%.?0+$", "")
	local sign = n < 0 and "-" or "+"
	if lucky then sign = n < 0 and "~-" or "~" end
	return sign .. "$" .. digits
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

-- Expected money preview only shows in rulesets with the money_preview layer
function FN.PRE.money_preview_enabled()
	return PVP.is_layer_active("money_preview")
end

function FN.PRE.enabled()
	return G.SETTINGS.FN.preview_score or G.SETTINGS.FN.preview_dollars
end
