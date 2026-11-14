-- MPAPI.ActionType definitions for the PvP peer protocol, split by concern across
-- this directory. Each action is broadcast over the lobby (broadcast loops back to
-- the sender, so handlers guard on `from == self`). They are mirror/relay actions:
-- a client tells peers about its own state; the opponent applies it through the
-- existing client handler (PVP.dispatch_action). The server referees the game and
-- sends its state through pvp_api/*_net.lua, not through actions.
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
	-- (here, net.lua, and the peer wire action name) misses.
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

