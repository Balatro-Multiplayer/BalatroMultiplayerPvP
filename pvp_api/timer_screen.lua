-- The timer HUD and its button, on the match net. Pressing sends an input; the countdown drawn and
-- whose clock runs are read from the net's view and server time (timer_reader.lua decides).
-- A run-out is never decided here: the server ends it and the view carries the result.
local screen = {}
PVP.timer_screen = screen

local animating_sent = "off"

local function net()
	return PVP.match_net
end

function screen.shown()
	return PVP.timer_reader.shown(net().view, net().server_now())
end

-- Seconds on the clock shown, nil when none is.
function screen.seconds()
	local shown = net().view and screen.shown()
	return shown and shown.seconds
end

-- The rate of the clock shown: 1 when none is.
function screen.rate()
	local shown = net().view and screen.shown()
	return shown and shown.rate or 1
end

-- My own personal countdown from the view, whatever else is shown, or nil.
function screen.personal()
	if not net().view then return nil end
	return PVP.timer_reader.personal(net().view, net().server_now())
end

-- An Ante or PvP countdown runs with me as its starter or target (Score Preview charges nothing then).
function screen.timed()
	return PVP.timer_reader.timed(net().view)
end

-- An Ante or PvP countdown I started runs.
function screen.timing()
	return PVP.timer_reader.timing(net().view)
end

-- Whose clock runs: "mine" (my own), "against me" (an opponent's, not a personal one) or "none".
function screen.clock()
	local shown = net().view and screen.shown()
	if not (shown and shown.clock == "running") then return "none" end
	if shown.kind == "personal" then return "none" end
	if shown.mine then return "mine" end
	if shown.against_me and shown.kind ~= "personal" then return "against me" end
	return "none"
end

-- "start", "pause" or nil.
function screen.button()
	local waiting = net().waiting("timerStart") or net().waiting("timerPause")
	return PVP.timer_reader.button(net().view, screen.shown(), waiting)
end

-- The hover hint state of the timer box (timer_reader.Tip).
function screen.tip()
	return PVP.timer_reader.tip(
		screen.seconds(),
		screen.clock(),
		screen.timing(),
		screen.button() ~= nil,
		PVP.timer_reader.blocked(net().view)
	)
end

function screen.press()
	local action = screen.button()
	if action == "pause" then return net().send("timerPause", {}) end
	if action == "start" then
		local kind = PVP.timer_reader.start_kind(PVP.is_pvp_boss(), PVP.is_layer_active("pvp_timer"))
		return net().send("timerStart", { timer = kind })
	end
end

-- A paid Score Preview use: the input carries how many this run; the server owns the cost.
function screen.spend()
	local pvp_net = G.GAME and G.GAME.pvp_net
	if not net().view or not (pvp_net and pvp_net.runId) then return end
	local total = PVP.run_totals.next_total(pvp_net, "paidPreviews")
	if total then net().send("paidPreviews", { total = total }) end
end

function screen.text()
	local shown = screen.shown()
	if not shown then
		local in_pvp_blind = PVP.is_pvp_boss()
		local base = PVP.timer_reader.bank_seconds(net().view, in_pvp_blind)
			or PVP.timer_reader.base_seconds(net().view, in_pvp_blind)
		if not base then return localize("k_timer_none") end
		return PVP.UTILS.timer_display_text(base, false)
	end
	return PVP.UTILS.timer_display_text(shown.seconds, true)
end

local function send_animating()
	local locked = G.CONTROLLER.locked and not G.CONTROLLER.locks.frame
	local menu_or_paused = G.SETTINGS.paused or G.OVERLAY_MENU
	local wanted = PVP.timer_reader.animating(locked and true or false, G.GAME and G.GAME.STOP_USE or 0, menu_or_paused)
	local name = wanted and "on" or "off"
	if name ~= animating_sent and net().send("animating", { on = wanted }) then animating_sent = name end
end

-- Main's forced game speed, set fresh every frame (lovely/timer.toml reads it).
local function set_forced_speed()
	local view = net().view
	local game = G.GAME
	local layers = {
		pvp_timer = PVP.is_layer_active("pvp_timer"),
		pressure_timer = PVP.is_layer_active("pressure_timer"),
		speedlatro_timer = PVP.is_layer_active("speedlatro_timer"),
		no_animation_timer = PVP.is_layer_active("no_animation_timer"),
	}
	local state = {
		in_pvp_blind = PVP.is_pvp_boss(),
		ready_blind = PVP.GAME.ready_blind,
		hands_left = game and game.current_round and game.current_round.hands_left or 0,
		blind_over = G.STATE == G.STATES.NEW_ROUND or G.STATE == G.STATES.ROUND_EVAL,
	}
	PVP.TIMER_FORCE_GAMESPEED = PVP.timer_reader.forces_speed(view, layers, state)
end

function screen.update()
	PVP.TIMER_FORCE_GAMESPEED = false
	if not net().view then
		animating_sent = "off"
		return
	end
	set_forced_speed()
	send_animating()
end

-- Main's timer start sound: three rising notes. The ante is recorded at every start, played or not.
local function play_start_sound()
	local ante = G.GAME.round_resets.ante
	local plays = PVP.timer_reader.start_sound_plays(PVP.config.timersfx or 1, ante, G.timer_ante)
	G.timer_ante = ante
	if not plays then return end
	for i = 1, 3 do
		G.E_MANAGER:add_event(Event({
			blocking = false,
			blockable = false,
			trigger = "after",
			delay = G.SETTINGS.GAMESPEED * 0.15 * (i - 1),
			func = function()
				play_sound("timpani", 0.55 + 0.25 * i, 0.7)
				play_sound("generic1", 0.75 + 0.25 * i, 0.7)
				return true
			end,
		}))
	end
end

function screen.install(match_net)
	local before = nil
	match_net.add_view_listener(function(view)
		if G.GAME and PVP.timer_reader.timer_started(before, view) then play_start_sound() end
		before = view
	end)
end

return screen
