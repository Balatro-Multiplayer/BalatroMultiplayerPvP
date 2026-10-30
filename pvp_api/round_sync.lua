-- A committed hand report survives a dropped send until the referee acknowledges it.
-- The opaque round id is fresh across runs. State lives in PVP.GAME so leaving/restarting
-- a run cancels recovery; the lobby reference also prevents sends into a different lobby.
local RETRY_SECONDS = 2
local UNCONFIRMED_SECONDS = 30

function PVP.begin_round_sync(round_id, host_id)
	if type(round_id) ~= "string" then
		PVP.GAME.round_sync = nil -- Older host: retain the legacy protocol, without retries.
		return
	end
	local previous = PVP.GAME.round_sync
	if previous and previous.id == round_id then return false end
	PVP.GAME.round_sync = {
		id = round_id,
		host_id = host_id,
		lobby = MPAPI.get_current_lobby(),
		revision = 0,
		pending = false,
		elapsed = 0,
		retry_in = 0,
		report = { round_id = round_id, revision = 0 },
	}
	return true
end

function PVP.reconcile_round(host_id)
	local round = PVP.GAME.round_sync
	if round and host_id then round.host_id = host_id end
	if not round or round.applied or not round.report then return end
	round.pending = true
	round.retry_in = 0
	round.elapsed = 0
	round.failed = false
end

function PVP.commit_round_report(report)
	local round = PVP.GAME.round_sync
	if not round then return false end
	if round.applied then return true end
	round.revision = round.revision + 1
	-- Only called at the existing committed-hand boundary. Never sample a partially
	-- scored hand on reconnect (HAND_PLAYED also includes waiting after the last hand).
	round.report = {
		round_id = round.id,
		revision = round.revision,
		score = tostring(report.score),
		handsLeft = report.handsLeft,
		skips = report.skips,
	}
	PVP.reconcile_round()
	PVP.update_round_sync(0)
	return true
end

function PVP.update_round_sync(dt)
	local round = PVP.GAME.round_sync
	local lobby = MPAPI.get_current_lobby()
	if
		not round
		or round.lobby ~= lobby
		or not lobby
		or lobby.mod_id ~= PVP.id
		or G.STAGE ~= G.STAGES.RUN
		or round.applied
		or not round.pending
		or round.failed
	then
		return
	end
	round.retry_in = round.retry_in - dt
	round.elapsed = round.elapsed + dt
	if round.elapsed >= UNCONFIRMED_SECONDS then
		round.failed = true
		sendWarnMessage("PvP round report unacknowledged: " .. round.id, "MULTIPLAYER")
		attention_text({ text = localize("k_pvp_sync_failed"), scale = 0.6, hold = 10, align = "cm", major = G.play })
		return
	end
	if round.retry_in > 0 then return end
	round.retry_in = RETRY_SECONDS
	-- A false send leaves the report pending. Even a successful socket write is not
	-- an acknowledgement: only pvp_round_state can clear it.
	lobby:action(MPAPI.ActionTypes.pvp_play_hand):send("*", round.report)
end

local function apply(key, from, params)
	local action = MPAPI.ActionTypes[key]
	action:on_receive(from, params)
end

function PVP.receive_round_state(from, state)
	local round = PVP.GAME.round_sync
	local lobby = MPAPI.get_current_lobby()
	if
		not round
		or round.lobby ~= lobby
		or round.host_id ~= from
		or G.STAGE ~= G.STAGES.RUN
		or round.id ~= state.round_id
		or round.applied
	then
		return
	end
	local accepted = state.revisions and state.revisions[lobby.player_id] or 0
	if accepted >= round.revision then
		round.pending = false
		round.failed = false
	end
	if not state.outcome then return end
	-- Mark before dispatch: outcome handlers can synchronously end/reset the run.
	round.applied = true
	round.pending = false
	for id, lives in pairs(state.lives or {}) do
		apply("pvp_player_lives", from, { player_id = id, lives = lives })
	end
	for team, lives in pairs(state.team_lives or {}) do
		apply("pvp_team_lives", from, { team_id = team, lives = lives })
	end
	if state.eliminated and state.eliminated[lobby.player_id] then
		apply("pvp_eliminated", from, { player_id = lobby.player_id })
	end
	if state.outcome.key == "pvp_end_pvp" or state.outcome.key == "pvp_win" then
		apply(state.outcome.key, from, state.outcome.params)
	end
end

local update = Game.update
function Game:update(dt)
	update(self, dt)
	PVP.update_round_sync(dt)
end
