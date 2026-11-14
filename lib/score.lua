-- PVP.Score: a player's score as score text (MPAPI.BigScore). Every compare and
-- every display of a score goes through here, never through the installed
-- number mod's own compare. A missing or malformed score is unknown (nil): it
-- ranks below every real score, zero included, and equal to another unknown
-- one, so a bad message from a peer cannot break a compare or pass for a zero.

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

-- -1, 0 or 1. An unknown score (nil, or text that is not a score) ranks below
-- every score and equal to another unknown one (the server's compareRoundScore).
function PVP.Score.compare(a, b)
	a, b = PVP.Score.parse(a), PVP.Score.parse(b)
	if a == nil then return b == nil and 0 or -1 end
	if b == nil then return 1 end
	return MPAPI.BigScore.compare(a, b)
end

function PVP.Score.greater(a, b)
	return PVP.Score.compare(a, b) > 0
end

function PVP.Score.equal(a, b)
	return PVP.Score.compare(a, b) == 0
end

-- Text for people, in Balatro notation; an unknown score shows as "???".
function PVP.Score.display(text)
	local score = PVP.Score.parse(text)
	if score == nil then return localize("k_score_unknown") end
	return MPAPI.BigScore.display(score)
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

-- The score as a game value: a double, or the installed mod's number. Nil and a
-- reason when the text is malformed, when it is past the double range and no mod
-- is installed, or when the mod does not build the same score.
function PVP.Score.to_game_value(text)
	return MPAPI.BigScore.to_game_value(text)
end

-- Score text of the sum of score texts. The sum uses the installed number type
-- (doubles with no mod). With no mod, a score past the double range cannot be
-- added, so the largest score stands in for the sum. An unknown score makes the
-- sum unknown (nil); the sum of no scores is zero.
-- If the installed mod's add raises an error, the error is logged and the sum
-- falls back to the double rule.
function PVP.Score.sum(list)
	local texts = {}
	for i = 1, #list do
		texts[i] = PVP.Score.parse(list[i])
		if texts[i] == nil then return nil end
	end
	if MPAPI.BigScore.has_number_mod() then
		local total = to_big(0)
		local ok, err = pcall(function()
			for _, text in ipairs(texts) do
				local value, reason = PVP.Score.to_game_value(text)
				if value == nil then error(reason, 0) end
				total = total + value
			end
		end)
		if ok then return PVP.Score.from_game_value(total) end
		sendWarnMessage("[score] the number mod could not add scores: " .. tostring(err), "MULTIPLAYER")
	end
	local total, largest = 0, PVP.Score.ZERO
	for _, text in ipairs(texts) do
		if PVP.Score.greater(text, largest) then largest = text end
		local n = not text:find(",", 1, true) and tonumber(text) or nil
		if n and total then
			total = total + n
		else
			total = nil
		end
	end
	if total and total < 1e300 then return PVP.Score.from_game_value(total) end
	return largest
end
