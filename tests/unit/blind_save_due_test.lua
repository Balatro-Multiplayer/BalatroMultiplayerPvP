-- Run from the repo root: luajit tests/unit/blind_save_due_test.lua
PVP = { id = "MultiplayerPvP", GAME = {} }
function PVP.in_session() return true end
MPAPI = { run_save = { register_state = function() end } }
dofile("lib/run_save.lua")
local all = { in_lobby = true, is_pvp_blind = true, arrived = true }
assert(PVP.blind_save_due(all), "due when every condition holds")
for _, key in ipairs({ "in_lobby", "is_pvp_blind", "arrived" }) do
	local ctx = {}
	for k, v in pairs(all) do ctx[k] = v end
	ctx[key] = false
	assert(PVP.blind_save_due(ctx) == false, "not due without " .. key)
end
assert(PVP.blind_save_due({}) == false, "not due on an empty context")
print("blind_save_due_test: ok")
