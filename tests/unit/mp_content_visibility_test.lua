-- Plain Lua test for lib/mp_content_visibility.lua (pure rules, no game needed).
-- Run from the repo root: luajit tests/unit/mp_content_visibility_test.lua
PVP = { LobbyAccess = { PRIVATE = "private", PRACTICE = "practice", RANKED = "ranked", CASUAL = "casual" } }
dofile("lib/mp_content_visibility.lua")
local hide = PVP.MpContentVisibility.should_hide
local A = PVP.LobbyAccess

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

check("private lobby, ruleset without PvP-only cards, shows all", hide(true, A.PRIVATE, false, false), false)
check("private lobby, ruleset with PvP-only cards, shows all", hide(true, A.PRIVATE, true, false), false)
check("casual lobby, ruleset without PvP-only cards, hides", hide(true, A.CASUAL, false, false), true)
check("ranked lobby, ruleset without PvP-only cards, hides", hide(true, A.RANKED, false, false), true)
check("casual lobby, ruleset with PvP-only cards, shows", hide(true, A.CASUAL, true, false), false)
check("ranked lobby, ruleset with PvP-only cards, shows", hide(true, A.RANKED, true, false), false)
check("no lobby hides", hide(false, nil, true, false), true)
check("no lobby, private kind left over, hides", hide(false, A.PRIVATE, false, false), true)
check("opt-in shows in a ranked lobby", hide(true, A.RANKED, false, true), false)
check("opt-in shows with no lobby", hide(false, nil, false, true), false)

if failures > 0 then
	os.exit(1)
end
