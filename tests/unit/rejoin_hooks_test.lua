-- Run from the repo root: luajit tests/unit/rejoin_hooks_test.lua
local registered
PVP = { id = "MultiplayerPvP", SP = {}, GAME = {} }
MPAPI = {
	playback = {
		register_rejoin_hooks = function(mod_id, hooks)
			registered = { mod_id = mod_id, hooks = hooks }
		end,
	},
}
dofile("lib/rejoin.lua")
assert(registered and registered.mod_id == "MultiplayerPvP", "registers under the mod id")

-- A mod that says it loads Run saves has its crash rejoin start from the server's save, and the
-- log only covers what came after it.
assert(registered.hooks.supports_run_save == true, "the rejoin loads the server's Run save")
assert(registered.hooks.playback_mod_id == "pvp", "the replay handlers are PvP's")
assert(type(registered.hooks.start_run) == "function", "the replay run is started by PvP")
