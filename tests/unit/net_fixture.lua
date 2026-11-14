-- The server wire fixtures in tests/fixtures/net-v1/, byte-identical copies of the
-- server repo's contract examples. dofile this from the repo root: it returns
-- fixture(name), the decoded JSON (null decodes to nil, as on the wire).
local function decode(text)
	local pos = 1
	local value
	local function skip()
		pos = text:find("%S", pos) or #text + 1
	end
	local function string_value()
		local close = text:find('"', pos + 1, true)
		local s = text:sub(pos + 1, close - 1)
		pos = close + 1
		return s
	end
	function value()
		skip()
		local c = text:sub(pos, pos)
		if c == "{" then
			local out = {}
			pos = pos + 1
			skip()
			if text:sub(pos, pos) == "}" then
				pos = pos + 1
				return out
			end
			while true do
				skip()
				local key = string_value()
				skip()
				pos = pos + 1 -- the colon
				out[key] = value()
				skip()
				local sep = text:sub(pos, pos)
				pos = pos + 1
				if sep == "}" then return out end
			end
		elseif c == "[" then
			local out = {}
			pos = pos + 1
			skip()
			if text:sub(pos, pos) == "]" then
				pos = pos + 1
				return out
			end
			while true do
				out[#out + 1] = value()
				skip()
				local sep = text:sub(pos, pos)
				pos = pos + 1
				if sep == "]" then return out end
			end
		elseif c == '"' then
			return string_value()
		end
		local literal = text:match("^[%w%.%-+]+", pos)
		pos = pos + #literal
		if literal == "true" then
			return true
		elseif literal == "false" then
			return false
		elseif literal == "null" then
			return nil
		end
		return tonumber(literal)
	end
	return value()
end

local function fixture(name)
	local file = assert(io.open("tests/fixtures/net-v1/" .. name .. ".json", "rb"))
	local text = file:read("*a")
	file:close()
	return decode(text)
end

return fixture
