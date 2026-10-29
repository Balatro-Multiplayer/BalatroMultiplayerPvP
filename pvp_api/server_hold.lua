-- Asking the server to hold a started run open while a pending death waits
-- (lobby:set_result_pending), and letting it settle again. The referee decides
-- when (pvp_api/referee.lua); this file only talks to the server. Loaded with
-- the rest of pvp_api/ inside MPAPI.on_loaded; callers use these at runtime only.

-- many_hold: where the server hold of a match of 3 or more players stands.
-- nil before any pending death, ASKING while the first answer is out.
PVP.ManyHold = { ASKING = "asking", HELD = "held", NONE = "none" }

-- Holds the server's run open as a pending result while a pending death waits
-- for the other player. cb(held, err): held is true when the server took the
-- flag; false with no err when this lobby has no server referee; false with
-- err when the server refused it (PVP.is_not_authoritative: it cannot hold runs).
function PVP.hold_server_result(lobby, cb)
	if not MPAPI.has_server_referee(lobby) then
		cb(false, nil)
		return
	end
	lobby:set_result_pending(true, function(err)
		cb(err == nil, err)
	end)
end

-- True when a server refusal says the server does not know the action.
function PVP.is_not_authoritative(err)
	if err == nil then
		return false
	end
	local reason = type(err) == "table" and (err.message or err.reason or err.kind) or err
	return tostring(reason):find("not_authoritative", 1, true) ~= nil
end

-- Lets the run settle again. Called after this client reported the final result.
function PVP.release_server_result(lobby)
	lobby:set_result_pending(false, function(err)
		if err then
			sendWarnMessage("set_result_pending(false) error: " .. tostring(err), "MULTIPLAYER")
		end
	end)
end

-- The client that asked the server to hold the run (PVP.hold_server_result)
-- lets it settle, once its own report is in.
function PVP.release_held_result(lobby)
	if PVP.GAME.result_held and lobby then
		PVP.GAME.result_held = false
		PVP.release_server_result(lobby)
	end
end
