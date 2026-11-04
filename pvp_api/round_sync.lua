-- Hand reports use the shared ordered retry queue, but retain the existing
-- round_id/revision wire protocol and authoritative pvp_round_state responses.
-- This adapter owns snapshot semantics; the delivery core never reads a score.
local function active(round)
	local lobby = MPAPI.get_current_lobby()
	return PVP.GAME.round_sync == round and lobby and round.lobby == lobby
		and lobby.mod_id == PVP.id and G.STAGE == G.STAGES.RUN and not round.applied
end

local function sync_flags(round)
	round.pending = round.unsent ~= nil or round.delivery:head(round.host_id) ~= nil
	round.failed = round.delivery:is_stalled(round.host_id)
end

local function queue_report(round)
	if round.unsent then
		local report = round.unsent
		round.unsent = nil -- Clear before a synchronous transport can reenter.
		local seq = round.delivery:send(round.host_id, report)
		if not seq and not round.unsent then round.unsent = report end
	end
	sync_flags(round)
end

function PVP.begin_round_sync(round_id, host_id)
	local previous = PVP.GAME.round_sync
	if type(round_id) == "string" and previous and previous.id == round_id then return false end
	if previous then previous.delivery:close() end
	if type(round_id) ~= "string" then
		PVP.GAME.round_sync = nil -- Older host: retain the legacy protocol, without retries.
		return
	end
	local round = {
		id = round_id, host_id = host_id, lobby = MPAPI.get_current_lobby(),
		revision = 0, pending = false, report = { round_id = round_id, revision = 0 },
	}
	round.delivery = PVP.ReliableMessages.new({
		scope = round_id,
		transmit = function(_peer, envelope)
			if not active(round) then
				round.delivery:pause(round.host_id)
				return false
			end
			-- Reports are still broadcast through Nakama. Only the host referee
			-- processes them; existing protocol-1 clients need no wire changes.
			local sent = round.lobby:action(MPAPI.ActionTypes.pvp_play_hand):send("*", envelope.payload)
			if sent == false then
				-- The socket/rejoin layer refused the send. Keep the queue and
				-- pause its deadline until existing reconnect hooks reconcile it.
				round.delivery:pause(round.host_id)
			end
			return sent
		end,
		on_message = function() return false end, -- pvp_round_state is adapted below.
		on_timeout = function()
			sync_flags(round)
			sendWarnMessage("PvP round report unacknowledged: " .. round.id, "MULTIPLAYER")
			attention_text({ text = localize("k_pvp_sync_failed"), scale = 0.6, hold = 10, align = "cm", major = G.play })
		end,
	})
	PVP.GAME.round_sync = round
	return true
end

function PVP.reconcile_round(host_id)
	PVP.reconcile_referee_checkpoint()
	if PVP.reconcile_reliable_events then PVP.reconcile_reliable_events(true) end
	local round = PVP.GAME.round_sync
	if not round or round.applied then return end
	if host_id and host_id ~= round.host_id then
		-- Safe for this adapter's existing cumulative report protocol, not a
		-- general guarantee for arbitrary events after a host change.
		round.delivery:retarget(round.host_id, host_id)
		round.host_id = host_id
	end
	if round.delivery:head(round.host_id) then
		round.delivery:resume(round.host_id)
	elseif round.unsent then
		queue_report(round)
	elseif not round.delivery:resume(round.host_id, true) then
		-- First reconciliation before any hand: revision 0 is a state query,
		-- not a fabricated score/hands report. It gets its own queue identity.
		round.unsent = round.report
		queue_report(round)
	end
	sync_flags(round)
end

function PVP.commit_round_report(report)
	local round = PVP.GAME.round_sync
	if not round then return false end
	if round.applied then return true end
	round.revision = round.revision + 1
	-- Capture at the committed-hand boundary; never resample live score on retry.
	round.report = {
		round_id = round.id, revision = round.revision, score = tostring(report.score),
		handsLeft = report.handsLeft, skips = report.skips,
	}
	-- When the bounded queue is full retain the latest unqueued snapshot. Scores
	-- are cumulative: replacing this unqueued snapshot cannot drop a life event.
	round.unsent = round.report
	queue_report(round)
	return true
end

function PVP.update_round_sync(dt)
	local round = PVP.GAME.round_sync
	if not round or not active(round) then return end
	queue_report(round)
	round.delivery:update(dt)
	sync_flags(round)
end

local function apply(key, from, params)
	MPAPI.ActionTypes[key]:on_receive(from, params)
end

function PVP.receive_round_state(from, state)
	local round = PVP.GAME.round_sync
	local lobby = MPAPI.get_current_lobby()
	if not round or round.lobby ~= lobby or round.host_id ~= from
		or G.STAGE ~= G.STAGES.RUN or round.id ~= state.round_id or round.applied then return end
	if state.outcome then
		-- Cancel before dispatch: handlers can synchronously end/reset the run.
		-- Final authoritative state supersedes any queued interim score snapshots.
		round.applied, round.pending, round.failed, round.unsent = true, false, false, nil
		round.delivery:close()
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
		return
	end
	local accepted = state.revisions and state.revisions[lobby.player_id] or 0
	local seq, report = round.delivery:head(round.host_id)
	-- Wire revisions and queue sequences differ when a revision-0 query was
	-- queued. Only an authoritative revision covering the sent head can ACK it.
	if seq and type(accepted) == "number" and accepted >= report.revision
		and accepted < math.huge and accepted % 1 == 0 then
		round.delivery:acknowledge(round.host_id, seq)
		queue_report(round)
	end
	sync_flags(round)
end

local update = Game.update
function Game:update(dt)
	update(self, dt)
	PVP.update_referee_checkpoint(dt)
	if PVP.update_reliable_events then PVP.update_reliable_events(dt) end
	PVP.update_round_sync(dt)
end
