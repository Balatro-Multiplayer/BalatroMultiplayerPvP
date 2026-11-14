-- Run from the repo root: luajit tests/unit/run_save_state_test.lua
local registered
PVP = { id = "MultiplayerPvP", GAME = { lives = 4, enemy = { score = "0" } } }
-- The fresh-match defaults (core.lua's PVP.reset_game_states), cut down to a few keys.
function PVP.reset_game_states()
	PVP.GAME = { lives = 0, furthest_blind = 120, enemy = { score = "0" } }
end
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

local saved = registered.hooks.save()
assert(saved and saved.lives == 4 and saved.enemy.score == "0", "gives the match state in a session")
PVP.GAME.next_blind_context = { UIBox = {} }
assert(registered.hooks.save().next_blind_context == nil, "leaves out the blind button, a UI node that cannot be saved")
assert(PVP.GAME.next_blind_context ~= nil, "and does not touch the live state")
in_session = false
assert(registered.hooks.save() == nil, "gives nothing outside a session")

-- load: the saved match state goes over a fresh match, so nothing of the live state is kept.
PVP.GAME = { lives = 1, furthest_blind = 99, next_blind_context = "live", watched_leftover = true }
registered.hooks.load({ lives = 3, enemy = { score = "7" }, ante_key = "k" })
assert(PVP.GAME.lives == 3 and PVP.GAME.enemy.score == "7" and PVP.GAME.ante_key == "k", "saved values are back")
assert(PVP.GAME.furthest_blind == 120, "a value the save does not hold is the fresh-match default")
assert(PVP.GAME.watched_leftover == nil, "and a key only the live state had is gone")
assert(PVP.GAME.next_blind_context == nil, "and the blind button is not kept from the other run")

-- A crash rejoin keeps what the save holds (the lives, the scores, the who-is-timed flags); the clocks are
-- the server's and are not part of it.
in_session = true
PVP.GAME = {
	lives = 2,
	furthest_blind = 61,
	timer_started = true,
	nemesis_timer_started = false,
	enemy = { score = "0" },
}
local snapshot = registered.hooks.save()
PVP.GAME = { lives = 1, furthest_blind = 120, enemy = { score = "0" } }
registered.hooks.load(snapshot)
assert(PVP.GAME.furthest_blind == 61, "a saved value comes back, not the fresh-match default")
assert(PVP.GAME.timer_started == true and PVP.GAME.nemesis_timer_started == false, "and who was timed")
print("run_save_state_test: ok")
