-- PVP.Score: a player's score as score text (MPAPI.BigScore). Every compare and
-- every display of a score goes through here, never through the installed
-- number mod's own compare. A missing or malformed score counts as zero, so a
-- bad message from a peer cannot break a compare.

PVP.Score = {}

PVP.Score.ZERO = "0"

-- Canonical score text of a game value (a double, a Talisman or Amulet value).
function PVP.Score.from_game_value(value)
	return MPAPI.BigScore.from_game_value(value)
end

-- Canonical score text, or nil when the text is missing or malformed.
function PVP.Score.parse(text)
	if type(text) ~= "string" then return nil end
	return MPAPI.BigScore.normalize(text)
end

-- Canonical score text, with zero in place of a missing or malformed score.
function PVP.Score.or_zero(text)
	return PVP.Score.parse(text) or PVP.Score.ZERO
end

-- -1, 0 or 1.
function PVP.Score.compare(a, b)
	return MPAPI.BigScore.compare(PVP.Score.or_zero(a), PVP.Score.or_zero(b))
end

function PVP.Score.greater(a, b)
	return PVP.Score.compare(a, b) > 0
end

function PVP.Score.equal(a, b)
	return PVP.Score.compare(a, b) == 0
end

-- Text for people, in Balatro notation.
function PVP.Score.display(text)
	return MPAPI.BigScore.display(PVP.Score.or_zero(text))
end

-- The score as a plain number when it is a whole number below the point where
-- Balatro switches to e-notation (for easing a counter), else nil.
function PVP.Score.small_number(text)
	local canonical = PVP.Score.parse(text)
	if not canonical or canonical:find(",", 1, true) then return nil end
	local n = tonumber(canonical)
	if n and n < (G and G.E_SWITCH_POINT or 100000000000) then return n end
	return nil
end
