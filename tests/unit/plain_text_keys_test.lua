-- Plain Lua test: every text key the code reads with a plain localize(key) is in
-- misc.dictionary of the real en-us strings (a key in v_dictionary shows "ERROR").
-- The API mod's strings load into the same dictionary, so its keys count too.
-- Run from the repo root: luajit tests/unit/plain_text_keys_test.lua
PVP = {}
local en = dofile("localization/en-us.lua")
local api_file = io.open("../api/localization/en-us.lua", "r")
local api_en = nil
if api_file then
	api_file:close()
	api_en = dofile("../api/localization/en-us.lua")
end

local function read(path)
	local file = assert(io.open(path, "r"))
	local text = file:read("*a")
	file:close()
	return text
end

local failures = 0
-- Balatro's own strings, read by the mod but defined by the base game.
local BASE_GAME = {}
for _, key in ipairs({
	"b_back", "b_github_project", "b_new_run", "b_settings", "k_active_ex", "k_again_ex",
	"k_copied_ex", "k_debuffed", "k_deck", "k_drank_ex", "k_duplicated_ex", "k_eaten_ex",
	"k_extinct_ex", "k_hud_discards", "k_level_up_ex", "k_lower_score", "k_melted_ex",
	"k_no_reward", "k_nope_ex", "k_plus_spectral", "k_plus_tarot", "k_reset", "k_round",
	"k_upgrade_ex", "k_val_up", "ph_blind_reward", "ph_blind_score_at_least", "ph_defeat_the_boss",
}) do
	BASE_GAME[key] = true
end

local function need_plain(key, where)
	if BASE_GAME[key] then return end
	local in_api = api_en and api_en.misc.dictionary[key] ~= nil
	if en.misc.dictionary[key] == nil and not in_api then
		failures = failures + 1
		print(("FAIL %s: %s is not in misc.dictionary"):format(where, key))
	end
end

-- Keys written straight into a plain localize("...") call, in every Lua file of the mod.
local files = {}
local listing = io.popen("git ls-files pvp_api ui lib gamemodes objects")
for path in listing:lines() do
	if path:match("%.lua$") then
		files[#files + 1] = path
	end
end
listing:close()
assert(#files > 20, "found too few Lua files; run from the repo root")
for _, path in ipairs(files) do
	local code = read(path):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
	for key in code:gmatch('localize%("([%w_]+)"%)') do
		need_plain(key, path)
	end
end

for _, key in ipairs({ "b_ready_waiting", "b_ready_held", "b_unready", "b_ready" }) do
	need_plain(key, "entry_screen")
end

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("plain_text_keys_test: ok")
