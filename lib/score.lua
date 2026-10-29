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

-- True when a big-number mod is installed (the Talisman shim hands numbers back unchanged).
local function has_number_mod()
	if type(to_big) ~= "function" then return false end
	local ok, value = pcall(to_big, 0)
	return ok and type(value) ~= "number"
end

-- The score as a game value: a double, or the installed mod's number. Nil when
-- the text is malformed, or when it is past the double range and no mod is installed.
function PVP.Score.to_game_value(text)
	local canonical = PVP.Score.parse(text)
	if not canonical then return nil end
	local array = {}
	for part in canonical:gmatch("[^,]+") do
		array[#array + 1] = tonumber(part)
	end
	if has_number_mod() then
		if #array == 1 then return to_big(array[1]) end
		local ok, value = pcall(to_big, { array = array, sign = 1 })
		return ok and value or nil
	end
	if #array == 1 then return array[1] end
	return nil
end

-- Score text of the sum of score texts. The sum uses the installed number type
-- (doubles with no mod). With no mod, a score past the double range cannot be
-- added, so the largest score stands in for the sum. Malformed scores count as zero.
-- If the installed mod's add raises an error, the error is logged and the sum
-- falls back to the double rule.
function PVP.Score.sum(list)
	local texts = {}
	for i = 1, #list do
		texts[i] = PVP.Score.or_zero(list[i])
	end
	if has_number_mod() then
		local total = to_big(0)
		local ok, err = pcall(function()
			for _, text in ipairs(texts) do
				total = total + PVP.Score.to_game_value(text)
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
