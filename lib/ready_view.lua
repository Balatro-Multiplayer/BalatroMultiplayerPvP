-- Pure rules for the server-owned Ready and blind start.
--
-- The server keeps who is ready and when a blind starts in the "pvp.ready" match
-- state (contract: pvp.ready). Every client reads that state: it shows Ready from
-- `ready`, and starts the blind when `lastStart.roundId` is beyond the round this
-- process already started in the current run, whether the news came as a push or in
-- a snapshot. No game state, requests or UI here: pvp_api/ready_net.lua feeds this
-- module and acts on the answer.
--
-- A record is { run_id, started }: the run it belongs to and the highest round this
-- client has started (or was already in when it first saw the run).

PVP.ReadyView = {}
local ReadyView = PVP.ReadyView

local is_table = PVP.StateValue.is_table
local same_run = PVP.StateValue.same_run
local unmatched_run = PVP.StateValue.unmatched_run

local function contains(list, id)
	if not is_table(list) then return false end
	for _, entry in ipairs(list) do
		if entry == id then return true end
	end
	return false
end

-- The blind to start from a `lastStart`: the round id, who readied first (an id, or nil when
-- nobody did, in every lobby size) and `players`, the ids that were ready when it started. The
-- server always sends the list; a `lastStart` without one is an error (starts_here refuses it).
-- Hands are not part of a start: the server learns them from pvp.blind_start
-- (pvp_api/blind_start_net.lua).
local function build_start(last)
	return {
		round_id = tonumber(last.roundId),
		first_player = last.firstPlayer,
		players = last.players,
	}
end

-- Whether `my_id` is shown as ready in the state value.
function ReadyView.i_am_ready(value, my_id)
	return is_table(value) and is_table(value.ready) and value.ready[my_id] == true
end

-- Decides from the state value, this client's record and the run the lobby says is
-- current: returns `start` (a blind to start now, or nil) and the record to keep.
-- A value of another run than the current one is stale and changes nothing. With no
-- record for the run (a fresh process, or a new run) the `lastStart` already there counts as
-- started only when `my_id` is in its players: that blind began without this process, which
-- rejoined it. A start this player was never in is not started here.
function ReadyView.decide(value, record, current_run_id, my_id)
	if not is_table(value) or value.runId == nil then return nil, record end
	local run_id = tostring(value.runId)
	if unmatched_run(value, current_run_id) then return nil, record end
	local last = is_table(value.lastStart) and value.lastStart or nil
	local last_round = last and tonumber(last.roundId) or nil
	if record == nil or record.run_id ~= run_id then
		local started = last_round ~= nil and contains(last.players, my_id) and last_round or 0
		return nil, { run_id = run_id, started = started }
	end
	if last_round and last_round > record.started then
		return build_start(last), { run_id = run_id, started = last_round }
	end
	return nil, record
end

-- Whether this client starts a blind now: its id is in `started_players`, the ids that were ready
-- when the round started (a spectator, or a player who came back after the start, is not), it has
-- not been eliminated, and it is in a run (`in_run`). The list is always sent: a start without
-- one is an error, answered with false (the caller logs it).
function ReadyView.starts_here(started_players, my_id, eliminated, in_run)
	if eliminated or not in_run then return false end
	return contains(started_players, my_id)
end

-- The round id to put back in PVP.GAME after a rejoin wiped it, or nil when there is nothing to
-- restore: the server's `lastStart.roundId` of this run, when this player is in its players (a
-- blind this process did not start, so no start comes to set it).
function ReadyView.restored_round_id(round_id, value, run_id, my_id)
	if round_id ~= nil or not is_table(value) or not same_run(value, run_id) then return nil end
	local last = value.lastStart
	if not is_table(last) or not contains(last.players, my_id) then return nil end
	return tonumber(last.roundId)
end

-- The run and the next round a Ready or Unready is for. The run is the lobby's; the round counts on
-- from the state of that same run. The round is nil when the lobby's run is unknown, there is no state
-- of this run, or it has no numeric `round`: nothing is sent then (no run and no round is assumed).
local function target(value, current_run_id)
	local run_id = current_run_id ~= nil and tostring(current_run_id) or nil
	if not is_table(value) or run_id == nil or not same_run(value, run_id) then return run_id, nil end
	local round = tonumber(value.round)
	return run_id, round ~= nil and round + 1 or nil
end

-- `blind_key` is the blind the Ready is pressed on ("<ante>:<blind>", as pvp.blind names
-- it); the server refuses a Ready on a blind that is not a PvP blind. nil when the round
-- is unknown.
function ReadyView.ready_payload(value, current_run_id, blind_key)
	local run_id, round_id = target(value, current_run_id)
	if round_id == nil then return nil end
	return { runId = run_id, roundId = round_id, blindKey = blind_key }
end

function ReadyView.unready_payload(value, current_run_id)
	local run_id, round_id = target(value, current_run_id)
	if round_id == nil then return nil end
	return { runId = run_id, roundId = round_id }
end

-- After a snapshot: the server dropped our Ready while we were away, so press it
-- again if we still mean it and are still on the blind-select screen.
function ReadyView.should_resend_ready(value, my_id, wanted, on_blind_select, eliminated)
	return is_table(value)
		and wanted == true
		and on_blind_select == true
		and not eliminated
		and not ReadyView.i_am_ready(value, my_id)
end
