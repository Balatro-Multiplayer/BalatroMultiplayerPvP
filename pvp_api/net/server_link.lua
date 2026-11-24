-- The match's numbered inputs up and its view down. net owns the input numbers, the inputs the
-- server has not confirmed, the newest view (net.view), the clock offset, and the inbox: which item
-- runs next, when, and the inboxDone number in G.GAME.pvp_net. It knows no feature: a feature
-- sets net.handlers[effect], sends through net.send and reads net.view. Nothing runs until
-- net.register() is called. The decisions are in _rules.lua.
local net = PVP.NET
net.handlers = {}
net.view = nil

local rules = net.rules

local WAIT_WARNING_SECONDS = 10
local SAFE_STATE_NAMES = { "BLIND_SELECT", "SHOP", "SELECTING_HAND" }

local listeners = {}
local safe_states

-- Every field of one lobby's match state; a lobby's first view starts them over.
local function fresh_state()
	return {
		lobby = nil,
		offset = nil,
		join = "not joined",
		last_input_number = nil,
		unconfirmed = {},
		item_running = nil,
		frame_event = nil,
		-- The last applied number a missing item was logged at, and the one applied went out for.
		missing_item_logged = nil,
		applied_sent = nil,
		-- Why the join just made refused its loaded save (take_refusal).
		refusal = nil,
	}
end
local state = fresh_state()

-- What outlives a lobby's reset, which runs at the first view of every lobby: the run id this client
-- already has a record for, and the fresh game waiting for its run:
-- waiting_for_run = nil | { game, since, warned = "not yet" | "warned" }.
-- A game can start before its lobby's first view, and a late gone hook of the old lobby comes after
-- the new game. Only a different G.GAME (the wait) or a started record (both) ends them.
-- before_view: the inputs before a run made ahead of their lobby's first view, { lobby, kind, body }.
-- before_run: the run inputs made by the fresh game before its run id, { game, lobby, kind, body }.
local kept = { last_run_id = nil, waiting_for_run = nil, before_view = {}, before_run = {} }

function net.clock()
	return love.timer.getTime()
end

local function warn(text)
	sendWarnMessage("[NET] " .. text, "MULTIPLAYER")
end

local function pvp_net_of_game()
	return G and G.GAME and G.GAME.pvp_net
end

local function send_once(waiting)
	local lobby = MPAPI.get_current_lobby()
	if not (lobby and lobby.mod_id == PVP.id) then return false end
	return MPAPI.send_match_input(lobby, waiting.input) and true or false
end

-- Nothing is resent before the first view after a join: that view marks every input due.
local function send_due()
	if net.view == nil then return end
	local now = net.clock()
	for _, waiting in ipairs(rules.due(state.unconfirmed, now)) do
		local delivered = send_once(waiting)
		rules.mark_sent(waiting, now, delivered)
		if not delivered then return end
	end
end

function net.save_must_wait()
	return rules.save_must_wait({
		join = state.join,
		has_view = net.view ~= nil,
		busy = net.busy(),
	})
end

-- The run's record holds the unconfirmed inputs, so a save carries them with the state they describe.
local function save_unconfirmed_in_record()
	local pvp_net = pvp_net_of_game()
	if pvp_net then pvp_net.unconfirmed = rules.saved_inputs(state.unconfirmed) end
end

-- Leaving a lobby ends its inputs: the record must not hand them to the next lobby's numbers.
local function forget_record_inputs()
	local pvp_net = pvp_net_of_game()
	if pvp_net then pvp_net.unconfirmed = {} end
end

-- The record of the fresh game, once the view shows its run. The game's own table is the only mark of
-- "this game is the fresh one": a later game of any kind drops the wait.
local function start_awaited_run()
	local game = G and G.GAME
	local waiting = kept.waiting_for_run
	if not waiting or not game then return end
	if game ~= waiting.game then
		kept.waiting_for_run = nil
		kept.before_run = {}
		return
	end
	local run = PVP.READ.view.run(net.view)
	local has_record = game.pvp_net ~= nil
	local run_id = rules.run_to_start({
		has_record = has_record,
		view_run_id = run and run.id,
		previous_run_id = kept.last_run_id,
	})
	if has_record or run_id then kept.waiting_for_run = nil end
	if run_id then
		net.start_run(run_id)
	elseif kept.waiting_for_run and rules.wait_warning_due(waiting, net.clock(), WAIT_WARNING_SECONDS) then
		waiting.warned = "warned"
		warn("the view has shown no run " .. WAIT_WARNING_SECONDS .. " seconds after the run started")
	end
end

-- Not during a blind's evaluation: a save taken there can hold a comeback bonus given and its cash-out
-- unpaid. The next view or item after it takes the save.
local function take_put_off_save()
	if net.save_must_wait() or G.STATE == G.STATES.ROUND_EVAL then return end
	local ok, err = pcall(MPAPI.run_save.save_now)
	if not ok then warn("the put-off save failed: " .. tostring(err)) end
end

local function may_run_now(item, blind_eval_entry)
	if not safe_states then
		safe_states = {}
		for _, name in ipairs(SAFE_STATE_NAMES) do
			safe_states[G.STATES[name]] = true
		end
	end
	-- A rejoin's replay is not the live run: its items wait until the replay ends.
	local replaying = MPAPI.playback.is_driving("pvp")
	return rules.may_run(item, {
		run_live = not replaying and G.STAGE == G.STAGES.RUN and G.GAME ~= nil and (blind_eval_entry or G.STATE_COMPLETE) and true or false,
		state = G.STATE,
		safe_states = safe_states,
		blind_eval_entry = blind_eval_entry,
	})
end

-- Tells the server every item up to this number is done, once per number.
local function send_applied(inbox_done)
	if state.applied_sent == inbox_done then return end
	state.applied_sent = inbox_done
	net.send("applied", {})
end

-- Runs the item's handler, then queues the event that moves the last applied number behind every
-- event the handler queued. no_delete: a cleared event queue must not lose it, or the inbox and every
-- save stay held. An item that errors or has no handler is lost and still moves the number.
local function run_item(item, pvp_net)
	local number = item.itemNumber
	state.item_running = number
	local handler = net.handlers[item.effect]
	if not handler then
		warn("item " .. number .. " has no handler for the effect " .. tostring(item.effect))
	else
		local ok, err = pcall(handler, item)
		if not ok then warn("item " .. number .. " (" .. tostring(item.effect) .. ") failed: " .. tostring(err)) end
	end
	G.E_MANAGER:add_event(Event({
		no_delete = true,
		func = function()
			state.item_running = nil
			if pvp_net_of_game() == pvp_net then
				pvp_net.inboxDone = number
				if net.view and rules.next_item(net.view, pvp_net).outcome ~= "run" then send_applied(number) end
			end
			take_put_off_save()
			return true
		end,
	}))
end

local function run_next_item(blind_eval_entry)
	if state.item_running or not net.view then return end
	local pvp_net = pvp_net_of_game()
	local next_item = rules.next_item(net.view, pvp_net)
	if next_item.outcome == "wait for missing" and state.missing_item_logged ~= pvp_net.inboxDone then
		state.missing_item_logged = pvp_net.inboxDone
		warn("item " .. (pvp_net.inboxDone + 1) .. " is not in the inbox, which goes on at " .. next_item.skipped_to .. "; waiting")
	end
	if next_item.outcome ~= "run" then
		if next_item.held == "done items" then send_applied(pvp_net.inboxDone) end
		return
	end
	if may_run_now(next_item.item, blind_eval_entry == true) then run_item(next_item.item, pvp_net) end
end

function net.update()
	start_awaited_run()
	send_due()
	run_next_item()
end

-- Called as a blind's evaluation starts: the next item runs now if it is a comeback bonus, so the
-- evaluation pays it. Any other next item, or an item still running, waits for its own safe point
-- and the bonus behind it with it: items run in number order.
function net.before_blind_eval()
	run_next_item(true)
end

local function start_frame_event()
	if state.frame_event or not (G and G.E_MANAGER and Event) then return end
	local frame_event = {}
	state.frame_event = frame_event
	G.E_MANAGER:add_event(Event({
		blocking = false,
		blockable = false,
		no_delete = true,
		func = function()
			if state.frame_event ~= frame_event then return true end
			local ok, err = pcall(net.update)
			if not ok then
				warn("stopped: " .. tostring(err))
				state.frame_event = nil
				return true
			end
			return false
		end,
	}))
end

-- Numbers the input, keeps it until the view confirms it, and sends it now. Returns its number, or
-- nil and why. Nothing is sent before the lobby's first view: the number comes from that view, and an
-- input before a run made sooner waits for it (nil, "held for the first view").
-- The kinds before a run (rules.is_before_run) never carry a run id; the server reads a missing runId as
-- "no run" for it.
function net.send(kind, body)
	local before_run = rules.is_before_run(kind)
	local pvp_net = pvp_net_of_game()
	local waiting = kept.waiting_for_run
	if not before_run and not (pvp_net and pvp_net.runId) and waiting and G.GAME == waiting.game then
		local lobby = MPAPI.get_current_lobby()
		if lobby then
			kept.before_run[#kept.before_run + 1] = { game = waiting.game, lobby = lobby, kind = kind, body = body }
			return nil, "held for the run"
		end
	end
	if state.last_input_number == nil then
		local lobby = MPAPI.get_current_lobby()
		if not (before_run and lobby) then return nil, "no view yet" end
		kept.before_view[#kept.before_view + 1] = { lobby = lobby, kind = kind, body = body }
		return nil, "held for the first view"
	end
	if not before_run and not (pvp_net and pvp_net.runId) then return nil, "no run" end
	local inbox_done, run_id = 0, nil
	if not before_run then inbox_done, run_id = pvp_net.inboxDone, pvp_net.runId end
	local input, problem = rules.make_input(state.last_input_number + 1, inbox_done, run_id, kind, body)
	if not input then
		warn("input refused: " .. problem)
		return nil, problem
	end
	state.last_input_number = input.messageNumber
	local waiting = rules.new_waiting_input(input, net.clock())
	state.unconfirmed[#state.unconfirmed + 1] = waiting
	save_unconfirmed_in_record()
	start_frame_event()
	send_once(waiting)
	return input.messageNumber
end

-- net.send for a feature's own play: nothing without a body, and nothing while a replay or a
-- fast-forward plays my run again through the same game calls (a rejoin load makes no game calls that
-- send).
function net.send_live(kind, body)
	if not body or MPAPI.playback.is_driving("pvp") then return nil end
	return net.send(kind, body)
end

-- True while an input (of this kind, or of any) is not yet confirmed.
function net.waiting(kind)
	for _, waiting in ipairs(state.unconfirmed) do
		if kind == nil or waiting.input.kind == kind then return true end
	end
	return false
end

-- The latest unconfirmed input of a kind, as sent, or nil.
function net.latest_waiting(kind)
	for index = #state.unconfirmed, 1, -1 do
		local input = state.unconfirmed[index].input
		if input.kind == kind then return input end
	end
	return nil
end

function net.busy()
	return state.item_running ~= nil or (net.view ~= nil and rules.next_item(net.view, pvp_net_of_game()).outcome == "run")
end

-- The handler of the API's view message.
function net.receive_view(lobby, view)
	local problem = rules.view_problem(view)
	if problem then return warn("view ignored: " .. problem) end
	local first_after_join = net.view == nil
	net.view = view
	for place, entry in ipairs(view.onlyMine.inbox) do
		if type(entry) ~= "table" or not PVP.READ.view.whole(entry.itemNumber) then warn("view item " .. place .. " has no whole itemNumber") end
	end
	state.offset = rules.larger_offset(state.offset, view.serverTime, net.clock() * 1000)
	state.last_input_number = state.last_input_number or view.lastMessageReceived
	-- After a load the save's own unconfirmed inputs wait again; their numbers are not made again.
	local record = pvp_net_of_game()
	if first_after_join and record then
		state.unconfirmed = rules.with_saved_inputs(state.unconfirmed, record.unconfirmed, record.runId, net.clock())
		for _, waiting in ipairs(state.unconfirmed) do
			state.last_input_number = math.max(state.last_input_number, waiting.input.messageNumber)
		end
	end
	state.unconfirmed = rules.drop_confirmed(state.unconfirmed, view.lastMessageReceived)
	save_unconfirmed_in_record()
	if first_after_join then
		for _, waiting in ipairs(state.unconfirmed) do
			waiting.next_at = net.clock()
		end
	end
	-- The inputs held for this view are numbered now, in the order made; a gone lobby's are dropped.
	local held = kept.before_view
	kept.before_view = {}
	for _, input in ipairs(held) do
		if input.lobby == lobby then net.send(input.kind, input.body) end
	end
	start_frame_event()
	start_awaited_run()
	send_due()
	run_next_item()
	for _, listener in ipairs(listeners) do
		local ok, err = pcall(listener, view)
		if not ok then warn("a view listener failed: " .. tostring(err)) end
	end
	take_put_off_save()
end

-- Server time now, from the largest offset seen since the join; nil before a view.
function net.server_now()
	return state.offset and (net.clock() * 1000 + state.offset) or nil
end

-- Every join, rejoins included: forget the view and the offset. The unconfirmed inputs are sent
-- again by the first view that follows, before any put-off save.
function net.on_join()
	net.view, state.offset, state.join = nil, nil, "joined"
end

-- Leaving the match: forget the numbers, the view and the inbox. What `kept` holds stays.
function net.reset()
	state = fresh_state()
	net.view = nil
end

-- A new run starts here, never on a load: the run id, nothing done, no totals.
function net.start_run(run_id)
	if type(run_id) ~= "string" then return nil, "the run id must be text" end
	G.GAME.pvp_net = { runId = run_id, inboxDone = 0, totals = {}, traps_gone = {} }
	kept.last_run_id = run_id
	-- The inputs the fresh game made before its run id go out now, in the order made.
	local held = kept.before_run
	kept.before_run = {}
	for _, input in ipairs(held) do
		if input.game == G.GAME and input.lobby == MPAPI.get_current_lobby() then net.send(input.kind, input.body) end
	end
	return true
end

-- Called when the game has just started a run; is_load is true for a run built from a save. A fresh
-- run in a server-refereed PvP lobby waits for the view that shows its run (start_awaited_run).
function net.game_started(is_load)
	kept.waiting_for_run = nil
	kept.before_run = {}
	local lobby = MPAPI.get_current_lobby()
	local wanted = rules.wants_record({
		server_lobby = lobby ~= nil and lobby.mod_id == PVP.id,
		practice = PVP.PRACTICE.is_on(),
		load = is_load,
	})
	if wanted then
		kept.waiting_for_run = { game = G.GAME, since = net.clock(), warned = "not yet" }
		start_frame_event()
	end
end

-- The two join keys, from the Run save about to load or, with none, from the game in memory. The API
-- asks at every join and rejoin, so this is also where a join starts and the loaded run is held.
function net.join_keys(save_to_load)
	net.on_join()
	state.refusal = nil
	local keys
	if save_to_load then
		local game = save_to_load.save and save_to_load.save.GAME
		keys = rules.join_keys(game and game.pvp_net)
		-- No keys would tell the server nothing is done and replay the whole inbox onto a run that
		-- already had it. The join has to go out, so the refusal is kept for the load (take_refusal).
		if next(keys) == nil then
			state.refusal = "the loaded save has no PvP run record, so it cannot be a PvP rejoin"
			warn("rejoin refused: " .. state.refusal)
		end
	else
		keys = rules.join_keys(pvp_net_of_game())
	end
	kept.last_run_id = keys.pvp_run or kept.last_run_id
	return keys
end

-- Why the join just made refused its loaded save, once; nil when it did not.
function net.take_refusal()
	local refusal = state.refusal
	state.refusal = nil
	return refusal
end

function net.add_view_listener(listener)
	listeners[#listeners + 1] = listener
end

-- The numbers belong to one lobby. A view of another lobby starts them over; a lobby's gone hook can
-- arrive late, after the next lobby's view, and then must not reset.
local function receive_view_of_lobby(lobby, view)
	if state.lobby ~= lobby then
		if state.lobby ~= nil then forget_record_inputs() end
		net.reset()
		net.on_join()
		state.lobby = lobby
	end
	net.receive_view(lobby, view)
end

-- The one switch: nothing above is wired to the API until this is called.
function net.register()
	MPAPI.on_match_view(PVP.id, receive_view_of_lobby)
	MPAPI.add_join_keys(PVP.id, net.join_keys)
	MPAPI.run_save.register_save_wait(PVP.id, net.save_must_wait)
	MPAPI.on_lobby_gone(PVP.id, function(lobby)
		if lobby == state.lobby then
			forget_record_inputs()
			net.reset()
		end
	end)
end

if Game and Game.start_run then
	local start_run_ref = Game.start_run
	function Game:start_run(args)
		local known, is_load = pcall(function() return rules.is_load(args, MPAPI.run_save.is_staged()) end)
		start_run_ref(self, args)
		if not known then return warn("the run's start was not noted, a load could not be told: " .. tostring(is_load)) end
		local ok, err = pcall(net.game_started, is_load)
		if not ok then warn("the run's start was not noted: " .. tostring(err)) end
	end
end

return net
