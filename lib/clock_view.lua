-- Pure view of the server's "pvp.clocks" match state: the personal clocks (Pressure, Speedlatro)
-- the server counts for each player. The wire value is { [playerId] = { ms, running, rate, n, spent } }
-- and the key is absent on rulesets without a personal clock. No game state, requests or engine
-- clock here: pvp_api/clocks_net.lua feeds this module and passes the time in as a value.
--
-- Nothing is invented: a player the server does not list has an unknown clock (nil, never 0), and
-- an entry that lacks a required field is rejected whole. `spent` is the server's "this clock ran
-- out and stays out until the next reset".

PVP.ClockView = {}
local ClockView = PVP.ClockView

local is_table = PVP.StateValue.is_table

local function number(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- One wire entry as { ms, running, rate, n, spent }, or nil with the reason it is not a clock.
-- `ms` is the time left at the moment the entry was sent, `rate` 1 or 2, `n` bumps on every change.
function ClockView.parse(entry)
	if not is_table(entry) then return nil, "not a table" end
	if not number(entry.ms) or entry.ms < 0 then return nil, "ms" end
	if type(entry.running) ~= "boolean" then return nil, "running" end
	if not number(entry.rate) or entry.rate <= 0 then return nil, "rate" end
	if not number(entry.n) or entry.n < 0 or entry.n % 1 ~= 0 then return nil, "n" end
	if type(entry.spent) ~= "boolean" then return nil, "spent" end
	return { ms = entry.ms, running = entry.running, rate = entry.rate, n = entry.n, spent = entry.spent }
end

-- The state value as { [id] = clock } plus { [id] = reason } for the entries rejected, or nil when
-- there is no value to read. A rejected player has no clock here: unknown, not a default.
function ClockView.players(value)
	if not is_table(value) then return nil end
	local clocks, rejected = {}, {}
	for id, entry in pairs(value) do
		local clock, reason = ClockView.parse(entry)
		if clock then
			clocks[id] = clock
		else
			rejected[id] = reason
		end
	end
	return clocks, rejected
end

-- The clock to keep after a push, `at` being the time (seconds) the push arrived. Every change of
-- the server's clock bumps `n`, so a push of the `n` already kept carries the time it already
-- gave, and the countdown it has runs on; a new `n` restarts the countdown from the pushed `ms`.
-- A push shows the time frozen at its `n` (and goes out whenever any player's `n` changes), so the same
-- `n` in a push is a repeat. A snapshot (`from_snapshot`) shows the live time, so it restarts the
-- countdown even at the same `n`: a rejoin or a server restart fixes the clock there.
function ClockView.keep(kept, pushed, at, from_snapshot)
	if kept and kept.n == pushed.n and not from_snapshot then return kept end
	pushed.at = at
	return pushed
end

-- The milliseconds left `now` seconds on the same time base as `clock.at`, or nil for an unknown
-- clock. While it runs the time falls `rate` times as fast as the wall clock. The result never
-- goes below 0: that is for display only, the server decides the run-out.
function ClockView.live_ms(clock, now)
	if not is_table(clock) or not number(clock.at) or not number(now) then return nil end
	if not clock.running then return clock.ms end
	local elapsed_ms = math.max(0, now - clock.at) * 1000
	return math.max(0, clock.ms - elapsed_ms * clock.rate)
end

-- What a clock shows `now`: { known, ms, running, rate, spent }. An unknown clock is
-- { known = false } with every other field nil, so the box draws "--". A clock that is not
-- `running` is held by the server (Ready, a PvP hold, ahead, tied, away): its time stands still.
function ClockView.read(clock, now)
	local ms = ClockView.live_ms(clock, now)
	if ms == nil then return { known = false } end
	return {
		known = true,
		ms = ms,
		running = clock.running,
		rate = clock.rate,
		spent = clock.spent,
	}
end
