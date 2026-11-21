-- Run from the repo root: lua5.4 tests/unit/tournament_text_test.lua
-- Every tournament text key the code names (k_tn_...) is in the English
-- file (localization/en-us.lua), and PVP.T fills in its #n# arguments.
dofile("lib/_tournament_text.lua")

local failures = 0
local function check(name, ok, detail)
	if not ok then
		failures = failures + 1
		print("FAIL " .. name .. (detail and (": " .. detail) or ""))
	end
end

local english = dofile("localization/en-us.lua").misc.dictionary

local FILES = {
	"lib/tournament_time.lua",
	"pvp_api/tournament/net.lua",
	"pvp_api/tournament/play.lua",
	"ui/tournament/banner.lua",
	"ui/tournament/common.lua",
	"ui/tournament/screen.lua",
}

local used = 0
for _, path in ipairs(FILES) do
	local f = assert(io.open(path, "r"))
	local src = f:read("a")
	f:close()
	for key in src:gmatch('"(k_tn_[%w_]+)"') do
		-- "k_tn_day_" .. x builds the key: those prefixes end in "_".
		if not key:match("_$") then
			used = used + 1
			-- TUI.count(n, key) uses key .. "_1" and key .. "_n".
			local ok = english[key] ~= nil or (english[key .. "_1"] ~= nil and english[key .. "_n"] ~= nil)
			check("key " .. key .. " (" .. path .. ")", ok)
		end
	end
end
check("keys found", used > 30, tostring(used))

check("plain", PVP.T("k_tn_lobby_match_over") == "Match over. Back to the tournament...")
check("arguments", PVP.T("k_tn_status_ready_up", "Ann") == "Ready up vs Ann")
check("missing argument", PVP.T("k_tn_best_of") == "Best of #1#" and PVP.T("k_tn_best_of", nil, 2) == "Best of ")
check("unknown key shows itself", PVP.T("k_tn_no_such_key") == "k_tn_no_such_key")

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("tournament_text_test: all passed")
