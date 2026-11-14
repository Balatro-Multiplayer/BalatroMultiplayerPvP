-- Pure rule for the PvP server protocol gate (D4 R1): before any queue or lobby create,
-- the client asks the server's `pvp_protocol` RPC and refuses to go on when the server
-- is too old to referee the game (a 1.1.0 client on a pre-referee server). No I/O here;
-- the call itself is pvp_api/protocol_check.lua.

PVP.ProtocolGate = {}
local Gate = PVP.ProtocolGate

-- The lowest server protocol this client plays on. Raise it only together with a server
-- change that old clients cannot follow.
Gate.FLOOR = 1

-- The RPC the new server registers; it answers { protocol = <integer> }.
Gate.RPC = "pvp_protocol"

-- Nakama answers a call to an unregistered RPC with NOT_FOUND "RPC function not found". The
-- API passes the server's message through (networking/nakama_lobby.lua) and drops the numeric
-- code, so this whole phrase is what tells an old server from a player who is offline (a bare
-- "not found" also comes from a session refresh for a deleted account).
local function is_rpc_missing(err)
	return type(err) == "string" and err:lower():find("rpc function not found", 1, true) ~= nil
end

-- Decides on the RPC's callback arguments. Returns true, or false and a reason:
--   "not_updated"  the server has no pvp_protocol RPC (an old server)
--   "too_old"      its protocol is below the floor
--   "no_protocol"  it answered without a numeric protocol
--   "unreachable"  any other failure (offline, no session, timeout, bad answer)
function Gate.protocol_ok(response, err)
	if err ~= nil then
		return false, is_rpc_missing(err) and "not_updated" or "unreachable"
	end
	if type(response) ~= "table" then
		return false, "unreachable"
	end
	local protocol = response.protocol
	if type(protocol) ~= "number" then
		return false, "no_protocol"
	end
	if protocol < Gate.FLOOR then
		return false, "too_old"
	end
	return true
end

-- The line shown for a failed check. Only "unreachable" is the player's connection; every
-- other reason (and a lobby SNAPSHOT the server does not support) is a server not updated.
function Gate.message(reason)
	if reason == "unreachable" then
		return localize("k_server_unreachable")
	end
	return localize("k_server_not_updated")
end
