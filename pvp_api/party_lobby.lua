-- The Party lobby: a private lobby with no game of its own. Its players queue
-- together for a Casual mode (the group queue, pvp_api/group_queue.lua) and
-- come back to it after the game. The host's metadata says it is one
-- (kind = party), so a joiner and a player back from the game see it too.

-- The lobby this client just created as a Party lobby, before the host's
-- metadata write comes back from the server.
PVP._new_party_lobby = nil

function PVP.is_party_lobby(lobby)
	if not lobby then
		return false
	end
	if lobby == PVP._new_party_lobby then
		return true
	end
	local meta = lobby:get_metadata()
	return type(meta) == "table" and meta.kind == PVP.LobbyAccess.PARTY
end

-- Whether the host may open Find Game: two players or more (no more than a
-- group may be), every player except the host ready, and no queue running.
-- facts = { is_host, queueing, self_id, player_ids = {..}, ready = { [id] = true } }. Pure.
function PVP.party_find_game_enabled(facts)
	if not facts.is_host or facts.queueing then
		return false
	end
	local Group = MPAPI.matchmaking.group
	local ids = facts.player_ids or {}
	if #ids < Group.MIN_SIZE or #ids > Group.MAX_SIZE then
		return false
	end
	for _, id in ipairs(ids) do
		if id ~= facts.self_id and not facts.ready[id] then
			return false
		end
	end
	return true
end

-- The facts party_find_game_enabled reads, from the lobby and the ready tally.
function PVP.party_find_game_facts(lobby, ready_tracker)
	if not lobby then
		return { is_host = false, ready = {} }
	end
	local ids, ready = {}, {}
	for _, p in ipairs(lobby:get_players()) do
		ids[#ids + 1] = p.id
		ready[p.id] = ready_tracker:is_ready(p.id) and true or false
	end
	return {
		is_host = lobby.is_host and true or false,
		queueing = lobby.group_queue ~= nil,
		self_id = lobby.player_id,
		player_ids = ids,
		ready = ready,
	}
end

function PVP.pvp_create_party_lobby()
	if MPAPI.matchmaking.guard_queued(function()
		return PVP.pvp_create_party_lobby()
	end) then
		return
	end
	local lobby = MPAPI.create_lobby(PVP.id, { max_players = MPAPI.matchmaking.group.MAX_SIZE })
	if not lobby then
		sendWarnMessage("pvp_create_party_lobby: failed to create lobby", "MULTIPLAYER")
		return
	end
	PVP._new_party_lobby = lobby
	PVP._pvp_kind = PVP.LobbyAccess.PRIVATE
	PVP._pvp_gamemode = nil
	PVP.setup_lobby_mirror(lobby)
	lobby:on(MPAPI.LobbyEvent.CONNECTED, function()
		if lobby.is_host then
			lobby:set_metadata({ kind = PVP.LobbyAccess.PARTY })
		end
		if love and love.system and love.system.setClipboardText then
			pcall(love.system.setClipboardText, lobby.code)
		end
		MPAPI.refresh_current_view()
	end)
end

-- The host's Find Game: the Casual pillars, each QUEUE queueing the party.
G.FUNCS.mp_pvp_party_find_game = function()
	local lobby = PVP.lobby and PVP.lobby.ref
	if not PVP.party_find_game_enabled(PVP.party_find_game_facts(lobby, PVP.lobby.ready)) then
		return
	end
	MPAPI.pages.show("pvp_find_game", { category = "casual", group = true })
end
