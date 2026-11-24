-- Run from the repo root: luajit tests/unit/play_action_gate_test.lua
-- The Play action itself refuses a hand once the view says my PvP blind is over, not only the
-- Play button's look: a game paused with the button lit must not play after the blind closed.
local f = assert(io.open("ui/game/timer.lua", "r"))
local text = f:read("*a")
f:close()

local body = text:match("function G%.FUNCS%.play_cards_from_highlighted%(%.%.%.%)(.-)\nend")
assert(body, "timer.lua has no play_cards_from_highlighted hook")

local gate = body:find("PVP.UI.pvp_blind.may_play()", 1, true)
local play = body:find("old_play", 1, true)
assert(gate, "the Play action does not check pvp_blind_screen.may_play()")
assert(play and gate < play, "the Play action checks may_play() only after playing the hand")

print("play_action_gate_test: ok (2 checks)")
