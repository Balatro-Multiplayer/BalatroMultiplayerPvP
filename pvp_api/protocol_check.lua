-- The shell of the server protocol gate (lib/protocol_gate.lua decides, this acts).
--
-- PVP.ProtocolCheck.run(go) asks the server's `pvp_protocol` RPC and calls `go()` only if
-- the answer passes. Otherwise it shows the "server not updated" line and calls nothing,
-- so no ticket is queued and no lobby is created.
--
-- Not cached: one tiny RPC per queue or create click costs nothing, and a cached refusal
-- would keep a player out after the server is updated (a cached pass could outlive a
-- rollback). A click while a check is in flight is dropped, so a double click cannot queue
-- twice, a lost check clears after Check.STALE_SECONDS.

PVP.ProtocolCheck = {}
local Check = PVP.ProtocolCheck

local checking = false
-- Every request of a lobby fails the same way, so only the first `not_supported` acts.
local unsupported_handled = false

-- Tells the player why the check failed.
function Check.refuse(reason)
	PVP.match_log("info", "[pvp] server protocol check failed: " .. tostring(reason))
	if PVP.UI and PVP.UI.UTILS and PVP.UI.UTILS.overlay_message then
		PVP.UI.UTILS.overlay_message(PVP.ProtocolGate.message(reason))
	end
end

-- A check still out after this long is taken as lost (the RPC's own HTTP timeout is 10 s), so a
-- callback that never fires cannot leave every queue and create button dead for the session.
Check.STALE_SECONDS = 15

-- Seconds, monotonic in the game (a wall clock stepping back would drop clicks); a test replaces it.
Check.clock = (love and love.timer and love.timer.getTime) or os.time

local started_at = 0
-- Which check is the live one: a stale check's late answer must start nothing.
local generation = 0

function Check.run(go)
	local now = Check.clock()
	if checking then
		if now - started_at < Check.STALE_SECONDS then
			PVP.match_log("debug", "[pvp] protocol check in flight: click dropped")
			return
		end
		PVP.match_log("info", "[pvp] protocol check lost after " .. tostring(now - started_at) .. " s: checking again")
	end
	checking = true
	started_at = now
	generation = generation + 1
	local mine = generation
	MPAPI.networking.nakama_lobby.rpc(PVP.ProtocolGate.RPC, {}, function(err, data)
		if mine ~= generation then
			return
		end
		checking = false
		local ok, reason = PVP.ProtocolGate.protocol_ok(data, err)
		if ok then
			go()
		else
			Check.refuse(reason)
		end
	end)
end

-- The backstop: a lobby SNAPSHOT the server does not support fails every request with
-- `not_supported` (the API's request layer). Leaves the lobby and shows the same line.
-- A new lobby (any way in, a join by code included, which runs no check) arms it again.
function Check.lobby_started()
	unsupported_handled = false
end

function Check.on_unsupported_lobby()
	if unsupported_handled then
		return
	end
	unsupported_handled = true
	if PVP.pvp_leave_lobby then
		PVP.pvp_leave_lobby()
	end
	Check.refuse("not_supported")
end
