-- What the timer HUD and its button show, decided from the server's view and server time. Pure: no
-- game, no net. A countdown is never started, ticked or ended here: the server decides every
-- run-out and the view carries the result. timer_screen.lua is the shell that calls these.
local reader = {}
PVP.timer_reader = reader

-- The countdowns the HUD may draw, most important first. Idle and grace are not drawn here.
local ORDER = { pvp = 1, ante = 2, personal = 3 }

local function holds(list, id)
	for _, entry in ipairs(list or {}) do
		if entry == id then return true end
	end
	return false
end

-- Seconds left: from the pause time when paused, else from server time now. Nothing when a number
-- it needs is missing; never a made-up number.
function reader.seconds_left(deadline, server_now)
	if type(deadline) ~= "table" or type(deadline.endsAt) ~= "number" then return nil end
	local from = type(deadline.pausedAt) == "number" and deadline.pausedAt or server_now
	if type(from) ~= "number" then return nil end
	return math.max(0, (deadline.endsAt - from) / 1000)
end

local function before(view, left, right)
	local left_rank, right_rank = ORDER[left.kind], ORDER[right.kind]
	if left_rank ~= right_rank then return left_rank < right_rank end
	local left_mine, right_mine = holds(left.against, view.me), holds(right.against, view.me)
	if left_mine ~= right_mine then return left_mine end
	return left.endsAt < right.endsAt
end

-- The run's Ante clock is my personal one (Pressure, Speedlatro): the HUD draws it, never the Ante marker.
function reader.ante_is_personal(view)
	local run = PVP.view.run(view)
	local clocks = run and run.rules and run.rules.clocks
	return type(clocks) == "table" and clocks.ante == "personal"
end

-- The one countdown to draw, or nil. mine: I started it; against_me: it runs out on me.
function reader.shown(view, server_now)
	local best
	local ante_is_personal = reader.ante_is_personal(view)
	for _, deadline in ipairs(view and view.timers and view.timers.deadlines or {}) do
		local counts = ORDER[deadline.kind] ~= nil and type(deadline.endsAt) == "number"
			and not (deadline.kind == "ante" and ante_is_personal)
		if counts and (deadline.kind ~= "personal" or holds(deadline.against, view.me)) then
			if not best or before(view, deadline, best) then best = deadline end
		end
	end
	return best and reader.describe(view, best, server_now)
end

-- A countdown as the HUD draws it. The server's rate (1, or 2 while I am being timed) multiplies the
-- shown seconds: real time left times rate, so they count down that many times as fast.
function reader.describe(view, deadline, server_now)
	local left = reader.seconds_left(deadline, server_now)
	if not left then return nil end
	local rate = type(deadline.rate) == "number" and deadline.rate or 1
	return {
		seconds = left * rate,
		rate = rate,
		kind = deadline.kind,
		clock = type(deadline.pausedAt) == "number" and "paused" or "running",
		mine = deadline.by == view.me,
		against_me = holds(deadline.against, view.me),
	}
end

-- My own personal countdown (pressure, Speedlatro, Chaos), whatever else the HUD draws, or nil.
function reader.personal(view, server_now)
	for _, deadline in ipairs(view and view.timers and view.timers.deadlines or {}) do
		if deadline.kind == "personal" and holds(deadline.against, view.me) then
			return reader.describe(view, deadline, server_now)
		end
	end
	return nil
end

-- A running Ante or PvP countdown that I started or that runs out on me.
function reader.timed(view)
	for _, deadline in ipairs(view and view.timers and view.timers.deadlines or {}) do
		local counts = deadline.kind == "ante" or deadline.kind == "pvp"
		local mine = deadline.by == view.me or holds(deadline.against, view.me)
		if counts and mine and type(deadline.pausedAt) ~= "number" then return true end
	end
	return false
end

-- A countdown of this kind runs on me: counting, or held for a player (main forces speed through
-- the animation pause). One its starter paused, or Ready stopped, does not. by_opponent: its starter is not me.
local function ticks_on_me(view, kind, by_opponent)
	for _, deadline in ipairs(view.timers.deadlines or {}) do
		local counting = deadline.hold == "counting" or deadline.hold == "held for player"
		local started_by_opponent = deadline.by ~= view.me
		if deadline.kind == kind and holds(deadline.against, view.me) and counting
			and (not by_opponent or started_by_opponent) then
			return true
		end
	end
	return false
end

-- The game is forced to at least 4x speed while a timer that pauses for animations runs on me (main's
-- TIMER_FORCE_GAMESPEED). layers: which timer layers are on (pvp_timer, pressure_timer, speedlatro_timer,
-- no_animation_timer); game: in_pvp_blind, ready_blind, hands_left, blind_over (the blind
-- is scoring out). Nothing without a view with timers.
function reader.forces_speed(view, layers, game)
	if type(view) ~= "table" or type(view.timers) ~= "table" then return false end
	if layers.speedlatro_timer then return false end
	local timered_by_opponent = ticks_on_me(view, "ante", true)
	if layers.pvp_timer and game.in_pvp_blind then
		return ticks_on_me(view, "pvp", true) and game.hands_left > 0 and not game.blind_over
	elseif layers.pressure_timer then
		if game.ready_blind or game.in_pvp_blind then return false end
		return ticks_on_me(view, "personal", false) or timered_by_opponent
	elseif layers.no_animation_timer then
		return timered_by_opponent and not game.ready_blind and not game.in_pvp_blind
	end
	return false
end

-- The gradient runs fast only while a countdown runs at more than real time.
function reader.accelerated(shown)
	return shown ~= nil and shown.clock == "running" and shown.rate > 1 and shown.seconds > 0
end

-- A running Ante or PvP countdown that I started (main's timer_started).
function reader.timing(view)
	for _, deadline in ipairs(view and view.timers and view.timers.deadlines or {}) do
		local counts = deadline.kind == "ante" or deadline.kind == "pvp"
		if counts and deadline.by == view.me and type(deadline.pausedAt) ~= "number" then return true end
	end
	return false
end

reader.Tip = {
	IDLE = "idle",
	CAN_START = "can_start",
	CAN_PAUSE = "can_pause",
	RUNNING = "running",
	AGAINST_ME = "against_me",
	EXPIRED = "expired",
	BLOCKED = "blocked",
}

-- The server could let me start a timer but a player is away, so no press works now.
function reader.blocked(view)
	return type(view) == "table" and type(view.timers) == "table" and view.timers.timerButton == "someone away"
end

-- Which hint the timer box's hover tooltip shows. The box is also the start/pause button, which colour
-- alone does not tell you. seconds: the clock shown, nil when none; clock: "mine", "against me" or
-- "none"; timing: I started a running countdown; can_act: the button has an action now;
-- blocked: a press is refused while a player is away (reader.blocked).
function reader.tip(seconds, clock, timing, can_act, blocked)
	local tip = reader.Tip
	if seconds ~= nil and seconds <= 0 then return tip.EXPIRED end
	if clock == "against me" then return tip.AGAINST_ME end
	if can_act then return timing and tip.CAN_PAUSE or tip.CAN_START end
	if blocked then return tip.BLOCKED end
	if timing then return tip.RUNNING end
	return tip.IDLE
end

-- Seconds as "73.50": whole seconds, a point, two digits of hundredths (floored).
function reader.hundredths_text(seconds)
	local hundredths = math.floor(seconds * 100 + 1e-9)
	return string.format("%d.%02d", math.floor(hundredths / 100), hundredths % 100)
end

-- What the timer button does now: "start", "pause" (my own running timer) or nil. Never while a
-- timer input of mine is unconfirmed.
function reader.button(view, shown, input_waiting)
	if input_waiting or type(view) ~= "table" or not view.timers then return nil end
	if shown and shown.mine and shown.kind ~= "personal" and shown.clock == "running" then return "pause" end
	for _, deadline in ipairs(view.timers.deadlines or {}) do
		local timed = deadline.kind == "ante" or deadline.kind == "pvp"
		if timed and deadline.by == view.me and type(deadline.pausedAt) ~= "number" then return "pause" end
	end
	local starts = view.timers.timerButton
	if starts == "ante" or starts == "pvp" then return "start" end
	return nil
end

-- The seconds a player starts with, from the run's frozen rules, for the HUD while no countdown
-- runs: the PvP hand timer's base in the PvP blind, else the Ante clock's (bank base or personal
-- base). Nothing when the rules carry no clock for it; never a made-up number.
function reader.base_seconds(view, in_pvp_blind)
	local run = PVP.view.run(view)
	local rules = run and run.rules
	local clocks = rules and rules.clocks
	if type(clocks) ~= "table" then return nil end
	local milliseconds
	if in_pvp_blind and type(clocks.pvp) == "table" then
		milliseconds = clocks.pvp.baseMilliseconds
	elseif clocks.ante == "personal" and type(clocks.personal) == "table" then
		milliseconds = clocks.personal.baseMilliseconds
	elseif clocks.ante == "bank" then
		milliseconds = rules.timerBaseMilliseconds
	end
	if type(milliseconds) ~= "number" then return nil end
	return milliseconds / 1000
end

-- My time bank in whole seconds: the PvP bank inside a PvP blind, else the Ante bank (skip time
-- included). Nothing when the view carries none.
function reader.bank_seconds(view, in_pvp_blind)
	local timers = view and view.timers
	local banks = timers and (in_pvp_blind and timers.pvpBanks or not in_pvp_blind and timers.anteBanks)
	local milliseconds = type(banks) == "table" and banks[view.me]
	if type(milliseconds) ~= "number" then return nil end
	return math.floor(milliseconds / 1000)
end

-- How far a hold is from running: a split Ante countdown (one per Ready target) reads as one timer,
-- as the most running of its parts.
local function hold_rank(hold)
	if hold == "paused for ready" then return 1 end
	if hold == "paused by starter" then return 2 end
	return 3
end

-- Each Ante or PvP timer in `view`, by kind and starter, to its hold.
local function timer_holds(view)
	local holds = {}
	for _, deadline in ipairs(view.timers and view.timers.deadlines or {}) do
		if deadline.kind == "ante" or deadline.kind == "pvp" then
			local key = deadline.kind .. ":" .. tostring(deadline.by)
			if holds[key] == nil or hold_rank(deadline.hold) > hold_rank(holds[key]) then holds[key] = deadline.hold end
		end
	end
	return holds
end

-- An Ante or PvP countdown, mine or an opponent's, is new in `view` or its starter resumed it:
-- main's timer start sound plays. One that reaches me held (I am animating) is still a start; the
-- server's hold ending is not. Nothing for the first view after a join (`before` nil).
function reader.timer_started(before, view)
	if type(before) ~= "table" or type(view) ~= "table" then return false end
	local was = timer_holds(before)
	for key, hold in pairs(timer_holds(view)) do
		if hold ~= "paused by starter" and (was[key] == nil or was[key] == "paused by starter") then return true end
	end
	return false
end

-- Main's Timer SFX setting: 1 On (every start), 2 Once per Ante (the first start of an ante), 3 Off.
function reader.start_sound_plays(option, ante, last_ante)
	return option == 1 or (option == 2 and ante ~= last_ante)
end

function reader.start_kind(in_pvp_blind, pvp_timer_on)
	return (in_pvp_blind and pvp_timer_on) and "pvp" or "ante"
end

-- My game is animating and not in a menu or paused (the server holds my countdowns while I animate).
function reader.animating(controller_locked, stop_use, menu_or_paused)
	return ((controller_locked or stop_use > 0) and not menu_or_paused) and true or false
end

return reader
