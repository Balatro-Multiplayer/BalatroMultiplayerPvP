-- The tournament text: PVP.T(key, ...) looks the key up in the loaded
-- localization (misc.dictionary, the k_tn_ keys in localization/<language>.lua)
-- and fills in #1#, #2#, ... with the arguments. With no game around it (the
-- unit tests), it reads the English file itself. A missing key shows as the key.

PVP = PVP or {}

local english = nil -- the English dictionary for the tests, read on first need (false: unavailable)

local function english_dictionary()
	if english == nil then
		english = false
		local chunk = loadfile and loadfile("localization/en-us.lua")
		if chunk then
			local ok, t = pcall(chunk)
			if ok and type(t) == "table" and t.misc and type(t.misc.dictionary) == "table" then
				english = t.misc.dictionary
			end
		end
	end
	return english or nil
end

function PVP.T(key, ...)
	local loaded = G and G.localization and G.localization.misc and G.localization.misc.dictionary
	local text = loaded and loaded[key]
	if type(text) ~= "string" and not loaded then
		local en = english_dictionary()
		text = en and en[key]
	end
	if type(text) ~= "string" then
		return key
	end
	local n = select("#", ...)
	if n == 0 then
		return text
	end
	local args = { ... }
	return (text:gsub("#(%d+)#", function(i)
		local v = args[tonumber(i)]
		return v == nil and "" or tostring(v)
	end))
end
