-- Run from the repo root: luajit tests/unit/timer_screen_test.lua
-- pvp_api/timer_screen.lua text(): the counting time, else my PvP time bank, else the base time.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local in_pvp_blind = true
local current_view
PVP = {
	match_net = {
		server_now = function() return 60000 end,
		waiting = function() return false end,
		send = function() end,
	},
	is_pvp_boss = function() return in_pvp_blind end,
	is_layer_active = function() return false end,
	UTILS = {
		timer_display_text = function(seconds, running) return string.format("%s%s", seconds, running and "!" or "") end,
	},
}
function localize(key) return key end
dofile("pvp_api/_view.lua")
dofile("pvp_api/timer_reader.lua")
dofile("pvp_api/timer_screen.lua")

local function set_view(deadlines, banks)
	current_view = {
		me = "a",
		timers = { deadlines = deadlines, pvpBanks = banks },
		match = { run = { rules = { clocks = { ante = "bank", pvp = { baseMilliseconds = 60000 } }, timerBaseMilliseconds = 150000 } } },
	}
	PVP.match_net.view = current_view
end

set_view({}, { a = 80000, b = 50000 })
eq(PVP.timer_screen.text(), "80", "pvp blind, no countdown on me: my bank")

set_view({ { kind = "pvp", by = "b", against = { "a" }, endsAt = 100000 } }, { a = 80000 })
eq(PVP.timer_screen.text(), "40!", "a countdown on me: the counting time")

set_view({}, nil)
eq(PVP.timer_screen.text(), "60", "no pvpBanks: the base time as before")

in_pvp_blind = false
set_view({}, { a = 80000 })
eq(PVP.timer_screen.text(), "150", "outside a pvp blind: unchanged")

-- Ante bank: outside a PvP blind with no countdown on me.
local function set_ante_view(deadlines, ante_banks)
	set_view(deadlines, nil)
	current_view.timers.anteBanks = ante_banks
end
set_ante_view({}, { a = 95500, b = 1000 })
eq(PVP.timer_screen.text(), "95", "outside a pvp blind, no countdown: my Ante bank")
set_ante_view({}, nil)
eq(PVP.timer_screen.text(), "150", "no anteBanks: the base time as before")
set_ante_view({ { kind = "ante", by = "b", against = { "a" }, endsAt = 100000 } }, { a = 95500 })
eq(PVP.timer_screen.text(), "40!", "an Ante countdown on me: the counting time")

-- Pressure: my personal countdown at its rate.
set_ante_view({ { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 2 } }, { a = 95500 })
eq(PVP.timer_screen.text(), "80!", "personal at rate 2 shows twice the real time left")
eq(PVP.timer_screen.rate(), 2, "the shown rate")
set_ante_view({}, nil)
eq(PVP.timer_screen.rate(), 1, "no countdown shown is rate 1")
set_ante_view({ { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 2 } }, nil)
eq(PVP.timer_screen.personal().seconds, 80, "personal() reads the view")
eq(PVP.timer_screen.timed(), false, "my personal clock alone does not pulse the box (main: red, no pulse)")
set_ante_view({ { kind = "personal", against = { "a" }, endsAt = 100000, rate = 2 } }, nil)
eq(PVP.timer_screen.clock(), "none", "clock() is unchanged for it (Score Preview spends)")
set_ante_view({ { kind = "ante", by = "b", against = { "a" }, endsAt = 100000 } }, nil)
eq(PVP.timer_screen.timed(), true, "an Ante countdown against me pulses the box")
eq(PVP.timer_screen.timing(), false, "and is not mine")
eq(PVP.timer_screen.clock(), "against me", "Ante clock against me unchanged")
set_ante_view({ { kind = "ante", by = "a", against = { "b" }, endsAt = 100000 } }, nil)
eq(PVP.timer_screen.timing(), true, "my Ante countdown on an opponent: I am timing")
set_ante_view({}, nil)
eq(PVP.timer_screen.timed(), false, "nothing shown, no pulse")

-- Under a personal Ante clock the personal clock is drawn and counts as no one's timer.
local function set_personal_view(deadlines)
	set_ante_view(deadlines, nil)
	current_view.match.run.rules.clocks = { ante = "personal", personal = { baseMilliseconds = 60000 } }
end
set_personal_view({
	{ kind = "ante", by = "b", against = { "a" }, endsAt = 70000 },
	{ kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 2 },
})
eq(PVP.timer_screen.text(), "80!", "personal ante clock: text is my personal clock at 2x")
eq(PVP.timer_screen.rate(), 2, "personal ante clock: the gradient gets the personal rate")
eq(PVP.timer_screen.clock(), "none", "personal ante clock: not my own or an opponent's timer")
eq(PVP.timer_screen.timing(), false, "personal ante clock: timed by b, not timing")

-- Timed: Score Preview's gate. An opponent's Ante marker still times me under a personal Ante clock.
eq(PVP.timer_screen.timed(), true, "personal ante clock with an Ante marker on me: timed")
set_personal_view({ { kind = "personal", by = "a", against = { "a" }, endsAt = 100000, rate = 1 } })
eq(PVP.timer_screen.timed(), false, "my personal clock alone: not timed")
set_personal_view({})
eq(PVP.timer_screen.timed(), false, "no deadlines: not timed")

-- The Preview gate uses timed(), not clock().
local file = assert(io.open("compatibility/Preview/InitPreview.lua", "r"))
local preview = file:read("*a")
file:close()
checks = checks + 1
assert(preview:find("not PVP.timer_screen.timed()", 1, true), "the Preview gate does not use timer_screen.timed()")
checks = checks + 1
assert(not preview:find("timer_screen.clock()", 1, true), "the Preview gate still reads clock()")

print("timer_screen_test: ok (" .. checks .. " checks)")
