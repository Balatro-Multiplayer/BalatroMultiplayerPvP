-- Traps over the server's "pvp.traps" match state.
--
-- The server owns every trap: a plant is a request (lib/trap_utils.lua PVP.TRAP.plant, numbered by
-- pvp_api/opponent_net.lua), the server assigns the id, the owner and the holders, and this client builds the
-- traps it holds from the record, reports a fire or a loss by request, and pays the reward of a trap it
-- planted once the record says it fired. lib/trap_utils.lua decides what to build and consume
-- (PVP.TRAP.reconcile_plan), lib/applied_trap_rewards.lua decides which rewards are due (the ids paid are
-- PVP.GAME.trap_rewards_applied, saved with the run and carried across a crash rejoin); this file gathers
-- and acts. Rebuilding from the record, not from a message, is what keeps a plant made while this client
-- was reconnecting. Everything waits for an apply point (PVP.OpponentNet.can_apply).

local KEY = "pvp.traps"

PVP.TrapsNet = PVP.TrapsNet or {}
local N = PVP.TrapsNet
local pvp_lobby = PVP.NetBasics.pvp_lobby

local dirty = true
local handled_value, handled_game = nil, nil
-- Ids with a request in flight, so a report is never sent twice at once. Memory only: the report itself is in
-- the saved record (PVP.GAME.traps_sent), which is what a crash or a lost connection resends from.
local inflight = {}

local function log_error(text)
	PVP.match_log("info", "[pvp] error: " .. text)
end

local function entry_of(id)
	local record = PVP.GAME.traps_sent
	return type(record) == "table" and record.ids and record.ids[tostring(id)] or nil
end

local function send(id, entry)
	inflight[tostring(id)] = true
	local payload = { runId = PVP.current_run_id(), trapId = id }
	-- Absent, not empty, for the keys that carry no data.
	payload.data = entry.data
	MPAPI.request(entry.kind, payload, function(ok, result)
		inflight[tostring(id)] = nil
		if ok then return end
		local reason = result
		if type(result) == "table" then reason = result.reason end
		reason = tostring(reason)
		-- A report of another run than the current one is dead: the record it belonged to is gone.
		if payload.runId ~= PVP.current_run_id() then return end
		if reason == "bad_payload" and entry.kind == "pvp.trap_fire" then
			-- The server will not take this fire's shape. Settle the trap as lost, with no reward, so the
			-- record does not stay live under a card that is gone.
			log_error(entry.kind .. " " .. tostring(id) .. " refused: " .. reason .. "; reporting it lost")
			PVP.TRAP.remember_report(id, "pvp.trap_lost")
		elseif reason == "bad_payload" or reason == "not_holder" or reason == "already_fired" then
			-- Final: stop resending. The entry stays in the record (marked) so the card is not rebuilt before the
			-- record settles the trap.
			entry.given_up = true
			if reason == "already_fired" then
				PVP.match_log("debug", "[pvp] " .. entry.kind .. " " .. tostring(id) .. " refused: already_fired")
			else
				log_error(entry.kind .. " " .. tostring(id) .. " refused: " .. reason .. "; given up")
			end
		else
			-- Not final (not_connected, not_running, wrong_run, unknown_trap, round_over ...): stays in the record
			-- and N.resend tries it again at the next connect or change of the record.
			PVP.match_log("debug", "[pvp] " .. entry.kind .. " " .. tostring(id) .. " refused for now: " .. reason)
		end
	end)
end

-- Sends the report kept for trap `id` when this is a live attached run and none is in flight. Otherwise it
-- waits in the record (N.resend sends it later).
function N.report(id)
	local entry = entry_of(id)
	if type(entry) ~= "table" or inflight[tostring(id)] then return end
	if not PVP.OpponentNet.is_live() then return end
	send(id, entry)
end

-- Sends every kept report whose trap the record still says is live: what a catch-up, a lost connection or a
-- crash left unsent. A trap the record already settled is not sent (the reconcile forgets it).
function N.resend()
	local record = PVP.GAME.traps_sent
	local value = MPAPI.get_state(KEY)
	if type(record) ~= "table" or not record.ids or not PVP.StateValue.same_run(value, PVP.current_run_id()) then return end
	for _, report in ipairs(PVP.TRAP.pending_reports(value, record.ids)) do
		N.report(report.id)
	end
end

local function pay(reward)
	local handler = PVP.TRAP.REWARDS[reward.key]
	if not handler then return log_error("trap " .. tostring(reward.id) .. " has no reward for key " .. tostring(reward.key)) end
	local paid, reason = handler(reward.data)
	if paid == false then
		PVP.match_log("info", "[pvp] trap " .. tostring(reward.id) .. " (" .. tostring(reward.key) .. ") reward refused: " .. tostring(reason))
	end
end

-- Pays the rewards of my fired traps that were not paid yet, each once.
function N.pay_rewards()
	local lobby = pvp_lobby()
	if not lobby then return end
	local ctx = { my_id = lobby.player_id, run_id = PVP.current_run_id(), can_apply = PVP.OpponentNet.can_apply() }
	local rewards, applied, malformed = PVP.AppliedTrapRewards.step(MPAPI.get_state(KEY), PVP.GAME.trap_rewards_applied, ctx)
	if malformed then log_error(malformed .. " fired traps have no id") end
	PVP.GAME.trap_rewards_applied = applied
	for _, reward in ipairs(rewards) do
		pay(reward)
	end
end

-- Applies the record at an apply point, once per change: the rewards due, then the cards.
function N.apply()
	if not PVP.RunGate.loaded() then return end
	local value = MPAPI.get_state(KEY)
	if value ~= handled_value or PVP.GAME ~= handled_game then dirty = true end
	if not dirty or not PVP.OpponentNet.can_apply() then return end
	dirty = false
	handled_value, handled_game = value, PVP.GAME
	N.pay_rewards()
	PVP.TRAP.reconcile()
	N.resend()
end

-- CONNECTED (the lobby attached, or the socket back): the record is read again (a plant may have been made
-- while this client was away) and the reports kept in the saved record go out.
function N.on_connected()
	dirty = true
	N.resend()
end

-- Per frame (pvp_api/frame.lua).
function N.update()
	N.apply()
end

if MPAPI.on_state then
	MPAPI.on_state(KEY, function()
		dirty = true
		PVP.TRAP_ROW.refresh()
	end)
end

PVP.OpponentNet.on_connected(N.on_connected)
