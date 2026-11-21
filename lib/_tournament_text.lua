-- The tournament screens' text: PVP.T(key, ...) looks the key up in the
-- loaded localization (localization/tournaments/<language>.lua, which SMODS
-- loads over the English file) and fills in #1#, #2#, ... with the
-- arguments. A key the localization lacks falls back to the English file
-- itself (also what the unit tests use, with no game around them), and a key
-- missing even there shows as the key.

PVP = PVP or {}

local english = nil -- the English dictionary, read on first need (false: unavailable)

local function english_dictionary()
	if english == nil then
		english = false
		local path = "localization/tournaments/en-us.lua"
		local chunk
		if SMODS and SMODS.load_file and PVP and PVP.id then
			chunk = SMODS.load_file(path, PVP.id)
		elseif loadfile then
			chunk = loadfile(path)
		end
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
	if type(text) ~= "string" then
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
