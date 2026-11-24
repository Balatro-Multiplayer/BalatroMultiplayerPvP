-- A local Run save after each action of the run (hand played, discard, consumable used), so a crash
-- loses at most the last action. MPAPI.run_save.take_local writes it to this machine only; the
-- server's copy keeps its own save points. A rejoin starts from the newer of the two.
--
-- An action marks a save due. The save is taken once the game is back at "pick a hand" with
-- nothing still running: not while the hand scores, not while an event or an inbox item is
-- running (a save then could hold an effect without the applied number that goes with it), and
-- never in a booster pack, the shop or the cash out, where the due mark is dropped.
PVP.ActionSave = {}
local AS = PVP.ActionSave

-- The states a hand, discard or consumable passes through on its way back to "pick a hand".
local HAND_LOOP = { "HAND_PLAYED", "DRAW_TO_HAND", "PLAY_TAROT", "NEW_ROUND" }

-- "ready" at a built "pick a hand", "in_hand" while the action is still working through the
-- hand's states, "elsewhere" anywhere else (packs, shop, blind select, cash out, menu).
function AS.phase(state, state_complete, states)
	if state == states.SELECTING_HAND then return state_complete and "ready" or "in_hand" end
	for _, name in ipairs(HAND_LOOP) do
		if state == states[name] then return "in_hand" end
	end
	return "elsewhere"
end

-- "busy" while an event that blocks the queue is waiting ("running": the idle rule the rejoin
-- replay uses, MPAPI.playback._queues_empty) or the match's inbox holds the save back.
function AS.work(queue, must_wait)
	if must_wait or queue == "running" then return "busy" end
	return "idle"
end

-- ctx: { in_match = boolean, phase = AS.phase(), work = AS.work() }
-- Returns "save" (take it now), "wait" (due, not yet) or "drop" (no longer due).
function AS.step(ctx)
	if not ctx.in_match or ctx.phase == "elsewhere" then return "drop" end
	if ctx.phase == "ready" and ctx.work == "idle" then return "save" end
	return "wait"
end

-- "due" from an action until its save is taken or dropped.
local mark = "none"

function AS.mark_due()
	mark = "due"
end

function AS.reset()
	mark = "none"
end

function AS.is_due()
	return mark == "due"
end

-- One frame's check. `world` gives the game's facts so the decision stays in step().
function AS.update(world)
	if mark ~= "due" then return end
	local decision = AS.step({
		in_match = world.in_match(),
		phase = AS.phase(world.state(), world.state_complete(), world.states()),
		work = AS.work(world.queue(), world.must_wait()),
	})
	if decision == "wait" then return end
	mark = "none"
	if decision == "save" then world.take() end
end

if not (G and G.FUNCS and Game) then return end

local function in_match()
	return PVP.in_session() and MPAPI.get_current_lobby() ~= nil and PVP.LOBBY.code ~= nil
end

local world = {
	in_match = in_match,
	state = function()
		return G.STATE
	end,
	state_complete = function()
		return G.STATE_COMPLETE
	end,
	states = function()
		return G.STATES
	end,
	queue = function()
		return MPAPI.playback._queues_empty() and "empty" or "running"
	end,
	must_wait = function()
		local net = PVP.match_net
		return net ~= nil and net.save_must_wait() or false
	end,
	take = function()
		if not (MPAPI.run_save and MPAPI.run_save.take_local) then return end
		local ok, err = pcall(MPAPI.run_save.take_local)
		if not ok then sendWarnMessage("[actionsave] " .. tostring(err), "ActionSave") end
	end,
}

-- "server_covers": a hand or discard in a PvP blind arrives at a pick-a-hand that already takes the
-- server's Run save (lib/run_save.lua), which also keeps the local copy, so no second save is built.
-- A consumable has no such arrival. A replayed action (the rejoin's fast-forward) marks nothing.
local function mark_after(original, coverage)
	return function(...)
		local result = original(...)
		local replaying = MPAPI.playback.is_driving("pvp")
		local covered = coverage == "server_covers" and PVP.is_pvp_boss()
		if in_match() and not replaying and not covered then AS.mark_due() end
		return result
	end
end

G.FUNCS.play_cards_from_highlighted = mark_after(G.FUNCS.play_cards_from_highlighted, "server_covers")
G.FUNCS.discard_cards_from_highlighted = mark_after(G.FUNCS.discard_cards_from_highlighted, "server_covers")
if Card and Card.use_consumeable then Card.use_consumeable = mark_after(Card.use_consumeable, "alone") end

local update_ref = Game.update
function Game:update(dt)
	update_ref(self, dt)
	AS.update(world)
end
