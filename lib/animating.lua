-- Pure rules for telling the server the player is animating (pvp.animating), so the clocks it counts
-- freeze while a scoring or card animation plays. No game state, clock or requests here: the per-frame
-- frame step in pvp_api/animating_net.lua gathers the plain inputs and pvp_api/round_net.lua sends the answer.

PVP.Animating = {}
local Animating = PVP.Animating

-- Seconds (an exact binary fraction) a changed value must hold before it is sent, so a one-frame lock flicker sends nothing.
Animating.HOLD = 0.125

-- Whether the player is animating this frame. `input` is { locked, frame_lock, stop_use, paused,
-- overlay_menu } read from G.CONTROLLER.locked, G.CONTROLLER.locks.frame, G.GAME.STOP_USE,
-- G.SETTINGS.paused and G.OVERLAY_MENU. A paused game or an open menu is the player's own time.
function Animating.is_animating(input)
	if input.paused or input.overlay_menu then return false end
	return (input.locked and not input.frame_lock) or (input.stop_use or 0) > 0 or false
end

-- Whether a clock that freezes for animations applies. `input` is { pvp_boss, pvp_clock (the rules give
-- the PvP blind a hand clock), pressure, ready_blind, speedlatro }; `pressure` comes from the
-- server's clock rules. Pressure ticks outside the PvP blind and past the blind select;
-- Speedlatro and the Ante clock never freeze for animations.
function Animating.in_context(input)
	if input.speedlatro then return false end
	if input.pvp_boss then return input.pvp_clock == true end
	if input.ready_blind then return false end
	return input.pressure == true
end

-- The state before any frame: nothing sent, nothing pending.
function Animating.new()
	return { run_id = nil, epoch = nil, sent = false, pending = nil, since = nil }
end

-- One frame. `state` is as returned here (never changed); `input` is { run_id (nil = no run open),
-- epoch, in_context, animating }; `now` is seconds on any steady clock. Returns the new state and what to
-- send: true or false, or nil for nothing.
--   * A new run, or a new `epoch` (any value that changes when the server drops what it knows of the
--     player's animating: another round or phase, a reconnect), starts from "not animating" without
--     sending, so a player still animating sends true again after the hold.
--   * Outside the context nothing is sent, except one false when true was the last value sent.
--   * Inside it a value that differs from the last one sent is sent once it has held for HOLD.
function Animating.step(state, input, now)
	local run_id = input.run_id
	local epoch = input.epoch
	if run_id ~= state.run_id or epoch ~= state.epoch then
		state = { run_id = run_id, epoch = epoch, sent = false }
	end
	if run_id == nil then return state, nil end
	if not input.in_context then
		if state.sent then return { run_id = run_id, epoch = epoch, sent = false }, false end
		return { run_id = run_id, epoch = epoch, sent = false }, nil
	end
	local animating = input.animating == true
	if animating == state.sent then return { run_id = run_id, epoch = epoch, sent = state.sent }, nil end
	local since = state.pending == animating and state.since or now
	if now - since >= Animating.HOLD then return { run_id = run_id, epoch = epoch, sent = animating }, animating end
	return { run_id = run_id, epoch = epoch, sent = state.sent, pending = animating, since = since }, nil
end
