-- Time for in-client tournaments: the server's clock, start times in the
-- player's own timezone (12-hour clock), and countdowns. Pure (no game
-- state), so tests/unit/tournament_time_test.lua runs it under plain Lua.
--
-- Every tournament RPC answer carries serverNow (epoch ms); remembering how
-- far the local clock is off keeps countdowns right on a PC whose clock is
-- wrong. os.date without "!" formats in the PC's timezone, which is the
-- player's.

PVP = PVP or {}
local T = {}
PVP.TournamentTime = T

local MINUTE = 60 * 1000
local HOUR = 60 * MINUTE
local DAY = 24 * HOUR

-- Day and month names are looked up when drawn (localization/tournaments).
local DAYS = { "sun", "mon", "tue", "wed", "thu", "fri", "sat" }
local MONTHS = { "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec" }

local function day_name(wday)
	return PVP.T("k_tn_day_" .. DAYS[wday])
end

local function month_name(month)
	return PVP.T("k_tn_month_" .. MONTHS[month])
end

-- Server time minus local time, in ms.
T.offset_ms = 0

-- The local clock in epoch ms (os.time() is whole seconds; enough here).
function T.local_ms()
	return os.time() * 1000
end

-- Called with every answer's serverNow.
function T.observe_server_now(server_ms)
	if type(server_ms) == "number" then
		T.offset_ms = server_ms - T.local_ms()
	end
end

-- Now, on the server's clock.
function T.now_ms()
	return T.local_ms() + T.offset_ms
end

-- "6:00 PM" from an os.date("*t") table.
local function clock_text(t)
	local hour = t.hour % 12
	if hour == 0 then
		hour = 12
	end
	return PVP.T(t.hour < 12 and "k_tn_clock_am" or "k_tn_clock_pm", hour, string.format("%02d", t.min))
end

-- epoch ms -> the player's local time: "Today 6:00 PM", "Tomorrow 9:30 AM",
-- "Sat 6:00 PM" (within a week), "Nov 15, 6:00 PM" (later). date_fn is
-- os.date (tests pass their own).
function T.format_local(epoch_ms, now_ms, date_fn)
	date_fn = date_fn or os.date
	now_ms = now_ms or T.now_ms()
	local at = date_fn("*t", math.floor(epoch_ms / 1000))
	local today = date_fn("*t", math.floor(now_ms / 1000))
	local time = clock_text(at)
	local function day_number(t)
		return os.time({ year = t.year, month = t.month, day = t.day, hour = 12 }) / 86400
	end
	local days_away = math.floor(day_number(at) - day_number(today) + 0.5)
	if days_away == 0 then
		return PVP.T("k_tn_today_at", time)
	elseif days_away == 1 then
		return PVP.T("k_tn_tomorrow_at", time)
	elseif days_away > 1 and days_away < 7 then
		return PVP.T("k_tn_weekday_at", day_name(at.wday), time)
	end
	return PVP.T("k_tn_date_at", month_name(at.month), at.day, time)
end

-- The time left until epoch ms, for a countdown: nil a day or more away
-- (show the date instead); hours and minutes under a day ("5h 12m"); minutes
-- and seconds under an hour ("12m 05s"); "0s" when due.
function T.countdown(epoch_ms, now_ms)
	now_ms = now_ms or T.now_ms()
	local left = epoch_ms - now_ms
	if left >= DAY then
		return nil
	end
	if left <= 0 then
		return PVP.T("k_tn_countdown_s", 0)
	end
	local seconds = math.floor(left / 1000)
	if left >= HOUR then
		return PVP.T("k_tn_countdown_hm", math.floor(seconds / 3600), string.format("%02d", math.floor(seconds % 3600 / 60)))
	end
	return PVP.T("k_tn_countdown_ms", math.floor(seconds / 60), string.format("%02d", seconds % 60))
end

-- A big clock for the tournament screen: "54:10" under an hour, "1:05:10"
-- under a day, nil a day or more away, "0:00" when due.
function T.clock(epoch_ms, now_ms)
	now_ms = now_ms or T.now_ms()
	local left = epoch_ms - now_ms
	if left >= DAY then
		return nil
	end
	if left <= 0 then
		return "0:00"
	end
	local seconds = math.ceil(left / 1000)
	local h, m, sec = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

-- When something happens, the way the tournament list shows it: the local
-- date a day or more away, else a countdown ("in 5h 12m").
function T.describe(epoch_ms, now_ms, date_fn)
	now_ms = now_ms or T.now_ms()
	local left = T.countdown(epoch_ms, now_ms)
	if left == nil then
		return T.format_local(epoch_ms, now_ms, date_fn)
	end
	if epoch_ms <= now_ms then
		return PVP.T("k_tn_now")
	end
	return PVP.T("k_tn_in", left)
end

return T
