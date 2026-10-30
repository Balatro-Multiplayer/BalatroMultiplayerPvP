-- PvP's Party lobby (MPAPI.Party): its players queue together for a Casual
-- mode (the group queue, pvp_api/group_queue.lua) and come back to it after
-- the game.

function PVP.pvp_create_party_lobby()
	MPAPI.Party.create(PVP.id, function(lobby)
		PVP._pvp_kind = PVP.LobbyAccess.PRIVATE
		PVP._pvp_gamemode = nil
		PVP.setup_lobby_mirror(lobby)
	end)
end

-- The host's Find Game: the Casual pillars, each QUEUE queueing the party.
G.FUNCS.mp_pvp_party_find_game = function()
	local L = PVP.lobby
	if not MPAPI.Party.find_game_enabled(MPAPI.Party.find_game_facts(L.ref, L.ready)) then
		return
	end
	MPAPI.pages.show("pvp_find_game", { category = "casual", group = true })
end
