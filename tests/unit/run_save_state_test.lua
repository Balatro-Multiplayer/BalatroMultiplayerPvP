-- Run from the repo root: luajit tests/unit/run_save_state_test.lua
local registered
PVP = { id = "MultiplayerPvP", GAME = { lives = 4 } }
local in_session = true
function PVP.in_session()
	return in_session
end
MPAPI = {
	run_save = {
		register_state = function(mod_id, hooks)
			registered = { mod_id = mod_id, hooks = hooks }
		end,
	},
}
dofile("lib/run_save.lua")
assert(registered and registered.mod_id == "MultiplayerPvP", "registers under the mod id")
assert(registered.hooks.save() == PVP.GAME, "gives PVP.GAME in a session")
in_session = false
assert(registered.hooks.save() == nil, "gives nothing outside a session")
print("run_save_state_test: ok")
