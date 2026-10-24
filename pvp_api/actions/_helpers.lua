-- MPAPI.ActionType definitions for the PvP peer protocol, split by concern across
-- this directory. Each action is broadcast over the lobby (broadcast loops back to
-- the sender, so handlers guard on `from == self`). Two kinds:
--   * mirror/relay  - a client tells peers about its own state; the opponent applies
--                     it through the existing client handler (PVP.dispatch_action).
--   * authoritative - the HOST computes an outcome in referee.lua and broadcasts it;
--                     every client (host included, via loopback) applies it.
--
-- Loaded inside MPAPI.on_loaded (see core.lua) so each ActionType is tagged to this
-- mod; per-lobby routing filters actions by owning mod id.
--
-- Shared helpers for the rest of this directory. Named with a leading underscore so
-- PVP.load_mp_dir's sort ("_" prefixed items first) loads this file before any
-- sibling that references PVP._pvp_action_helpers at file-execution time.

PVP._pvp_action_helpers = {}

-- This client's player id in the current lobby (nil outside a lobby).
function PVP.self_player_id()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.player_id
end
PVP._pvp_action_helpers.self_id = PVP.self_player_id

function PVP._pvp_action_helpers.A(key, on_receive)
	-- prefix_config.key = false: keep the literal `pvp_*` key. Otherwise SMODS
	-- prepends this mod's prefix ("mp") -> "mp_pvp_*", and every lookup by "pvp_*"
	-- (here, the referee, net.lua, and the peer wire action name) misses.
	MPAPI.ActionType({ key = key, on_receive = on_receive, prefix_config = { key = false } })
end

-- Relay: opponent applies `wire` handler; sender ignores its own loopback.
function PVP._pvp_action_helpers.relay(key, wire)
	PVP._pvp_action_helpers.A(key, function(_at, from, params)
		if from == PVP._pvp_action_helpers.self_id() then
			return
		end
		PVP.dispatch_action(wire, params or {})
	end)
end

-- Who this client last heard is host, per lobby: HOST_CHANGED names the new host
-- (pvp_api/lobby_bridge.lua). MPAPI keeps only our own is_host, so until a change
-- is seen a guest can't tell the host from another guest.
local heard_host = setmetatable({}, { __mode = "k" })

function PVP._pvp_action_helpers.note_host(lobby, host_id)
	heard_host[lobby] = host_id
end

function PVP._pvp_action_helpers.forget_host(lobby)
	heard_host[lobby] = nil
end

-- Whether `from` may send a host-only action. The server drops these from anyone
-- but the host already (nakama/src/lobby/sender_guard.ts); this is the client's
-- own check. No lobby: a direct local call.
function PVP._pvp_action_helpers.from_host(from)
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return true
	end
	if lobby.is_host then
		return from == lobby.player_id
	end
	if from == lobby.player_id then
		return false
	end
	local host = heard_host[lobby]
	return host == nil or host == from
end

-- `on_receive` for a host-only action: an action from anyone else is ignored.
function PVP._pvp_action_helpers.host_only(key, on_receive)
	return function(at, from, params)
		if not PVP._pvp_action_helpers.from_host(from) then
			MPAPI.sendWarnMessage("Ignored " .. key .. " from " .. tostring(from) .. ": not the host")
			return
		end
		return on_receive(at, from, params)
	end
end

-- A host-only action (the referee's broadcasts).
function PVP._pvp_action_helpers.A_host(key, on_receive)
	PVP._pvp_action_helpers.A(key, PVP._pvp_action_helpers.host_only(key, on_receive))
end
