-- Pure rules for the server's timer deadline ("pvp.round".deadline): who it times, who
-- started it, and how many seconds the timer box shows. No game state, requests or
-- clock here: pvp_api/timer_net.lua feeds this module and acts on the answer.
--
-- A deadline is { kind = "ante"|"pvp", by = id, against = { id, ... }, remainingMs = number|nil, n = number,
-- paused = true|nil }.
-- `remainingMs` is set when the server counts the time of the deadline (the Ante bank, the PvP hand
-- timer); nil is a deadline with no time of its own: on a personal-clock ruleset (Pressure,
-- Speedlatro) it only marks who is timed, and the clocks are the server's "pvp.clocks". `paused` is
-- set while a timed player is disconnected: the server holds the time, `remainingMs` is the frozen
-- time left, and the box shows it standing still until the next state without `paused`.

PVP.TimerView = {}
local TimerView = PVP.TimerView

local function contains(list, id)
	for _, value in ipairs(list or {}) do
		if value == id then return true end
	end
	return false
end

-- Whether the deadline carries a time of its own.
function TimerView.server_counted(deadline)
	return deadline ~= nil and type(deadline.remainingMs) == "number"
end

-- Whether the server holds this deadline's time: it carries a time and a timed player is
-- disconnected.
function TimerView.paused(deadline)
	return TimerView.server_counted(deadline) and deadline.paused == true
end

-- The seconds left on a deadline with a time `elapsed` seconds after it arrived,
-- never below 0; nil for a deadline with no time or none. A paused deadline stands still at its
-- frozen time, whatever the elapsed time.
function TimerView.remaining(deadline, elapsed)
	if not TimerView.server_counted(deadline) then return nil end
	if TimerView.paused(deadline) then return math.max(0, deadline.remainingMs / 1000) end
	return math.max(0, deadline.remainingMs / 1000 - math.max(0, elapsed or 0))
end

-- The deadline to count from after a push of the same `n` as the one in `kept`, and whether the
-- countdown's arrival time starts again. A same-n push carries the time frozen at the n's start,
-- never the time left, so the countdown keeps the time it has; only the pause changes it:
--   a paused push        takes its frozen time and holds it (the arrival restarts)
--   the push after one   resumes from the frozen time it held (the arrival restarts)
function TimerView.keep_time(kept, pushed)
	if TimerView.paused(pushed) then return pushed, true end
	local copy = {}
	for name, value in pairs(pushed) do
		copy[name] = value
	end
	copy.remainingMs = kept.remainingMs
	return copy, TimerView.paused(kept)
end

local function not_involved()
	return { running = false, timed_me = false, started_by_me = false, seconds = nil, paused = false }
end

-- What `my_id` sees of `deadline`, `elapsed` seconds after it arrived:
--   started_by_me  I pressed it
--   timed_me       I am one of the players it times
--   running        my timer box counts: always for the starter, for a timed player only once the
--                  time is at or below `threshold` (a ruleset's display threshold, 0 for none)
--   seconds        the time my box shows, or nil when the deadline gives my box no time: it has
--                  none (a personal-clock ruleset), or the display threshold holds the server's time back
--   paused         the server holds the time: `seconds` is frozen, nothing counts down
-- A player who neither started it nor is timed is not involved: nothing runs for them.
function TimerView.read(deadline, my_id, elapsed, threshold)
	if not deadline or my_id == nil then return not_involved() end
	local started_by_me = deadline.by == my_id
	local timed_me = contains(deadline.against, my_id)
	if not (started_by_me or timed_me) then return not_involved() end
	local seconds = TimerView.remaining(deadline, elapsed)
	local limit = threshold or 0
	local held_back = false
	if timed_me and seconds and limit > 0 then
		held_back = seconds > limit
		-- Held back, the box shows the player's own bank: the server's time is not theirs to show yet.
		if held_back then seconds = nil end
	end
	return {
		running = not held_back,
		timed_me = timed_me,
		started_by_me = started_by_me,
		seconds = seconds,
		paused = TimerView.paused(deadline),
	}
end

-- Whether the server says `my_id` may start the PvP timer now (players[id].canTime of the "pvp.round"
-- state of run `run_id`): its own wouldTime, so no score or first-player rule is repeated here. Absent or
-- another run is false.
function TimerView.can_time(round_value, run_id, my_id)
	if type(round_value) ~= "table" or round_value.runId == nil or run_id == nil or my_id == nil then return false end
	if tostring(round_value.runId) ~= tostring(run_id) or type(round_value.players) ~= "table" then return false end
	local entry = round_value.players[my_id]
	return type(entry) == "table" and entry.canTime == true
end

-- My PvP allowance in seconds from the "pvp.round" value (players[me].pvpLeftMs), nil while the server has
-- not given it (null, absent, another run, not a number).
function TimerView.pvp_left_seconds(round_value, run_id, my_id)
	if type(round_value) ~= "table" or round_value.runId == nil or run_id == nil or my_id == nil then return nil end
	if tostring(round_value.runId) ~= tostring(run_id) or type(round_value.players) ~= "table" then return nil end
	local entry = round_value.players[my_id]
	if type(entry) ~= "table" or type(entry.pvpLeftMs) ~= "number" then return nil end
	return entry.pvpLeftMs / 1000
end

-- What the timer box draws, from what the server says. Every input is a value the server gave; a time
-- the server has not given is nil and draws "--", never a number made up.
--   clocks            PVP.clocks_rules(): the run's clock rules, nil while unknown
--   in_pvp            the PvP blind is on
--   personal          PVP.ClocksNet.read(me): { known = false } or { known = true, ms, ... }
--   deadline_seconds  the time a deadline gives my box (TimerView.read's `seconds`), nil for none
--   bank_seconds      my Ante bank from "pvp.skips", nil while unknown
--   pvp_left_seconds  my PvP allowance from pvp.round.players[me].pvpLeftMs, nil while unknown
-- Returns { kind = "unknown" } (draw "--"), { kind = "speedlatro" } (the Speedlatro box shows
-- the arrows: its clock is drawn by its own element) or { kind = "seconds", seconds, running }, where
-- `running` is whether the box counts (the display threshold holds a bank back while it does not).
function TimerView.box(clocks, in_pvp, personal, deadline_seconds, bank_seconds, pvp_left_seconds)
	local unknown = { kind = "unknown" }
	if clocks == nil then return unknown end
	if in_pvp and clocks.pvp ~= nil then
		-- The running deadline wins; else the server's own PvP allowance (pvpLeftMs), standing; else unknown.
		-- The client never computes it.
		if deadline_seconds ~= nil then return { kind = "seconds", seconds = deadline_seconds, running = true } end
		if type(pvp_left_seconds) == "number" then
			return { kind = "seconds", seconds = pvp_left_seconds, running = false, pvp_allowance = true }
		end
		return unknown
	end
	if clocks.ante == "personal" then
		if clocks.personal ~= nil and clocks.personal.kind == "speedlatro" then return { kind = "speedlatro" } end
		if personal == nil or not personal.known then return unknown end
		return { kind = "seconds", seconds = personal.ms / 1000, running = personal.running }
	end
	if deadline_seconds ~= nil then return { kind = "seconds", seconds = deadline_seconds, running = true } end
	if bank_seconds ~= nil then return { kind = "seconds", seconds = bank_seconds, running = false } end
	return unknown
end
