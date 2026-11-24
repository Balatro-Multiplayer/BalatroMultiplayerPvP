-- Run from the repo root: luajit tests/unit/timer_reader_test.lua
-- pvp_api/timer_reader.lua: which countdown is drawn, its seconds at a server time, and the button.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

PVP = {}
dofile("pvp_api/_view.lua")
dofile("pvp_api/timer_reader.lua")
local reader = PVP.timer_reader

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

print("timer_reader_test: ok (" .. checks .. " checks)")
