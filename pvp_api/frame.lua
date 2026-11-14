-- The one per-frame hook of the nets. Each module in PVP.FRAME_ORDER has an `update()` that
-- does the work a snapshot or a push left for the next frame; this file runs them after the
-- game's own Game:update and everything wrapped before it.
--
-- Two of the steps depend on the order:
--   * LivesNet before ResultNet: a death the lives state names is applied first, so the result
--     sees PVP.GAME.result_handled / eliminated as the lives left them.
--   * ReadyNet before RoundEndNet: ReadyNet sets PVP.GAME.round_id (a start, or a rejoin
--     restoring it), which RoundEndNet reads to tell the round this client is in.
-- The others (TimerNet, RoundNet, SkipsNet, OpponentNet, EffectsNet, TrapsNet, AnimatingNet) touch nothing the rest read. Keep the list as it is; a new
-- module goes at the end unless it needs a step before another.
--
-- The modules are named, not captured, so this file does not depend on load order.

PVP.FRAME_ORDER = {
	"LivesNet",
	"ReadyNet",
	"ResultNet",
	"RoundEndNet",
	"TimerNet",
	"RoundNet",
	"SkipsNet",
	"OpponentNet",
	"EffectsNet",
	"TrapsNet",
	"AnimatingNet",
}

-- Runs every update() in PVP.FRAME_ORDER. A module missing here is a load error and should fail loudly.
function PVP.update_nets()
	for _, name in ipairs(PVP.FRAME_ORDER) do
		PVP[name].update()
	end
end

local update = Game.update
function Game:update(dt)
	update(self, dt)
	PVP.update_nets()
end
