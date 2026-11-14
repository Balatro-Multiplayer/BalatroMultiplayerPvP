-- Player-status provider for MPAPI's lobby card grid (see
-- BalatroMultiplayerAPI/api/player_status_providers.lua): a player with 0 or
-- fewer lives is out of the run (dead, or forfeited) and renders debuffed.
--
-- Lives come from PVP._player_lives_cache (pvp_api/lives_net.lua), the cache of
-- the server's pvp.lives state. A player not in it is unknown: the provider returns nil,
-- not true (out) and not false (alive). MPAPI's card grid debuffs only on `true`
-- (api/player_status_providers.lua), so an unknown player renders as an ordinary card,
-- without this mod claiming they are alive.
MPAPI.register_player_status_provider(PVP.id, function(lobby, player_data)
	return PVP.lives_out(PVP._player_lives_cache, player_data.id)
end)
