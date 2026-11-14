-- Tells the server while the player animates inside a clock that freezes for animations (the PvP hand
-- clock and Pressure), so the clock it counts freezes too. lib/animating.lua
-- decides what is sent and when; this only gathers the plain inputs each frame (pvp_api/frame.lua).

local animating_state = PVP.Animating.new()

PVP.AnimatingNet = {}

function PVP.AnimatingNet.update()
	local run_id = PVP.current_run_id()
	local input = { run_id = run_id, in_context = false, animating = false }
	if run_id and G.CONTROLLER and G.GAME then
		local clocks = PVP.clocks_rules()
		local state = MPAPI.get_state("pvp.round")
		local round = PVP.StateValue.same_run(state, run_id) and state or {}
		-- What the server's animating set depends on: it drops it at a round or phase change and on a reconnect.
		input.epoch = table.concat({ tostring(round.roundId), tostring(round.phase), tostring(PVP.CONNECTION_EPOCH or 0) }, ":")
		input.in_context = PVP.Animating.in_context({
			pvp_boss = PVP.is_pvp_boss(),
			pvp_clock = PVP.has_pvp_clock(),
			pressure = clocks ~= nil and clocks.personal ~= nil and clocks.personal.kind == "pressure",
			ready_blind = PVP.GAME.ready_blind,
			speedlatro = PVP.is_layer_active("speedlatro_timer"),
		})
		input.animating = PVP.Animating.is_animating({
			locked = G.CONTROLLER.locked,
			frame_lock = G.CONTROLLER.locks and G.CONTROLLER.locks.frame,
			stop_use = G.GAME.STOP_USE,
			paused = G.SETTINGS and G.SETTINGS.paused,
			overlay_menu = G.OVERLAY_MENU,
		})
	end
	local send
	animating_state, send = PVP.Animating.step(animating_state, input, love.timer.getTime())
	if send ~= nil then PVP.ACTIONS.set_animating(send) end
end
