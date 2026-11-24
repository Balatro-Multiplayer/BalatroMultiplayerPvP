-- Run from the repo root: luajit tests/unit/timer_test.lua
-- The timer: the reader's countdown and button, the screen's text, the forced game speed and the start sound.
local T = dofile("tests/support/check.lua")
local eq = T.eq

-- pvp_api/read/timer.lua: which countdown is drawn, its seconds at a server time, and the button.
do
	T.fresh()
	PVP = { NET = {}, READ = {}, UI = {} }
	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/read/timer.lua")
	local reader = PVP.READ.timer

	local function view(deadlines, can_start)
		return { me = "a", timers = { deadlines = deadlines, timerButton = can_start } }
	end

	-- Seconds.
	eq(reader.seconds_left({ endsAt = 100000 }, 70000), 30, "running: from server time")
	eq(reader.seconds_left({ endsAt = 100000, pausedAt = 90000 }, 70000), 10, "paused: from the pause time")
	eq(reader.seconds_left({ endsAt = 100000 }, 120000), 0, "ended is zero, never negative")
	eq(reader.seconds_left({ endsAt = 100000 }, nil), nil, "no server time gives nothing")
	eq(reader.seconds_left({}, 1), nil, "no end gives nothing")
	eq(reader.seconds_left(nil, 1), nil, "no deadline gives nothing")

	-- Each kind to seconds.
	for kind, seconds in pairs({ ante = 40, pvp = 40, personal = 40 }) do
		local shown = reader.shown(view({ { kind = kind, by = "b", against = { "a" }, endsAt = 100000 } }), 60000)
		eq(shown.seconds, seconds, kind .. " seconds")
		eq(shown.kind, kind, kind .. " kind")
		eq(shown.clock, "running", kind .. " running")
		eq(shown.against_me, true, kind .. " against me")
		eq(shown.mine, false, kind .. " not mine")
	end
	eq(reader.shown(view({ { kind = "grace", against = { "a" }, endsAt = 5 } }), 1), nil, "grace is not drawn")
	eq(reader.shown(view({ { kind = "personal", against = { "b" }, endsAt = 5 } }), 1), nil, "personal against the other is not drawn")
	eq(reader.shown(view({}), 1), nil, "no deadlines gives nothing")
	eq(reader.shown(nil, 1), nil, "no view gives nothing")
	eq(reader.shown(view({ { kind = "ante", endsAt = 5000 } }), nil), nil, "no server time gives nothing")

	-- Choosing among several.
	local picked = reader.shown(view({
		{ kind = "ante", by = "a", against = { "b" }, endsAt = 90000 },
		{ kind = "pvp", by = "b", against = { "a" }, endsAt = 95000 },
	}), 0)
	eq(picked.kind, "pvp", "pvp before ante")
	picked = reader.shown(view({
		{ kind = "ante", by = "a", against = { "b" }, endsAt = 50000 },
		{ kind = "ante", by = "b", against = { "a" }, endsAt = 90000 },
	}), 0)
	eq(picked.against_me, true, "against me before earlier")
	picked = reader.shown(view({
		{ kind = "ante", by = "b", against = { "a" }, endsAt = 90000 },
		{ kind = "ante", by = "b", against = { "a" }, endsAt = 50000 },
	}), 0)
	eq(picked.seconds, 50, "earlier end first")

	-- Paused and mine.
	local paused = reader.shown(view({ { kind = "ante", by = "a", against = { "b" }, endsAt = 100000, pausedAt = 80000 } }), 0)
	eq(paused.clock, "paused", "paused is not running")
	eq(paused.mine, true, "started by me")
	eq(paused.seconds, 20, "paused seconds")

	-- Button.
	local mine_running = reader.shown(view({ { kind = "ante", by = "a", against = { "b" }, endsAt = 100000 } }), 0)
	eq(reader.button(view({}, "ante"), mine_running, false), "pause", "my running timer pauses")
	eq(reader.button(view({}, "ante"), paused, false), "start", "my paused timer may start again")
	eq(reader.button(view({}, "ante"), nil, false), "start", "start when the server says so")
	eq(reader.button(view({}, "pvp"), nil, false), "start", "the PvP timer starts too")
	eq(reader.button(view({}, "none"), nil, false), nil, "no start when the server does not say so")
	eq(reader.button(view({}, "ante"), nil, true), nil, "nothing while my timer input is unconfirmed")
	eq(reader.button(nil, nil, false), nil, "no view, no button")
	eq(reader.button({ me = "a" }, nil, false), nil, "no timers part, no button")
	eq(reader.button(view({}, { start = true }), nil, false), nil, "a table timerButton is not a yes")
	eq(reader.button(view({}, true), nil, false), nil, "a boolean timerButton is not a yes")

	-- A player is away: the server says presses are blocked; there is no button, and the view is not a start.
	eq(reader.button(view({}, "someone away"), nil, false), nil, "no button while a player is away")
	eq(reader.blocked(view({}, "someone away")), true, "the view says presses are blocked")
	eq(reader.blocked(view({}, "ante")), false, "a start is not blocked")
	eq(reader.blocked(view({}, "none")), false, "none is not blocked")
	eq(reader.blocked({ me = "a" }, nil), false, "no timers part is not blocked")
	eq(reader.blocked(nil), false, "no view is not blocked")
	local mine_while_away = reader.shown(view({ { kind = "ante", by = "a", against = { "b" }, endsAt = 100000 } }, "someone away"), 0)
	eq(reader.button(view({ { kind = "ante", by = "a", against = { "b" }, endsAt = 100000 } }, "someone away"), mine_while_away, false), "pause", "my running timer may still be paused while a player is away")

	-- A Ready player's frozen Ante countdown shows its frozen seconds.
	local frozen = reader.shown(view({ { kind = "ante", by = "b", against = { "a" }, endsAt = 100000, pausedAt = 40000, hold = "paused for ready" } }), 90000)
	eq(frozen.seconds, 60, "frozen at the time they had")
	eq(frozen.clock, "paused", "frozen is a paused clock")

	-- Base time with no countdown, from the run's rules.
	local function with_rules(rules) return { match = { run = { rules = rules } } } end
	local rules = {
		clocks = { ante = "bank", pvp = { baseMilliseconds = 90000, handMilliseconds = 1000 }, personal = nil },
		timerBaseMilliseconds = 150000,
	}
	eq(reader.base_seconds(with_rules(rules), true), 90, "pvp blind shows the pvp base")
	eq(reader.base_seconds(with_rules(rules), false), 150, "outside pvp shows the ante bank base")
	rules.clocks.pvp = nil
	eq(reader.base_seconds(with_rules(rules), true), 150, "pvp blind without a pvp clock falls to the ante clock")
	rules.clocks.ante, rules.clocks.personal = "personal", { kind = "pressure", baseMilliseconds = 60000 }
	eq(reader.base_seconds(with_rules(rules), false), 60, "personal clock base")
	rules.clocks.ante = "none"
	eq(reader.base_seconds(with_rules(rules), false), nil, "no clock, no base")
	eq(reader.base_seconds(nil, false), nil, "no view, no base")
	eq(reader.base_seconds(with_rules({}), false), nil, "no clocks, no base")

	-- My PvP time bank, in whole seconds, only inside a PvP blind.
	local function with_banks(banks) return { me = "a", timers = { deadlines = {}, pvpBanks = banks } } end
	eq(reader.bank_seconds(with_banks({ a = 80000, b = 50000 }), true), 80, "my bank in whole seconds")
	eq(reader.bank_seconds(with_banks({ a = 80999 }), true), 80, "a part second is dropped")
	eq(reader.bank_seconds(with_banks({ a = 80000 }), false), nil, "no bank outside a PvP blind")
	eq(reader.bank_seconds(with_banks({ b = 50000 }), true), nil, "no bank of mine, nothing")
	eq(reader.bank_seconds(with_banks(nil), true), nil, "no pvpBanks, nothing")
	eq(reader.bank_seconds({ me = "a" }, true), nil, "no timers part, nothing")
	eq(reader.bank_seconds(nil, true), nil, "no view, nothing")

	-- My Ante bank, in whole seconds, outside a PvP blind.
	local function with_ante_banks(banks) return { me = "a", timers = { deadlines = {}, anteBanks = banks } } end
	eq(reader.bank_seconds(with_ante_banks({ a = 95500, b = 1000 }), false), 95, "my Ante bank in whole seconds")
	eq(reader.bank_seconds(with_ante_banks({ a = 95500 }), true), nil, "the Ante bank is not shown inside a PvP blind")
	eq(reader.bank_seconds(with_ante_banks({ b = 1000 }), false), nil, "no Ante bank of mine, nothing")
	eq(reader.bank_seconds(with_ante_banks(nil), false), nil, "no anteBanks, nothing")

	-- A rate: the shown seconds count down at that many times real time.
	local fast = { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 2 }
	eq(reader.shown(view({ fast }), 60000).seconds, 80, "rate 2: 40 s of real time shows 80")
	eq(reader.shown(view({ fast }), 70000).seconds, 60, "rate 2: 10 s later it shows 20 less")
	eq(reader.shown(view({ fast }), 60000).rate, 2, "the rate is carried")
	fast = { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 1 }
	eq(reader.shown(view({ fast }), 60000).seconds, 40, "rate 1: real time")
	eq(reader.shown(view({ { kind = "personal", against = { "a" }, endsAt = 100000 } }), 60000).rate, 1, "no rate is rate 1")
	eq(reader.shown(view({ { kind = "personal", against = { "a" }, endsAt = 100000, rate = 2, pausedAt = 90000 } }), 0).seconds, 20, "paused at rate 2 holds the shown seconds")

	-- My personal countdown, wherever it ranks among the others.
	local with_ante = view({
		{ kind = "ante", by = "b", against = { "a" }, endsAt = 70000 },
		{ kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 2 },
		{ kind = "personal", by = "b", against = { "b" }, endsAt = 90000 },
	})
	local own = reader.personal(with_ante, 60000)
	eq(own.seconds, 80, "my personal seconds at its rate, not the Ante countdown")
	eq(own.rate, 2, "my personal rate")
	eq(own.clock, "running", "my personal clock runs")
	eq(reader.personal(view({ { kind = "personal", against = { "b" }, endsAt = 5 } }), 1), nil, "the other's personal is not mine")
	eq(reader.personal(view({}), 1), nil, "no personal countdown, nothing")
	eq(reader.personal(nil, 1), nil, "no view, nothing")
	eq(reader.accelerated(own), true, "rate 2 running is accelerated")
	eq(reader.accelerated({ seconds = 5, rate = 1, clock = "running" }), false, "rate 1 is not")
	eq(reader.accelerated({ seconds = 5, rate = 2, clock = "paused" }), false, "paused is not")
	eq(reader.accelerated({ seconds = 0, rate = 2, clock = "running" }), false, "run out is not")
	eq(reader.accelerated(nil), false, "no countdown is not")

	-- Timing: a running Ante or PvP countdown I started (main's timer_started).
	eq(reader.timing(view({ { kind = "ante", by = "a", against = { "b" }, endsAt = 100000 } })), true, "my running Ante countdown")
	eq(reader.timing(view({ { kind = "pvp", by = "a", against = { "b" }, endsAt = 100000 } })), true, "my running PvP countdown")
	eq(reader.timing(view({ { kind = "ante", by = "a", against = { "b" }, endsAt = 100000, pausedAt = 90000 } })), false, "a paused one is not")
	eq(reader.timing(view({ { kind = "ante", by = "b", against = { "a" }, endsAt = 100000 } })), false, "one against me is not")
	eq(reader.timing(view({ { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 1 } })), false, "my personal clock is not")
	eq(reader.timing(nil), false, "no view is not")

	-- Hundredths text for the Speedlatro HUD.
	eq(reader.hundredths_text(73.5), "73.50", "tenths pad to hundredths")
	eq(reader.hundredths_text(147), "147.00", "whole seconds")
	eq(reader.hundredths_text(0), "0.00", "zero")
	eq(reader.hundredths_text(9.126), "9.12", "hundredths floor")

	-- Under a personal Ante clock (Pressure, Speedlatro) the HUD draws my personal clock, never the Ante marker.
	local function personal_view(deadlines, can_start)
		local built = view(deadlines, can_start)
		built.match = { run = { rules = { clocks = { ante = "personal", personal = { baseMilliseconds = 60000 } } } } }
		return built
	end
	local timed = personal_view({
		{ kind = "ante", by = "b", against = { "a" }, endsAt = 70000 },
		{ kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 2 },
	})
	local drawn = reader.shown(timed, 60000)
	eq(drawn.kind, "personal", "personal ante clock: my personal clock is drawn")
	eq(drawn.seconds, 80, "personal ante clock: at its rate")
	eq(reader.shown(personal_view({ { kind = "ante", by = "b", against = { "a" }, endsAt = 70000 } }), 60000), nil,
		"personal ante clock: an Ante marker alone is not drawn")
	eq(reader.shown(personal_view({
		{ kind = "ante", by = "b", against = { "a" }, endsAt = 70000 },
		{ kind = "pvp", by = "b", against = { "a" }, endsAt = 90000 },
	}), 60000).kind, "pvp", "personal ante clock: the PvP countdown still ranks first")
	eq(reader.shown(view({ { kind = "ante", by = "b", against = { "a" }, endsAt = 70000 } }), 60000).kind, "ante",
		"bank ante clock: the Ante countdown is drawn as before")

	-- The starter can still pause while the personal clock is drawn.
	local starter = personal_view({
		{ kind = "ante", by = "a", against = { "b" }, endsAt = 70000 },
		{ kind = "personal", by = "a", against = { "a" }, endsAt = 100000 },
	})
	eq(reader.button(starter, reader.shown(starter, 60000), false), "pause", "my running Ante timer pauses though personal is drawn")
	local only_personal = personal_view({ { kind = "personal", by = "a", against = { "a" }, endsAt = 100000 } }, "ante")
	eq(reader.button(only_personal, reader.shown(only_personal, 60000), false), "start", "my personal clock alone does not pause")
	local paused_starter = personal_view({ { kind = "ante", by = "a", against = { "b" }, endsAt = 70000, pausedAt = 65000 } }, "ante")
	eq(reader.button(paused_starter, nil, false), "start", "my paused Ante timer may start again")

	-- Timed: a running Ante or PvP countdown that I started or that targets me (Score Preview is free then).
	eq(reader.timed(personal_view({ { kind = "ante", by = "b", against = { "a" }, endsAt = 70000 } })), true, "an opponent's Ante marker times me")
	eq(reader.timed(personal_view({ { kind = "ante", by = "a", against = { "b" }, endsAt = 70000 } })), true, "my own running Ante timer times me")
	eq(reader.timed(view({ { kind = "pvp", by = "b", against = { "a" }, endsAt = 70000 } })), true, "a PvP countdown on me times me")
	eq(reader.timed(personal_view({ { kind = "personal", by = "a", against = { "a" }, endsAt = 70000 } })), false, "my personal clock alone is not timed")
	eq(reader.timed(view({ { kind = "ante", by = "b", against = { "a" }, endsAt = 70000, pausedAt = 65000 } })), false, "a paused countdown is not running")
	eq(reader.timed(view({ { kind = "ante", by = "b", against = { "c" }, endsAt = 70000 } })), false, "a countdown between others is not mine")
	eq(reader.timed(view({})), false, "no deadlines, not timed")
	eq(reader.timed(nil), false, "no view, not timed")

	-- Start kind and animating.
	eq(reader.start_kind(true, true), "pvp", "pvp blind with the pvp timer")
	eq(reader.start_kind(true, false), "ante", "pvp blind without the pvp timer")
	eq(reader.start_kind(false, true), "ante", "not a pvp blind")
	eq(reader.animating(true, 0, false), true, "locked controller")
	eq(reader.animating(false, 1, false), true, "stop use")
	eq(reader.animating(false, 0, false), false, "idle")
	eq(reader.animating(true, 1, true), false, "menu or pause holds nothing")
end

-- pvp_api/ui/timer.lua text(): the counting time, else my PvP time bank, else the base time.
do
	T.fresh()
	local in_pvp_blind = true
	local current_view
	PVP = {
		READ = {}, UI = { timer = {} },
		NET = {
			server_now = function() return 60000 end,
			waiting = function() return false end,
			send = function() end,
		},
		is_layer_active = function() return false end,
		UTILS = {
			is_pvp_blind = function() return in_pvp_blind end,
			timer_display_text = function(seconds, running) return string.format("%s%s", seconds, running and "!" or "") end,
		},
	}
	function localize(key) return key end
	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/read/timer.lua")
	dofile("pvp_api/ui/timer.lua")

	local function set_view(deadlines, banks)
		current_view = {
			me = "a",
			timers = { deadlines = deadlines, pvpBanks = banks },
			match = { run = { rules = { clocks = { ante = "bank", pvp = { baseMilliseconds = 60000 } }, timerBaseMilliseconds = 150000 } } },
		}
		PVP.NET.view = current_view
	end

	set_view({}, { a = 80000, b = 50000 })
	eq(PVP.UI.timer.text(), "80", "pvp blind, no countdown on me: my bank")

	set_view({ { kind = "pvp", by = "b", against = { "a" }, endsAt = 100000 } }, { a = 80000 })
	eq(PVP.UI.timer.text(), "40!", "a countdown on me: the counting time")

	set_view({}, nil)
	eq(PVP.UI.timer.text(), "60", "no pvpBanks: the base time as before")

	in_pvp_blind = false
	set_view({}, { a = 80000 })
	eq(PVP.UI.timer.text(), "150", "outside a pvp blind: unchanged")

	-- Ante bank: outside a PvP blind with no countdown on me.
	local function set_ante_view(deadlines, ante_banks)
		set_view(deadlines, nil)
		current_view.timers.anteBanks = ante_banks
	end
	set_ante_view({}, { a = 95500, b = 1000 })
	eq(PVP.UI.timer.text(), "95", "outside a pvp blind, no countdown: my Ante bank")
	set_ante_view({}, nil)
	eq(PVP.UI.timer.text(), "150", "no anteBanks: the base time as before")
	set_ante_view({ { kind = "ante", by = "b", against = { "a" }, endsAt = 100000 } }, { a = 95500 })
	eq(PVP.UI.timer.text(), "40!", "an Ante countdown on me: the counting time")

	-- Pressure: my personal countdown at its rate.
	set_ante_view({ { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 2 } }, { a = 95500 })
	eq(PVP.UI.timer.text(), "80!", "personal at rate 2 shows twice the real time left")
	eq(PVP.UI.timer.rate(), 2, "the shown rate")
	set_ante_view({}, nil)
	eq(PVP.UI.timer.rate(), 1, "no countdown shown is rate 1")
	set_ante_view({ { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 2 } }, nil)
	eq(PVP.UI.timer.personal().seconds, 80, "personal() reads the view")
	eq(PVP.UI.timer.timed(), false, "my personal clock alone does not pulse the box (main: red, no pulse)")
	set_ante_view({ { kind = "personal", against = { "a" }, endsAt = 100000, rate = 2 } }, nil)
	eq(PVP.UI.timer.clock(), "none", "clock() is unchanged for it (Score Preview spends)")
	set_ante_view({ { kind = "ante", by = "b", against = { "a" }, endsAt = 100000 } }, nil)
	eq(PVP.UI.timer.timed(), true, "an Ante countdown against me pulses the box")
	eq(PVP.UI.timer.timing(), false, "and is not mine")
	eq(PVP.UI.timer.clock(), "against me", "Ante clock against me unchanged")
	set_ante_view({ { kind = "ante", by = "a", against = { "b" }, endsAt = 100000 } }, nil)
	eq(PVP.UI.timer.timing(), true, "my Ante countdown on an opponent: I am timing")
	set_ante_view({}, nil)
	eq(PVP.UI.timer.timed(), false, "nothing shown, no pulse")

	-- Under a personal Ante clock the personal clock is drawn and counts as no one's timer.
	local function set_personal_view(deadlines)
		set_ante_view(deadlines, nil)
		current_view.match.run.rules.clocks = { ante = "personal", personal = { baseMilliseconds = 60000 } }
	end
	set_personal_view({
		{ kind = "ante", by = "b", against = { "a" }, endsAt = 70000 },
		{ kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 2 },
	})
	eq(PVP.UI.timer.text(), "80!", "personal ante clock: text is my personal clock at 2x")
	eq(PVP.UI.timer.rate(), 2, "personal ante clock: the gradient gets the personal rate")
	eq(PVP.UI.timer.clock(), "none", "personal ante clock: not my own or an opponent's timer")
	eq(PVP.UI.timer.timing(), false, "personal ante clock: timed by b, not timing")

	-- Timed: Score Preview's gate. An opponent's Ante marker still times me under a personal Ante clock.
	eq(PVP.UI.timer.timed(), true, "personal ante clock with an Ante marker on me: timed")
	set_personal_view({ { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 1 } })
	eq(PVP.UI.timer.timed(), false, "my personal clock alone: not timed")
	set_personal_view({})
	eq(PVP.UI.timer.timed(), false, "no deadlines: not timed")

	-- The Preview gate uses timed(), not clock().
	local file = assert(io.open("compatibility/Preview/InitPreview.lua", "r"))
	local preview = file:read("*a")
	file:close()
	T.checks = T.checks + 1
	assert(preview:find("not PVP.UI.timer.timed()", 1, true), "the Preview gate does not use timer_screen.timed()")
	T.checks = T.checks + 1
	assert(not preview:find("timer_screen.clock()", 1, true), "the Preview gate still reads clock()")
end

-- Main's forced game speed while a timer that pauses for animations runs on me
-- (timer_reader.forces_speed, set every frame by timer_screen.update).
do
	T.fresh()
	local source = os.getenv("TIMER_SRC") or "pvp_api"
	local layers_on = {}
	local in_pvp_blind = false
	PVP = {
		READ = {}, UI = { timer = {} },
		NET = {
			server_now = function() return 60000 end,
			waiting = function() return false end,
			send = function() return true end,
		},
		UTILS = { is_pvp_blind = function() return in_pvp_blind end },
		RULES = { is_layer_active = function(key) return layers_on[key] == true end },
		GAME = { ready_blind = false },
	}
	G = {
		CONTROLLER = { locked = false, locks = {} },
		SETTINGS = {},
		GAME = { STOP_USE = 0, current_round = { hands_left = 3 } },
		STATES = { NEW_ROUND = 1, ROUND_EVAL = 2, SELECTING_HAND = 3 },
		STATE = 3,
	}
	dofile(source .. "/read/timer.lua")
	dofile(source .. "/ui/timer.lua")
	local reader = PVP.READ.timer

	local function view(deadlines, pauses)
		return { me = "a", timers = { deadlines = deadlines, pauses = pauses or {} } }
	end
	local function game(overrides)
		local state = { in_pvp_blind = false, ready_blind = false, hands_left = 3, blind_over = false }
		for key, value in pairs(overrides or {}) do state[key] = value end
		return state
	end
	local function forces(v, layers, state)
		return reader.forces_speed and reader.forces_speed(v, layers, state)
	end

	local opponent_pvp = { kind = "pvp", by = "b", against = { "a" }, endsAt = 100000, hold = "counting" }
	local opponent_ante = { kind = "ante", by = "b", against = { "a" }, endsAt = 100000, hold = "counting" }
	local my_personal = { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 1, hold = "counting" }
	local held = { { reason = "animating", players = { "a" }, endsAt = 90000 } }

	-- pvp_timer: the opponent timered me in the PvP blind.
	local pvp_layers = { pvp_timer = true }
	eq(forces(view({ opponent_pvp }), pvp_layers, game({ in_pvp_blind = true })), true, "pvp_timer: timered in the PvP blind")
	local held_pvp = { kind = "pvp", by = "b", against = { "a" }, endsAt = 100000, pausedAt = 80000, hold = "held for player" }
	local stopped_pvp = { kind = "pvp", by = "b", against = { "a" }, endsAt = 100000, pausedAt = 80000, hold = "paused by starter" }
	eq(forces(view({ held_pvp }, held), pvp_layers, game({ in_pvp_blind = true })), true, "pvp_timer: held while I animate")
	eq(forces(view({ stopped_pvp }), pvp_layers, game({ in_pvp_blind = true })), false, "pvp_timer: paused by the opponent")
	eq(forces(view({ stopped_pvp }, held), pvp_layers, game({ in_pvp_blind = true })), false, "pvp_timer: paused by the opponent while I animate")
	eq(forces(view({ opponent_pvp }), pvp_layers, game({ in_pvp_blind = true, hands_left = 0 })), false, "pvp_timer: no hands left")
	eq(forces(view({ opponent_pvp }), pvp_layers, game({ in_pvp_blind = true, blind_over = true })), false, "pvp_timer: blind scoring out")
	eq(forces(view({ opponent_pvp }), pvp_layers, game({ in_pvp_blind = false })), false, "pvp_timer: not the PvP blind")
	eq(forces(view({}), pvp_layers, game({ in_pvp_blind = true })), false, "pvp_timer: nobody timered me")
	local mine_pvp = { kind = "pvp", by = "a", against = { "b" }, endsAt = 100000, hold = "counting" }
	eq(forces(view({ mine_pvp }), pvp_layers, game({ in_pvp_blind = true })), false, "pvp_timer: I timered them")

	-- pressure_timer: my personal clock, outside the PvP blind.
	local pressure_layers = { pressure_timer = true }
	eq(forces(view({ my_personal }), pressure_layers, game()), true, "pressure_timer: my clock runs")
	eq(forces(view({ opponent_ante }), pressure_layers, game()), true, "pressure_timer: timered")
	eq(forces(view({ my_personal }), pressure_layers, game({ ready_blind = true })), false, "pressure_timer: ready")
	eq(forces(view({ my_personal }), pressure_layers, game({ in_pvp_blind = true })), false, "pressure_timer: PvP blind")
	local paused_personal = { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, pausedAt = 70000, rate = 1, hold = "paused for pvp blind" }
	local ready_personal = { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, pausedAt = 70000, rate = 1, hold = "paused until timed" }
	local held_personal = { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, pausedAt = 70000, rate = 1, hold = "held for player" }
	eq(forces(view({ paused_personal }), pressure_layers, game()), false, "pressure_timer: clock stopped (after the PvP blind)")
	eq(forces(view({ held_personal }, held), pressure_layers, game()), true, "pressure_timer: clock held while I animate")
	eq(forces(view({ paused_personal }, held), pressure_layers, game()), false, "pressure_timer: stopped for the PvP blind while I animate")
	eq(forces(view({ ready_personal }, held), pressure_layers, game()), false, "pressure_timer: paused until timed while I animate")
	eq(forces(view({ paused_personal, opponent_ante }), pressure_layers, game()), true, "pressure_timer: stopped but timered")

	-- no_animation_timer: only when the opponent timered me.
	local no_animation_layers = { no_animation_timer = true }
	eq(forces(view({ opponent_ante }), no_animation_layers, game()), true, "no_animation_timer: timered")
	eq(forces(view({}), no_animation_layers, game()), false, "no_animation_timer: not timered")
	eq(forces(view({ opponent_ante }), no_animation_layers, game({ ready_blind = true })), false, "no_animation_timer: ready")
	eq(forces(view({ opponent_ante }), no_animation_layers, game({ in_pvp_blind = true })), false, "no_animation_timer: PvP blind")
	local mine_ante = { kind = "ante", by = "a", against = { "b" }, endsAt = 100000, hold = "counting" }
	eq(forces(view({ mine_ante }), no_animation_layers, game()), false, "no_animation_timer: I timered them")

	-- Never under Speedlatro; never without a timer layer; never without a view.
	eq(forces(view({ my_personal, opponent_ante }), { speedlatro_timer = true, pressure_timer = true }, game()), false, "speedlatro off")
	eq(forces(view({ opponent_ante }), {}, game()), false, "old timer: no force")
	eq(forces(nil, pressure_layers, game()), false, "no view")

	-- timer_screen.update sets the flag every frame, false with no view.
	PVP.UI.timer.update()
	eq(PVP.UI.timer.FORCE_GAMESPEED, false, "update with no view clears the flag")
	layers_on = { pressure_timer = true }
	PVP.NET.view = view({ my_personal })
	PVP.UI.timer.update()
	eq(PVP.UI.timer.FORCE_GAMESPEED, true, "update sets the flag")
	PVP.NET.view = view({ paused_personal })
	PVP.UI.timer.update()
	eq(PVP.UI.timer.FORCE_GAMESPEED, false, "update clears it when the timer stops")
	PVP.NET.view = view({ my_personal })
	PVP.UI.timer.update()
	PVP.NET.view = nil
	PVP.UI.timer.update()
	eq(PVP.UI.timer.FORCE_GAMESPEED, false, "update clears it when the view goes")
end

-- Main's timer start sound: it plays when an Ante or PvP countdown starts or its starter resumes it,
-- mine or an opponent's, as the Timer SFX setting allows. Never for the server's hold on a countdown ending.
do
	T.fresh()
	PVP = { NET = {}, READ = {}, UI = {} }
	dofile("pvp_api/read/timer.lua")
	local reader = PVP.READ.timer

	local function view(deadlines)
		return { me = "a", timers = { deadlines = deadlines } }
	end
	local function ante(by, hold)
		return { kind = "ante", by = by, against = { "b" }, endsAt = 100000, pausedAt = hold ~= "counting" and 80000 or nil, hold = hold }
	end

	local none = view({})
	eq(reader.timer_started(none, view({ ante("a", "counting") })), true, "my Ante timer starts")
	eq(reader.timer_started(none, view({ ante("b", "counting") })), true, "the opponent's Ante timer reaches me")
	eq(reader.timer_started(none, view({ { kind = "pvp", by = "a", against = { "b" }, endsAt = 1, hold = "counting" } })), true, "a PvP timer starts")
	eq(reader.timer_started(view({ ante("a", "paused by starter") }), view({ ante("a", "counting") })), true, "a resume plays again")
	eq(reader.timer_started(view({ ante("a", "counting") }), view({ ante("a", "counting") })), false, "a running timer plays once")
	eq(reader.timer_started(view({ ante("a", "counting") }), view({ ante("a", "paused by starter") })), false, "a pause is silent")
	eq(reader.timer_started(view({ ante("a", "held for player") }), view({ ante("a", "counting") })), false, "the server's hold ending is silent")
	-- A timer started while I animate reaches me held by the server: still its start (main plays on the start).
	eq(reader.timer_started(none, view({ ante("b", "held for player") })), true, "the opponent's timer reaching me held plays")
	eq(reader.timer_started(none, view({ { kind = "pvp", by = "b", against = { "a" }, endsAt = 1, hold = "held for player" } })), true, "a PvP timer reaching me held plays")
	eq(reader.timer_started(view({ ante("a", "paused by starter") }), view({ ante("a", "held for player") })), true, "a resume while held plays")
	eq(reader.timer_started(view({ ante("a", "held for player") }), view({ ante("a", "held for player") })), false, "a held timer plays once")
	eq(reader.timer_started(none, view({ { kind = "personal", by = nil, against = { "a" }, endsAt = 1, hold = "counting" } })), false, "a personal countdown is not a timer start")
	eq(reader.timer_started(nil, view({ ante("a", "counting") })), false, "the first view after a join is silent")

	-- One timer split in parts (a Ready target's frozen share) reads as one: the most running part.
	local function share(by, against, hold)
		return { kind = "ante", by = by, against = { against }, endsAt = 100000, pausedAt = hold ~= "counting" and 80000 or nil, hold = hold }
	end
	local split = view({ share("a", "c", "counting"), share("a", "b", "paused for ready") })
	eq(reader.timer_started(split, split), false, "a split timer plays once")
	eq(reader.timer_started(view({ share("a", "b", "paused for ready"), share("a", "c", "counting") }), split), false, "the part order does not matter")
	eq(reader.timer_started(view({ share("a", "c", "counting") }), split), false, "a part freezing is silent")
	eq(reader.timer_started(split, view({ share("a", "c", "counting"), share("a", "b", "counting") })), false, "a part thawing is silent")
	eq(reader.timer_started(view({ share("a", "c", "paused by starter"), share("a", "b", "paused for ready") }), split), true, "the starter's restart plays while a part is frozen")
	eq(reader.timer_started(split, view({ share("a", "c", "paused by starter"), share("a", "b", "paused for ready") })), false, "the starter's pause is silent")

	-- Timer SFX: 1 On, 2 Once per Ante, 3 Off.
	eq(reader.start_sound_plays(1, 2, 2), true, "On plays every start")
	eq(reader.start_sound_plays(2, 2, 1), true, "Once per Ante plays the first start of an ante")
	eq(reader.start_sound_plays(2, 2, 2), false, "Once per Ante stays quiet the rest of the ante")
	eq(reader.start_sound_plays(3, 2, 1), false, "Off never plays")
end

T.done("timer_test")
