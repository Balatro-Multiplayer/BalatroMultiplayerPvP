-- Ready and the blind start over the server's "pvp.ready" match state.
--
-- Ready and Unready are requests (MPAPI.request); the Ready button reads the state
-- the server publishes (MPAPI.on_state), never a request's result, which only
-- tells us a refusal. When the last required player is ready the server records
-- `lastStart` in that state and every client starts the blind from it
-- (lib/ready_view.lua decides; this file acts).

local KEY = "pvp.ready"

PVP.ReadyNet = PVP.ReadyNet or {}
local N = PVP.ReadyNet
local pvp_lobby = PVP.NetBasics.pvp_lobby

-- The started-round record (lib/ready_view.lua). Module-level on purpose: it must
-- survive PVP.GAME resets and a socket rejoin, so a start missed during a drop is
-- still taken from the snapshot. A new process has none, which is the point.
local record = nil
local resync_pending = false

-- Reasons that only mean the state moved on: not worth telling the player.
local QUIET = { round_over = true, bad_round = true, cancelled = true }

-- A refused or failed Ready/Unready: the state shows the truth, so only drop what we
-- meant and say so unless the state simply moved on.
local function on_result(what)
	return function(ok, result)
		if ok then return end
		local reason = PVP.NetBasics.log_refusal(what, result)
		-- The state is the truth: what we mean is what the button shows, so a refused
		-- Unready does not leave the player needing two clicks.
		local lobby = MPAPI.get_current_lobby()
		PVP.GAME.ready_intent = lobby ~= nil and PVP.ReadyView.i_am_ready(MPAPI.get_state(KEY), lobby.player_id)
		if not QUIET[reason] and G.STAGE == G.STAGES.RUN then
			attention_text({
				text = localize("k_pvp_ready_failed"),
				scale = 0.6,
				hold = 4,
				align = "cm",
				major = G.play,
			})
		end
	end
end

-- The blind the Ready button on the blind-select screen is for.
local function blind_on_deck_key()
	return PVP.PendingDeath.blind_key(G.GAME.round_resets.ante, G.GAME.blind_on_deck)
end

function N.request_ready()
	if not pvp_lobby() then return end
	local payload = PVP.ReadyView.ready_payload(MPAPI.get_state(KEY), PVP.current_run_id(), blind_on_deck_key())
	if not payload then
		return PVP.match_log("info", "[pvp] error: pvp.ready not sent: the server has no round state for this run")
	end
	MPAPI.request("pvp.ready", payload, on_result("pvp.ready"))
end

function N.request_unready()
	if not pvp_lobby() then return end
	local payload = PVP.ReadyView.unready_payload(MPAPI.get_state(KEY), PVP.current_run_id())
	if not payload then
		return PVP.match_log("info", "[pvp] error: pvp.unready not sent: the server has no round state for this run")
	end
	MPAPI.request("pvp.unready", payload, on_result("pvp.unready"))
end

local function start_blind(lobby, start)
	-- The server always names who started: a list that is missing is an error, never "everyone".
	if type(start.players) ~= "table" then
		PVP.match_log("info", "[pvp] error: lastStart has no players list: the blind is not started")
		return
	end
	if not PVP.ReadyView.starts_here(start.players, lobby.player_id, PVP.GAME.eliminated, G.STAGE == G.STAGES.RUN) then
		return
	end
	-- A start while the countdown of the last one runs (a second Ready pressed during it): the blind
	-- in play is the first one, so its round id stands. A second countdown would select the blind
	-- twice and crash on the missing blind select screen.
	if PVP.GAME.pvp_countdown_in_progress then
		PVP.match_log("info", "[pvp] start of round " .. tostring(start.round_id) .. " ignored: countdown running")
		return
	end
	-- The round every hand and timer fact of this blind names.
	PVP.GAME.round_id = start.round_id
	-- The first player is an id (or nil: nobody), as the server names it.
	PVP.dispatch_action("startBlind", { firstPlayer = start.first_player })
	-- The opponent's hands for this round are the server's (the push may have come before the round id).
	PVP.EnemyScoreNet.refresh()
end

-- The Ready button follows the server's state.
local function show_ready(value, lobby)
	local ready = PVP.ReadyView.i_am_ready(value, lobby.player_id)
	if PVP.GAME.ready_blind ~= ready then
		PVP.GAME.ready_blind = ready
		PVP.GAME.ready_blind_text = ready and localize("b_unready") or localize("b_ready")
		-- Replays record what the player saw, not what they pressed.
		if PVP.RLOG and MPAPI.OPCODE then PVP.RLOG.record(MPAPI.OPCODE.READY_BLIND, ready and 1 or 0) end
	end
end

-- Reads the state: starts a blind that has not been started here, then updates the button.
-- Returns whether it started a blind.
function N.evaluate()
	local lobby = pvp_lobby()
	if not lobby then return end
	local value = MPAPI.get_state(KEY)
	local start
	local run_id = PVP.current_run_id()
	start, record = PVP.ReadyView.decide(value, record, run_id, lobby.player_id)
	if start then
		start_blind(lobby, start)
	else
		-- No start, and PVP.GAME may have no round id: a rejoin wiped it (a new process after a crash,
		-- or a reconnect in this one, where the lobby mirror reset clears PVP.GAME). The blind in
		-- play was started before, so no startBlind comes, but every hand and timer fact of it,
		-- and the round-end rule, name this round: the server's, from lastStart. Also see
		-- pvp_api/round_end_net.lua.
		local restored = PVP.ReadyView.restored_round_id(PVP.GAME.round_id, value, run_id, lobby.player_id)
		if restored then PVP.GAME.round_id = restored end
	end
	show_ready(value, lobby)
	return start ~= nil
end

-- A start that was begun but never played (its countdown was cut short by a reconnect) is given
-- back: the record forgets that round, so the next read of the state starts it again.
function N.forget_start(round_id)
	if record and record.started == round_id then record.started = round_id - 1 end
end

-- CONNECTED: a crash rejoin's first snapshot lands while the lobby is still detached, so the
-- state could not be read then; read it now.
function N.on_connected()
	N.evaluate()
	PVP.BlindStartNet.resend()
end

-- The snapshot is applied after the lobby announces it, so the work that needs the
-- fresh state waits for the next frame.
function N.on_snapshot()
	resync_pending = true
end

local function resync(lobby)
	-- Read lastStart first (it may start a blind we missed), then press Ready again.
	local started = N.evaluate()
	local value = MPAPI.get_state(KEY)
	local on_blind_select = G.STAGE == G.STAGES.RUN and G.STATE == G.STATES.BLIND_SELECT
	if
		not started
		and PVP.ReadyView.should_resend_ready(
			value,
			lobby.player_id,
			PVP.GAME.ready_intent,
			on_blind_select,
			PVP.GAME.eliminated
		)
	then
		N.request_ready()
	end
	-- The server may have lost this round's hand count while we were away.
	PVP.BlindStartNet.resend()
end

-- Per frame (pvp_api/frame.lua): the work a snapshot left for the next frame.
function N.update()
	if not resync_pending then return end
	resync_pending = false
	local lobby = pvp_lobby()
	if lobby then resync(lobby) end
end

if MPAPI.on_state then MPAPI.on_state(KEY, N.evaluate) end
