-- Run from the repo root: luajit tests/unit/opponent_lives_text_test.lua
-- The HUD's opponent lives are the view's lives; while the view has none they show as "?".
PVP = { UTILS = {} }
dofile("lib/lives_lookup.lua")
local T = dofile("tests/support/check.lua")
local eq = T.eq

eq(PVP.UTILS.opponent_lives_text(nil), "?", "unknown lives show as ?")
eq(PVP.UTILS.opponent_lives_text(3), 3, "known lives show as they are")
eq(PVP.UTILS.opponent_lives_text(0), 0, "0 lives is a value, not unknown")

T.done("opponent_lives_text_test")
