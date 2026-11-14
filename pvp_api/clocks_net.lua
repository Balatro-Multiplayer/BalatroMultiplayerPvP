-- The personal clocks (Pressure, Speedlatro) over the server's "pvp.clocks" match state.
--
-- The server counts every player's clock and pushes it with the time left, whether it runs and its
-- rate; this client only draws it. On every STATE or SNAPSHOT this keeps each listed player's clock
-- with the time it arrived. lib/clock_view.lua decides what the state says and what a clock shows;
-- this file gathers and stores. A player the server does not list has no clock here (unknown).
--
-- The store belongs to one lobby and one run: another lobby or run starts it empty, so a clock of an
-- earlier match is never read as this one's (`n` restarts per match and cannot tell them apart).

local KEY = "pvp.clocks"

PVP.ClocksNet = PVP.ClocksNet or {}
local N = PVP.ClocksNet

-- The lobby and run the clocks were read for, and { [player id] = clock } as ClockView.keep stores it.
local store = { lobby = nil, run = nil, clocks = {} }
-- A snapshot is being applied (SNAPSHOT_APPLIED comes just before the match state is replaced): the
-- next read is the snapshot's, which shows the live time. A push shows the time frozen at its `n`.
local from_snapshot = false

function N.on_snapshot()
	from_snapshot = true
end

function N.evaluate(value)
	local snapshot = from_snapshot
	from_snapshot = false
	local lobby = PVP.NetBasics.pvp_lobby()
	if not lobby then
		store = { lobby = nil, run = nil, clocks = {} }
		return
	end
	local run = PVP.current_run_id()
	if store.lobby ~= lobby or store.run ~= run then store = { lobby = lobby, run = run, clocks = {} } end
	local players, rejected = PVP.ClockView.players(value)
	-- No value (the key is absent on rulesets without a personal clock): no clock is known.
	if not players then
		store.clocks = {}
		return
	end
	local at = love.timer.getTime()
	local kept = {}
	for id, clock in pairs(players) do
		kept[id] = PVP.ClockView.keep(store.clocks[id], clock, at, snapshot)
	end
	for id, reason in pairs(rejected) do
		PVP.match_log("warn", "[pvp] clock of " .. tostring(id) .. " rejected: " .. reason)
	end
	store.clocks = kept
end

-- What player `id`'s clock shows now: { known = false } when the server has not listed it, or when
-- the store was read for another lobby or run than the current one.
function N.read(id)
	local lobby = PVP.NetBasics.pvp_lobby()
	if not lobby or store.lobby ~= lobby or store.run ~= PVP.current_run_id() then return PVP.ClockView.read(nil, nil) end
	return PVP.ClockView.read(store.clocks[id], love.timer.getTime())
end

-- CONNECTED: reads the state again, a crash rejoin's snapshot can arrive before the lobby attaches.
function N.on_connected()
	N.evaluate(MPAPI.get_state(KEY))
end

if MPAPI.on_state then MPAPI.on_state(KEY, N.evaluate) end
