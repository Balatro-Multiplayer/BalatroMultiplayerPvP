-- Run from the repo root: luajit tests/unit/timer_force_speed_test.lua
-- Main's forced game speed while a timer that pauses for animations runs on me
-- (timer_reader.forces_speed, set every frame by timer_screen.update).
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local source = os.getenv("TIMER_SRC") or "pvp_api"
local layers_on = {}
local in_pvp_blind = false
PVP = {
	match_net = {
		server_now = function() return 60000 end,
		waiting = function() return false end,
		send = function() return true end,
	},
	is_pvp_boss = function() return in_pvp_blind end,
	is_layer_active = function(key) return layers_on[key] == true end,
	GAME = { ready_blind = false },
}
G = {
	CONTROLLER = { locked = false, locks = {} },
	SETTINGS = {},
	GAME = { STOP_USE = 0, current_round = { hands_left = 3 } },
	STATES = { NEW_ROUND = 1, ROUND_EVAL = 2, SELECTING_HAND = 3 },
	STATE = 3,
}
dofile(source .. "/timer_reader.lua")
dofile(source .. "/timer_screen.lua")
local reader = PVP.timer_reader

local function view(deadlines, pauses)
	return { me = "a", timers = { deadlines = deadlines, pauses = pauses or {} } }
end
local function game(overrides)
	local state = { in_pvp_blind = false, ready_blind = false, hands_left = 3, blind_over = false }
	for key, value in pairs(overrides or {}) do state[key] = value end
	return state
end
local function forces(v, layers, state)
	return reader.forces_speed and reader.forces_speed(v, layers, state)
end

local opponent_pvp = { kind = "pvp", by = "b", against = { "a" }, endsAt = 100000, hold = "counting" }
local opponent_ante = { kind = "ante", by = "b", against = { "a" }, endsAt = 100000, hold = "counting" }
local my_personal = { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 1, hold = "counting" }
local held = { { reason = "animating", players = { "a" }, endsAt = 90000 } }

-- pvp_timer: the opponent timered me in the PvP blind.
local pvp_layers = { pvp_timer = true }
eq(forces(view({ opponent_pvp }), pvp_layers, game({ in_pvp_blind = true })), true, "pvp_timer: timered in the PvP blind")
local held_pvp = { kind = "pvp", by = "b", against = { "a" }, endsAt = 100000, pausedAt = 80000, hold = "held for player" }
local stopped_pvp = { kind = "pvp", by = "b", against = { "a" }, endsAt = 100000, pausedAt = 80000, hold = "paused by starter" }
eq(forces(view({ held_pvp }, held), pvp_layers, game({ in_pvp_blind = true })), true, "pvp_timer: held while I animate")
eq(forces(view({ stopped_pvp }), pvp_layers, game({ in_pvp_blind = true })), false, "pvp_timer: paused by the opponent")
eq(forces(view({ stopped_pvp }, held), pvp_layers, game({ in_pvp_blind = true })), false, "pvp_timer: paused by the opponent while I animate")
eq(forces(view({ opponent_pvp }), pvp_layers, game({ in_pvp_blind = true, hands_left = 0 })), false, "pvp_timer: no hands left")
eq(forces(view({ opponent_pvp }), pvp_layers, game({ in_pvp_blind = true, blind_over = true })), false, "pvp_timer: blind scoring out")
eq(forces(view({ opponent_pvp }), pvp_layers, game({ in_pvp_blind = false })), false, "pvp_timer: not the PvP blind")
eq(forces(view({}), pvp_layers, game({ in_pvp_blind = true })), false, "pvp_timer: nobody timered me")
local mine_pvp = { kind = "pvp", by = "a", against = { "b" }, endsAt = 100000, hold = "counting" }
eq(forces(view({ mine_pvp }), pvp_layers, game({ in_pvp_blind = true })), false, "pvp_timer: I timered them")

-- pressure_timer: my personal clock, outside the PvP blind.
local pressure_layers = { pressure_timer = true }
eq(forces(view({ my_personal }), pressure_layers, game()), true, "pressure_timer: my clock runs")
eq(forces(view({ opponent_ante }), pressure_layers, game()), true, "pressure_timer: timered")
eq(forces(view({ my_personal }), pressure_layers, game({ ready_blind = true })), false, "pressure_timer: ready")
eq(forces(view({ my_personal }), pressure_layers, game({ in_pvp_blind = true })), false, "pressure_timer: PvP blind")
local paused_personal = { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, pausedAt = 70000, rate = 1, hold = "paused for pvp blind" }
local ready_personal = { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, pausedAt = 70000, rate = 1, hold = "paused until timed" }
local held_personal = { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, pausedAt = 70000, rate = 1, hold = "held for player" }
eq(forces(view({ paused_personal }), pressure_layers, game()), false, "pressure_timer: clock stopped (after the PvP blind)")
eq(forces(view({ held_personal }, held), pressure_layers, game()), true, "pressure_timer: clock held while I animate")
eq(forces(view({ paused_personal }, held), pressure_layers, game()), false, "pressure_timer: stopped for the PvP blind while I animate")
eq(forces(view({ ready_personal }, held), pressure_layers, game()), false, "pressure_timer: paused until timed while I animate")
eq(forces(view({ paused_personal, opponent_ante }), pressure_layers, game()), true, "pressure_timer: stopped but timered")

-- no_animation_timer: only when the opponent timered me.
local no_animation_layers = { no_animation_timer = true }
eq(forces(view({ opponent_ante }), no_animation_layers, game()), true, "no_animation_timer: timered")
eq(forces(view({}), no_animation_layers, game()), false, "no_animation_timer: not timered")
eq(forces(view({ opponent_ante }), no_animation_layers, game({ ready_blind = true })), false, "no_animation_timer: ready")
eq(forces(view({ opponent_ante }), no_animation_layers, game({ in_pvp_blind = true })), false, "no_animation_timer: PvP blind")
local mine_ante = { kind = "ante", by = "a", against = { "b" }, endsAt = 100000, hold = "counting" }
eq(forces(view({ mine_ante }), no_animation_layers, game()), false, "no_animation_timer: I timered them")

-- Never under Speedlatro; never without a timer layer; never without a view.
eq(forces(view({ my_personal, opponent_ante }), { speedlatro_timer = true, pressure_timer = true }, game()), false, "speedlatro off")
eq(forces(view({ opponent_ante }), {}, game()), false, "old timer: no force")
eq(forces(nil, pressure_layers, game()), false, "no view")

-- timer_screen.update sets the flag every frame, false with no view.
PVP.timer_screen.update()
eq(PVP.TIMER_FORCE_GAMESPEED, false, "update with no view clears the flag")
layers_on = { pressure_timer = true }
PVP.match_net.view = view({ my_personal })
PVP.timer_screen.update()
eq(PVP.TIMER_FORCE_GAMESPEED, true, "update sets the flag")
PVP.match_net.view = view({ paused_personal })
PVP.timer_screen.update()
eq(PVP.TIMER_FORCE_GAMESPEED, false, "update clears it when the timer stops")
PVP.match_net.view = view({ my_personal })
PVP.timer_screen.update()
PVP.match_net.view = nil
PVP.timer_screen.update()
eq(PVP.TIMER_FORCE_GAMESPEED, false, "update clears it when the view goes")

print("timer_force_speed_test: ok (" .. checks .. " checks)")
