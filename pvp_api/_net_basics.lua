-- The plumbing every net shares (NET.md): PvP's own lobby, the open run's id and the line a
-- refused request leaves in the match log. Loads first (the leading underscore).

PVP.NetBasics = {}
local NetBasics = PVP.NetBasics

-- Only PvP's own lobby: PvP code on vanilla hooks can fire while the player sits in another
-- mod's lobby.
function NetBasics.pvp_lobby()
	local lobby = MPAPI.get_current_lobby()
	if lobby and lobby.mod_id == PVP.id then return lobby end
	return nil
end

-- The open run's id (a string), or nil when no run is open. It stays on PVP, not NetBasics,
-- because code outside the nets uses it too (team_manhunt, run_actions, net.lua).
function PVP.current_run_id()
	local lobby = NetBasics.pvp_lobby()
	local started = lobby and lobby._game and lobby._game.started
	return started and started.run_id and tostring(started.run_id) or nil
end

-- Logs a refused request and returns the server's reason. The state shows the truth, so a
-- refusal is only logged; a net that cares about the reason reads the returned one.
function NetBasics.log_refusal(what, result)
	local reason = result
	if type(result) == "table" then reason = result.reason end
	reason = tostring(reason)
	PVP.match_log("debug", "[pvp] " .. what .. " refused: " .. reason)
	-- The server does not know requests: the lobby SNAPSHOT backstop of the protocol gate.
	if reason == "not_supported" and PVP.ProtocolCheck then PVP.ProtocolCheck.on_unsupported_lobby() end
	return reason
end

-- The answer callback of a request whose refusal is only logged.
function NetBasics.refusal_logger(what)
	return function(ok, result)
		if not ok then NetBasics.log_refusal(what, result) end
	end
end
