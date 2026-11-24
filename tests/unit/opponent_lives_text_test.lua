-- Run from the repo root: luajit tests/unit/opponent_lives_text_test.lua
-- The HUD's opponent lives are the view's lives; while the view has none they show as "?".
PVP = {}
dofile("lib/lives_lookup.lua")

local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

eq(PVP.opponent_lives_text(nil), "?", "unknown lives show as ?")
eq(PVP.opponent_lives_text(3), 3, "known lives show as they are")
eq(PVP.opponent_lives_text(0), 0, "0 lives is a value, not unknown")

print("opponent_lives_text_test: ok (" .. checks .. " checks)")
