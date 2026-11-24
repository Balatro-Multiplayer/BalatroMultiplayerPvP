-- Group casual queue (MPAPI.matchmaking.group): the host of a Party lobby
-- (pvp_api/party_lobby.lua) queues the whole lobby for a casual mode; the group
-- meets strangers in a public match and comes back to this lobby (same code,
-- same host) after it.
-- MPAPI runs the queue; this wires its handles like a solo casual queue's
-- (pvp_api/queue.lua) and says how to rejoin the home lobby.

-- The casual modes a group may queue, in picker order.
PVP.QUEUE.GROUP_MODES = { "pvp_nemesis", "pvp_royale", "pvp_teams", "pvp_smallworld" }

-- The host's pick in the group panel (index into the eligible list).

-- Every group-queueable mode: { key, display, max_players, teams }.
function PVP.QUEUE.group_modes()
	local modes = {}
	for _, key in ipairs(PVP.QUEUE.GROUP_MODES) do
		local def = PVP.RULES.MODES[key]
		local gm = MPAPI.GameModes[key]
		if def and gm then
			modes[#modes + 1] = {
				key = key,
				display = def.display,
				max_players = (gm.max_players and gm.max_players.public) or 2,
				teams = def.team_based and true or false,
			}
		end
	end
	return modes
end

-- The modes this lobby may queue as a group now (each with its refusal, nil
-- = may queue), and the first refusal that applies whatever the mode. A
-- member refused for their standing (MEMBER_REFUSED) still leaves the modes
-- listed: the panel greys the button and names them.
function PVP.QUEUE.group_options(lobby)
	local Group = MPAPI.matchmaking.group
	local facts = Group.facts_from_lobby(lobby)
	local lobby_refusal = Group.eligibility(facts, nil)
	local ranked = Group.rank_modes(Group.without_standings(facts), PVP.QUEUE.group_modes())
	local eligible = {}
	for _, entry in ipairs(ranked) do
		if not entry.refusal then
			eligible[#eligible + 1] = entry.mode
		end
	end
	return eligible, lobby_refusal
end

-- A group queue's handle, host's or member's: the public match it finds is
-- set up as a solo casual match is.
function PVP.QUEUE.wire_group_handle(handle, gamemode_key)
	local function refresh()
		pcall(MPAPI.refresh_current_view)
	end

	handle:on("error", function(err)
		sendWarnMessage("[pvp] group queue error: " .. tostring(err), "MULTIPLAYER")
		-- An error after match_found is a failed lobby join
		PVP.UI.queue.hud.dismiss_reveal()
		if PVP.QUEUE.match_handle == handle then
			PVP.QUEUE.match_handle = nil
		end
		refresh()
		PVP.UI.refusal.show(err)
	end)

	handle:on("queued", function()
		PVP.match_log("debug", "[pvp] group queued for " .. tostring(gamemode_key))
		refresh()
	end)

	handle:on("match_found", function(data)
		PVP.match_log("debug", "[pvp] group match_found " .. tostring(data and data.matchId))
		PVP.UI.queue.hud.match_found({ kind = PVP.LOBBY.Access.CASUAL, key = gamemode_key })
		-- Out of the home lobby (MPAPI parked our seat there) and into a
		-- matchmade one: the lobby view belongs to the public lobby now.
		PVP.LOBBY.kind = PVP.LOBBY.Access.CASUAL
		PVP.RULES.reset_to_gamemode_default(gamemode_key)
		if PVP.UI.lobby then
			PVP.UI.lobby.ref = nil
			PVP.UI.lobby.ui_ref = nil
			PVP.UI.lobby.buttons_initialized = false
		end
	end)

	handle:on("lobby_ready", function(lobby)
		PVP.UI.queue.hud.lobby_ready(lobby)
		PVP.LOBBY.kind = PVP.LOBBY.Access.CASUAL
		PVP.QUEUE.match_handle = handle
		PVP.LOBBY.mirror(lobby)
		if lobby.is_host then
			PVP.UI.lobby.send_settings(lobby, PVP.LOBBY.metadata(gamemode_key, PVP.LOBBY.Access.CASUAL))
		end
		refresh()
	end)

	handle:on("match_resolved", function()
		if PVP.QUEUE.match_handle == handle then
			PVP.QUEUE.match_handle = nil
		end
	end)

	handle:on("left", function()
		PVP.UI.queue.hud.dismiss_reveal()
		if PVP.QUEUE.match_handle == handle then
			PVP.QUEUE.match_handle = nil
		end
		refresh()
	end)
end

-- Host: queue the current private lobby as a group for `gamemode_key`.
-- Returns the handle, or nil and the refusal text.
function PVP.QUEUE.join_group(gamemode_key)
	local Group = MPAPI.matchmaking.group
	local def = PVP.RULES.MODES[gamemode_key]
	local gm = MPAPI.GameModes[gamemode_key]
	if not def or not gm then
		return nil, "unknown mode " .. tostring(gamemode_key)
	end
	local handle, refusal = MPAPI.matchmaking.queue_group({
		mod_id = PVP.id,
		game_mode = gamemode_key,
		min_players = 2,
		max_players = (gm.max_players and gm.max_players.public) or 2,
		teams = def.team_based or nil,
	})
	if not handle then
		local text = Group.refusal_text(refusal)
		sendWarnMessage("[pvp] group queue refused: " .. tostring(text), "MULTIPLAYER")
		if MPAPI.show_notice then
			MPAPI.show_notice("k_group_queue_failed_title", text)
		end
		return nil, text
	end
	PVP.QUEUE.wire_group_handle(handle, gamemode_key)
	pcall(MPAPI.refresh_current_view)
	return handle
end

-- Any member: give up the group queue (the server ends it for everyone).
function PVP.QUEUE.cancel_group()
	MPAPI.matchmaking.group.cancel(function()
		pcall(MPAPI.refresh_current_view)
	end)
end

if MPAPI.matchmaking.group and MPAPI.matchmaking.group.register then
	MPAPI.matchmaking.group.register(PVP.id, {
	on_member_handle = function(handle, view)
		PVP.QUEUE.wire_group_handle(handle, view.mode)
		pcall(MPAPI.refresh_current_view)
	end,
	return_home = function(code)
		PVP.LOBBY.join(code)
		return MPAPI.get_current_lobby()
	end,
	})
end

-- Whether the host may queue the lobby for `key` now, and whether a member's
-- standing refuses it. A refused standing leaves the mode pressable: the
-- server's refusal names the mods (MPAPI api/matchmaking/group/queue.lua).
function PVP.QUEUE.group_mode_available(lobby, key)
	local eligible, refusal = PVP.QUEUE.group_options(lobby)
	local standing_refused = refusal and refusal.code == MPAPI.matchmaking.group.Refusal.MEMBER_REFUSED
	if refusal and not standing_refused then
		return false
	end
	for _, mode in ipairs(eligible) do
		if mode.key == key then
			return true, standing_refused and true or false
		end
	end
	return false
end

-- A pillar's group QUEUE: queue the lobby for that mode and go back to it.
G.FUNCS.mp_pvp_group_queue_mode = function(e)
	local rt = e.config.ref_table
	if rt and rt.gamemode_key and PVP.QUEUE.join_group(rt.gamemode_key) then
		MPAPI.pages.show_deferred("pvp_lobby")
	end
end

G.FUNCS.mp_pvp_group_queue_back = function()
	MPAPI.pages.show_deferred("pvp_lobby")
end

G.FUNCS.mp_pvp_group_cancel = function()
	PVP.QUEUE.cancel_group()
end

G.FUNCS.mp_pvp_group_return = function()
	MPAPI.matchmaking.group.return_home()
end
