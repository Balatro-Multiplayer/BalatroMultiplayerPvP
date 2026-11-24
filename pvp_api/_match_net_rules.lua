-- The decisions of the match net: input bodies, resends, the next inbox item, safe points, join keys,
-- when a game gets its run record. Pure: plain values in, plain values out, no game and no net.
-- match_net.lua is the shell that calls these.
local rules = {}
PVP.match_net_rules = rules

local RESEND_GAPS = { 0.5, 1, 2, 4, 4 }
local RESEND_GAP_AFTER = 4

local function copy_table(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do
		out[key] = copy_table(item)
	end
	return out
end

-- The kinds sent with no run: the team pick, the host's lobby settings, and the lobby's Ready and Start. They carry no run id.
local BEFORE_RUN = { team = true, lobbySettings = true, lobbyReady = true, lobbyStart = true }

function rules.is_before_run(kind)
	return BEFORE_RUN[kind] == true
end

-- The input as it goes on the wire. Its bytes are fixed here; a resend sends this same table.
function rules.make_input(number, inbox_done, run_id, kind, body)
	if type(kind) ~= "string" or kind == "" then return nil, "the kind must be text" end
	if body ~= nil and type(body) ~= "table" then return nil, "the body must be a table" end
	if not (PVP.view.whole(number) and PVP.view.whole(inbox_done)) then return nil, "the header numbers must be whole" end
	local input = copy_table(body or {})
	input.kind, input.messageNumber, input.inboxDone, input.runId = kind, number, inbox_done, run_id
	return input
end

function rules.new_waiting_input(input, now)
	return { input = input, resends = 0, next_at = now + RESEND_GAPS[1] }
end

function rules.drop_confirmed(unconfirmed, last_input_received)
	local kept = {}
	for _, waiting in ipairs(unconfirmed) do
		if waiting.input.messageNumber > last_input_received then kept[#kept + 1] = waiting end
	end
	return kept
end

-- Everything unconfirmed, oldest first, once the oldest is due; nothing before.
function rules.due(unconfirmed, now)
	if unconfirmed[1] and unconfirmed[1].next_at <= now then return unconfirmed end
	return {}
end

function rules.mark_sent(waiting, now, delivered)
	if delivered then waiting.resends = waiting.resends + 1 end
	waiting.next_at = now + (delivered and (RESEND_GAPS[waiting.resends + 1] or RESEND_GAP_AFTER) or RESEND_GAPS[1])
end

-- Nil when the view has every field net reads, else what is missing.
function rules.view_problem(view)
	if type(view) ~= "table" then return "not a table" end
	if not PVP.view.whole(view.lastMessageReceived) then return "lastMessageReceived is missing or not a whole number" end
	if type(view.serverTime) ~= "number" then return "serverTime is missing" end
	if type(view.onlyMine) ~= "table" or type(view.onlyMine.inbox) ~= "table" then return "onlyMine.inbox is missing" end
	if type(view.match) ~= "table" then return "match is missing" end
	return nil
end

function rules.larger_offset(current, server_time, now_milliseconds)
	local offset = server_time - now_milliseconds
	if current == nil or offset > current then return offset end
	return current
end

-- What the inbox has next for the run the number was saved in. Returns { outcome, item, skipped_to, held }:
--   "run": the item numbered exactly last-item-done + 1 (item).
--   "wait for missing": that item is not there and the inbox goes on higher (skipped_to, the lowest
--     number above); the caller logs it and waits.
--   "all done": nothing next, and the inbox still holds items at or below last-item-done.
--   "nothing": nothing next and nothing held (no run record, no run, or an empty inbox).
-- held is "done items" when the inbox holds an item at or below last-item-done, else "none".
function rules.next_item(view, pvp_net)
	local run = PVP.view.run(view)
	if type(pvp_net) ~= "table" or type(run) ~= "table" or run.id == nil or pvp_net.runId ~= run.id then
		return { outcome = "nothing", held = "none" }
	end
	if not PVP.view.whole(pvp_net.inboxDone) then return { outcome = "nothing", held = "none" } end
	local wanted, lowest_above, holds_done
	for _, item in ipairs(view.onlyMine.inbox) do
		local number = type(item) == "table" and item.itemNumber
		if number == pvp_net.inboxDone + 1 then
			wanted = item
		elseif PVP.view.whole(number) and number > pvp_net.inboxDone and (not lowest_above or number < lowest_above) then
			lowest_above = number
		elseif PVP.view.whole(number) and number <= pvp_net.inboxDone then
			holds_done = true
		end
	end
	local held = holds_done and "done items" or "none"
	if wanted then return { outcome = "run", item = wanted, held = held } end
	if lowest_above then return { outcome = "wait for missing", skipped_to = lowest_above, held = held } end
	return { outcome = holds_done and "all done" or "nothing", held = held }
end

function rules.is_safe_point(context)
	if not context.run_live then return false end
	return context.safe_states[context.state] == true
end

-- The comeback bonus is read when a blind's evaluation is worked out, and a lost PvP blind goes from its
-- last hand straight to that evaluation, so this item also runs at the entry to it.
local RUNS_AT_BLIND_EVAL = { comebackBonus = true }

function rules.may_run(item, context)
	if rules.is_safe_point(context) then return true end
	if context.run_live ~= true then return false end
	return context.blind_eval_entry == true and RUNS_AT_BLIND_EVAL[item.effect] == true
end

-- A Run save is put off while a join has no first view yet (the loaded run is held) or an item is
-- waiting or running. Unconfirmed inputs do not put it off: the save holds them (saved_inputs).
function rules.save_must_wait(context)
	if context.join ~= "joined" then return false end
	return not context.has_view or context.busy
end

-- The inputs of the run that the save carries: the unconfirmed ones with a run id, as plain data.
function rules.saved_inputs(unconfirmed)
	local saved = {}
	for _, waiting in ipairs(unconfirmed) do
		if waiting.input.runId ~= nil then saved[#saved + 1] = copy_table(waiting.input) end
	end
	return saved
end

-- The unconfirmed inputs after a load: the ones the save holds for this run that are not already
-- waiting, added in number order. The server ignores a number it has already seen.
function rules.with_saved_inputs(unconfirmed, saved, run_id, now)
	if type(saved) ~= "table" or run_id == nil then return unconfirmed end
	local have = {}
	for _, waiting in ipairs(unconfirmed) do
		have[waiting.input.messageNumber] = true
	end
	local out = {}
	for _, waiting in ipairs(unconfirmed) do
		out[#out + 1] = waiting
	end
	for _, input in ipairs(saved) do
		if type(input) == "table" and input.runId == run_id and PVP.view.whole(input.messageNumber) and not have[input.messageNumber] then
			have[input.messageNumber] = true
			out[#out + 1] = rules.new_waiting_input(copy_table(input), now)
		end
	end
	table.sort(out, function(a, b) return a.input.messageNumber < b.input.messageNumber end)
	return out
end

-- Both join keys or neither; the server refuses one alone.
function rules.join_keys(pvp_net)
	if type(pvp_net) == "table" and type(pvp_net.runId) == "string" and PVP.view.whole(pvp_net.inboxDone) then
		return { pvp_run = pvp_net.runId, pvp_inbox_done = string.format("%d", pvp_net.inboxDone) }
	end
	return {}
end

-- The run id a fresh game's record starts with, or nil. A view of the run this client already had a
-- record for is a view of the run before (a restart, a rematch): the server made a new id for the
-- new run, and an input with the old one is refused.
function rules.run_to_start(facts)
	if facts.has_record or type(facts.view_run_id) ~= "string" then return nil end
	if facts.view_run_id == facts.previous_run_id then return nil end
	return facts.view_run_id
end

-- Only a run started fresh in a lobby the server referees has a record to start; a load has its own.
function rules.wants_record(facts)
	return facts.server_lobby == true and not facts.practice and not facts.load
end

-- Whether this start is a load: the Run save the API staged for it, or one the caller passed. The API
-- hands its staged save to the original start_run, so it has to be asked before that call.
function rules.is_load(args, staged)
	return staged == true or (type(args) == "table" and args.savetext ~= nil)
end

-- Whether to warn that a fresh game still has no run in the view: once, after `after` seconds.
-- waiting is { since, warned = "not yet" | "warned" }.
function rules.wait_warning_due(waiting, now, after)
	return waiting.warned == "not yet" and now - waiting.since >= after
end

return rules
