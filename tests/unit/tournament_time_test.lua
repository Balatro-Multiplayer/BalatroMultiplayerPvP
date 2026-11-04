-- Run from the repo root: lua5.4 tests/unit/tournament_time_test.lua
-- lib/tournament_time.lua: 12-hour local times and countdowns.
dofile("lib/tournament_time.lua")
local T = PVP.TournamentTime

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(string.format("FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
	end
end

local MIN = 60 * 1000
local HOUR = 60 * MIN
local DAY = 24 * HOUR

-- A fake os.date("*t", seconds) for a fixed timezone (UTC here), so the
-- test doesn't depend on the PC it runs on.
local function utc_date(format, seconds)
	assert(format == "*t")
	return os.date("!*t", seconds)
end

-- Saturday 7 November 2026, 14:30 UTC.
local NOW = 1794061800000

-- 12-hour clock, today / tomorrow / weekday / date.
check("today pm", T.format_local(NOW + 3 * HOUR + 30 * MIN, NOW, utc_date), "Today 6:00 PM")
check("today noon", T.format_local(NOW - 2 * HOUR - 30 * MIN, NOW, utc_date), "Today 12:00 PM")
check("tomorrow am", T.format_local(NOW + DAY - 5 * HOUR, NOW, utc_date), "Tomorrow 9:30 AM")
check("midnight", T.format_local(NOW + DAY - 14 * HOUR - 30 * MIN, NOW, utc_date), "Tomorrow 12:00 AM")
check("weekday", T.format_local(NOW + 3 * DAY, NOW, utc_date), "Tue 2:30 PM")
check("far away", T.format_local(NOW + 9 * DAY, NOW, utc_date), "Nov 16, 2:30 PM")

-- Countdowns: nil a day or more away; h+m under a day; m+s under an hour.
check("a day away", T.countdown(NOW + DAY, NOW), nil)
check("hours", T.countdown(NOW + 5 * HOUR + 12 * MIN + 40 * 1000, NOW), "5h 12m")
check("just under a day", T.countdown(NOW + DAY - 1000, NOW), "23h 59m")
check("minutes", T.countdown(NOW + 12 * MIN + 5 * 1000, NOW), "12m 05s")
check("seconds", T.countdown(NOW + 9 * 1000, NOW), "0m 09s")
check("due", T.countdown(NOW, NOW), "0s")
check("past", T.countdown(NOW - MIN, NOW), "0s")

-- What the list shows: a countdown under a day, else the local date.
check("describe soon", T.describe(NOW + 2 * HOUR, NOW, utc_date), "in 2h 00m")
check("describe later", T.describe(NOW + 2 * DAY, NOW, utc_date), "Mon 2:30 PM")
check("describe now", T.describe(NOW - 1000, NOW, utc_date), "now")

-- The big clock on the tournament screen.
check("clock minutes", T.clock(NOW + 54 * MIN + 10 * 1000, NOW), "54:10")
check("clock hours", T.clock(NOW + HOUR + 5 * MIN + 10 * 1000, NOW), "1:05:10")
check("clock rounds up", T.clock(NOW + 500, NOW), "0:01")
check("clock due", T.clock(NOW - 1, NOW), "0:00")
check("clock a day away", T.clock(NOW + DAY, NOW), nil)

-- The server's clock: answers carry serverNow.
T.local_ms = function()
	return 1000000
end
T.observe_server_now(1000000 + 42000)
check("offset", T.now_ms(), 1042000)
T.observe_server_now(nil)
check("offset kept on a bad value", T.now_ms(), 1042000)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("tournament_time_test: all passed")
