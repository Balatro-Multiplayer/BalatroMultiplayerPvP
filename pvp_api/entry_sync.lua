-- Client side of entering a PvP blind:
--   choose readiness -> repeat that choice while waiting -> accept one round start.
-- The choice is game state. Its retry clock and accepted start are delivery state;
-- neither belongs in the choice we send to the host.
-- On the other side, referee_on_entry_sync either records this choice or returns
-- the round start already saved by commit_round_start in referee.lua.
local RETRY_SECONDS = 2
local BLIND_INDEX = { Small = 1, Big = 2, Boss = 3 }

function PVP.entry_run_id()
	local lobby = MPAPI.get_current_lobby()
	local started = lobby and lobby._game and lobby._game.started
	return started and started.run_id and tostring(started.run_id)
end

function PVP.same_blind(a, b)
	return a and b and a.run_id == b.run_id and a.step == b.step
end

function PVP.same_choice_version(a, b)
	return PVP.same_blind(a, b) and a.client_id == b.client_id and a.revision == b.revision
end

local function current_blind()
	local run_id = PVP.entry_run_id()
	local resets = G.GAME and G.GAME.round_resets
	local blind = G.GAME and BLIND_INDEX[G.GAME.blind_on_deck]
	if not run_id or not resets or not blind then return end
	-- Keep the existing wire representation: step identifies an ante/blind pair.
	return { run_id = run_id, step = resets.ante * 3 + blind }
end

function PVP.current_readiness_choice()
	local delivery = PVP.GAME.entry_sync
	return delivery and delivery.choice
end

-- A button press replaces the choice and advances its version. A resend does not.
function PVP.set_blind_readiness(ready, starting_hands)
	local blind = current_blind()
	if not blind then return end
	local lobby = MPAPI.get_current_lobby()
	lobby._pvp_entry_client_id = lobby._pvp_entry_client_id or MPAPI.generate_id()
	local previous = PVP.current_readiness_choice()
	local choice = {
		run_id = blind.run_id,
		step = blind.step,
		client_id = lobby._pvp_entry_client_id,
		revision = PVP.same_blind(previous, blind) and previous.revision + 1 or 1,
		ready = ready,
		starting_hands = starting_hands or (previous and previous.starting_hands),
		round_protocol = 1,
	}
	PVP.GAME.entry_sync = { choice = choice, lobby = lobby, retry_in = RETRY_SECONDS }
	return choice
end

local function still_waiting_at_blind(delivery, lobby)
	if
		not delivery
		or delivery.lobby ~= lobby
		or not lobby
		or lobby.mod_id ~= PVP.id
		or G.STAGE ~= G.STAGES.RUN
		or G.STATE ~= G.STATES.BLIND_SELECT
		or PVP.GAME.eliminated
		or PVP.GAME.pvp_countdown_in_progress
		or delivery.accepted_start_id
	then
		return false
	end
	return PVP.same_blind(delivery.choice, current_blind())
end

function PVP.update_entry_sync(dt)
	local delivery = PVP.GAME.entry_sync
	local lobby = MPAPI.get_current_lobby()
	if not still_waiting_at_blind(delivery, lobby) then return end
	delivery.retry_in = delivery.retry_in - dt
	if delivery.retry_in > 0 then return end
	delivery.retry_in = RETRY_SECONDS
	-- Separate wire action: old hosts ignore retries rather than treating them
	-- as a fresh legacy Ready for the next round.
	lobby:action(MPAPI.ActionTypes.pvp_entry_sync):broadcast(delivery.choice)
end

-- Called by the host-filtered action handler in actions/blind_handshake.lua.
function PVP.accept_round_start(start, host_id)
	local lobby = MPAPI.get_current_lobby()
	if not lobby or PVP.GAME.eliminated then return end
	local expected = start.entries and start.entries[lobby.player_id]
	if expected then
		local delivery = PVP.GAME.entry_sync
		-- entry_id is the committed round's ID. The separate wire round_id is
		-- absent when legacy scoring disables report recovery, not entry recovery.
		local start_id = start.entry_id
		if delivery and delivery.accepted_start_id == start_id then return end
		local round = PVP.GAME.round_sync
		if round and round.id == start.round_id then return end
		if
			not PVP.same_blind(PVP.current_readiness_choice(), expected)
			or not PVP.GAME.next_blind_context
			or G.STATE ~= G.STATES.BLIND_SELECT
		then
			return
		end
		delivery.accepted_start_id = start_id
	end
	if PVP.begin_round_sync(start.round_id, host_id) == false then return end

	-- The existing countdown/start UI uses host/guest labels, not player IDs.
	local me = lobby.is_host and "host" or "guest"
	local other = lobby.is_host and "guest" or "host"
	local first_player = (start.first_player == lobby.player_id) and me or other
	local target_id = PVP.current_target_id()
	local starting_hands = target_id and start.starting_hands and start.starting_hands[target_id]
	PVP.dispatch_action("startBlind", { firstPlayer = first_player, startingHands = starting_hands })
end

local update = Game.update
function Game:update(dt)
	update(self, dt)
	PVP.update_entry_sync(dt)
	PVP.update_referee_checkpoint(dt)
end
