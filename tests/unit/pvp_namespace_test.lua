-- Every top-level key on PVP is a role table, a feature table or a framework key.
-- Run from the repo root: luajit tests/unit/pvp_namespace_test.lua

local ALLOWED = {}
for name in
	([[
	id path version config optional_features extra_tabs credits_tab config_tab reset_game_globals
	load_mp_dir load_mp_file match_log MIN_LOVELY_VERSION MIN_SMODS_VERSION BANNED_MODS
	EXPERIMENTAL ENV INTEGRATIONS PREVIEW
	is_practice_mode
	NET READ UI GAME LOBBY QUEUE REPLAY
	ACTIONS UTILS DECK SANDBOX COLOURS CONTEST SCORE DRAFT STATS PRACTICE TRAP SETUP SPECTATE
	WHITE EC MATCH_PLAYERS OPPONENT_SIGNALS OPPONENT_RECORD NEMESIS RULES VERIFIED COCKTAIL
]]):gmatch("%S+")
do
	ALLOWED[name] = true
end

-- Old keys still in use while a move lands; each commit deletes the lines it moves.
local LEGACY = {}

local function read(path)
	local f = assert(io.open(path, "rb"))
	local s = f:read("*a")
	f:close()
	return s
end

local function strip(path, s)
	if path:match("%.toml$") then s = s:gsub("\n[ \t]*#[^\n]*", "\n") end -- toml comment lines only; '#' is Lua's length operator in payloads
	return (s:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", ""))
end

local failures, seen = 0, {}
local function fail(msg)
	failures = failures + 1
	print("FAIL " .. msg)
end

local list = assert(io.popen("git ls-files"))
for path in list:lines() do
	if (path:match("%.lua$") or path:match("%.toml$")) and not path:match("^tests/") then
		local text = "\n" .. strip(path, read(path))
		for pre, sep, key in text:gmatch("([^%w_%.])PVP([%.:])([%a_][%w_]*)") do
			seen[key] = true
			if not ALLOWED[key] and not LEGACY[key] then
				fail(("%s: PVP%s%s is not a role table, feature table or framework key"):format(path, sep, key))
			end
			if sep == ":" then
				fail(("%s: PVP:%s, a method on the mod table; use a dot call on its role table"):format(path, key))
			end
		end
		if text:match("[^%w_%.]PVP%s*%[") then
			fail(path .. ": PVP[...] looks a key up by string; the guard cannot see it")
		end
		if text:match("ref_table%s*=%s*PVP%s*[,}\n]") then
			fail(path .. ": ref_table = PVP binds a top-level key by name")
		end
	end
end
list:close()

for key in pairs(LEGACY) do
	if not seen[key] then fail("LEGACY lists PVP." .. key .. " but nothing uses it; remove it") end
end

if failures > 0 then
	print(("pvp_namespace_test: %d failure(s)"):format(failures))
	os.exit(1)
end
print("pvp_namespace_test: ok")
