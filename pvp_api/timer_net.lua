-- The timers over the server's deadline ("pvp.round".deadline).
--
-- Pressing the timer button is a request (MPAPI.request): pvp.timer_start or pvp.timer_pause.
-- The server says who is timed and by whom; this file reads that state and writes the flags the
-- timer box already reads (PVP.GAME.timer_started: I started it, nemesis_timer_started: I am
-- being timed). lib/timer_view.lua decides; this file gathers and acts.
--
-- The server counts every clock, this client only draws them. A deadline with a time of its own (the
-- Ante bank, the PvP hand timer) carries the time left, which N.shown_seconds counts down for the
-- box every frame; at 0 nothing is sent, the server decides the run-out. A deadline with no time (a
-- personal-clock ruleset: Pressure, Speedlatro) only says who is timed; the clocks are
-- "pvp.clocks" (pvp_api/clocks_net.lua).
--
-- A state with a new `n` starts or restarts the countdown; the same `n` again leaves it alone
-- (a push carries the time frozen at the n's start, not the time left). The exception is a pause:
-- a push with `paused` holds the time it carries, and the push that ends it goes on from that
-- held time (TimerView.keep_time). A snapshot (join, rejoin) always starts it again from its own,
-- live, time left.

local KEY = "pvp.round"

PVP.TimerNet = PVP.TimerNet or {}
local N = PVP.TimerNet

-- Seconds on the countdown's clock; a test swaps it.
N.clock = function()
	return love.timer.getTime()
end

-- The mutable state of this module, all of it (everything else is read from the match state):
--   seen_n:           the n last applied, so a repeat of it is told from a new start; nil while no
--                     deadline runs.
--   current:          { deadline, arrived, announce } of the deadline this client counts or shows;
--                     nil when none, and after stop(). `arrived` (the clock's seconds when the
--                     countdown began) is only set when a countdown starts again.
--   snapshot_pending: set when the lobby announces a snapshot; the next evaluation takes the
--                     deadline as one.
local seen_n = nil
local current = nil
local snapshot_pending = false

local pvp_lobby = PVP.NetBasics.pvp_lobby
local of_other_run = PVP.StateValue.of_other_run

local function request(kind, payload)
	MPAPI.request(kind, payload, PVP.NetBasics.refusal_logger(kind))
end

-- Starts a timer against the opponents who are not ready: kind "ante" before a PvP blind, kind "pvp"
-- in the PvP blind. The server refuses what is not allowed (no timer on the ruleset, nothing
-- to time); the state shows what it did.
function N.start(kind)
	if not pvp_lobby() then return end
	local run_id = PVP.current_run_id()
	if not run_id then return end
	local payload = { runId = run_id, kind = kind }
	if kind == "pvp" then payload.roundId = PVP.GAME.round_id end
	request("pvp.timer_start", payload)
end

function N.pause()
	if not pvp_lobby() then return end
	local run_id = PVP.current_run_id()
	if not run_id then return end
	request("pvp.timer_pause", { runId = run_id })
end

-- The sound of a started timer, per the player's setting (1 always, 2 once per ante).
function N.start_sound()
	local option = PVP.config.timersfx or 1
	local ante = G.GAME.round_resets.ante
	local play = (option == 1) or (option == 2 and G.timer_ante ~= ante)
	G.timer_ante = ante
	if not play then return end
	for i = 1, 3 do
		G.E_MANAGER:add_event(Event({
			blocking = false,
			blockable = false,
			trigger = "after",
			delay = G.SETTINGS.GAMESPEED * (0.15 * (i - 1)),
			func = function()
				play_sound("timpani", 0.55 + 0.25 * i, 0.7)
				play_sound("generic1", 0.75 + 0.25 * i, 0.7)
				return true
			end,
		}))
	end
end

-- The deadline of a "pvp.round" value, for the open run only; nil when there is none.
local function deadline_of(value, run_id)
	if type(value) ~= "table" or type(value.deadline) ~= "table" then return nil end
	if of_other_run(value, run_id) then return nil end
	return value.deadline
end

-- What this client sees of the current deadline right now.
local function read(lobby)
	return PVP.TimerView.read(
		current.deadline,
		lobby.player_id,
		N.clock() - current.arrived,
		PVP.UTILS.timer_display_threshold()
	)
end

local function show(view)
	PVP.GAME.timer_started = view.started_by_me
	PVP.GAME.nemesis_timer_started = view.timed_me and view.running
end

-- The start sound, once per start, when the timer becomes visible to this player: at once for
-- the starter, and for a timed player once the time is at or below the display threshold.
local function announce(view)
	if not current.announce then return end
	if view.started_by_me or (view.timed_me and view.running) then
		current.announce = false
		N.start_sound()
	end
end

-- A snapshot (join, rejoin): the countdown starts from the snapshot's own, live, time left.
-- No start sound: the player did not just start it.
local function take_snapshot(deadline)
	current = { deadline = deadline, arrived = N.clock(), announce = false }
end

-- A push with a new n: the first deadline since none ran (announced), or a restart of one that
-- ran before.
local function start_pushed_n(deadline, previous_n)
	current = { deadline = deadline, arrived = N.clock(), announce = previous_n == nil }
end

-- A push of the same n carries the time frozen at the n's start, never the time left: only who is
-- timed is refreshed, the countdown keeps the time it began with. A pause, and the push that ends
-- it, move the countdown's arrival.
local function follow_push_of_same_n(deadline)
	local kept, restart = PVP.TimerView.keep_time(current.deadline, deadline)
	local arrived = current.arrived
	if restart then arrived = N.clock() end
	current = { deadline = kept, arrived = arrived, announce = current.announce }
end

-- Reads the state: a deadline gone clears both flags; a snapshot or a new n begins the
-- countdown; the same n only refreshes who is timed.
function N.evaluate()
	local lobby = pvp_lobby()
	if not lobby then return end
	local deadline = deadline_of(MPAPI.get_state(KEY), PVP.current_run_id())
	-- The first value read after a snapshot is the snapshot's own; whatever follows is a push.
	local snapshot = snapshot_pending
	snapshot_pending = false
	if not deadline then
		current, seen_n = nil, nil
		PVP.GAME.timer_started = false
		PVP.GAME.nemesis_timer_started = false
		return
	end
	local previous_n = seen_n
	seen_n = deadline.n
	if snapshot then
		take_snapshot(deadline)
	elseif previous_n ~= deadline.n then
		start_pushed_n(deadline, previous_n)
	elseif current then
		follow_push_of_same_n(deadline)
	else
		return
	end
	local view = read(lobby)
	show(view)
	announce(view)
end

-- Stops what this client shows of a deadline, until the next new n: the PvP blind started or
-- ended, and the server drops the deadline with it.
function N.stop()
	current = nil
	PVP.GAME.timer_started = false
	PVP.GAME.nemesis_timer_started = false
end

-- The time the timer box takes from the deadline now, in seconds: the time left from the server's number
-- and the time since it arrived, never below 0 (at 0 the box waits for the server). A paused
-- deadline stands still. nil when no deadline gives this player's box a time: none is shown, it has no time
-- of its own, or the display threshold holds the server's time back.
function N.shown_seconds()
	local lobby = pvp_lobby()
	if not lobby or current == nil then return nil end
	return read(lobby).seconds
end

-- Per frame: a timed player's box starts to run when the time falls to the display threshold, which
-- no state announces, so the flags and the start sound follow the countdown.
function N.count()
	local lobby = pvp_lobby()
	if not lobby or current == nil or not PVP.TimerView.server_counted(current.deadline) then return end
	local view = read(lobby)
	show(view)
	announce(view)
end

-- The snapshot is applied after the lobby announces it, so the state read waits for it: the next
-- evaluation takes the deadline as the snapshot's.
function N.on_snapshot()
	snapshot_pending = true
end

-- A lobby attached after a crash gets no SNAPSHOT_APPLIED: its first value is the snapshot, read
-- now, before the replayed pushes. A client already showing a deadline has nothing to catch up.
function N.on_connected()
	if current ~= nil then return end
	N.resync()
end

-- Reads who is timed again, no sound, no restart. A crash rejoin calls it once caught up
-- (lib/rejoin.lua): the catch-up may have stopped the box, or set the lobby up anew, which resets
-- the game's timer fields. No deadline shown: it is read again as a snapshot. A deadline still
-- shown keeps its countdown (the state then holds a push, whose time is frozen at the n's start)
-- and only shows who it times.
function N.resync()
	local lobby = pvp_lobby()
	if not lobby then return end
	if current == nil then
		snapshot_pending = true
		N.evaluate()
		return
	end
	show(read(lobby))
end

-- Per frame (pvp_api/frame.lua). A snapshot whose value never notified (it equalled the last one)
-- is read on the next frame.
function N.update()
	if snapshot_pending then N.evaluate() end
	N.count()
end

if MPAPI.on_state then MPAPI.on_state(KEY, N.evaluate) end
