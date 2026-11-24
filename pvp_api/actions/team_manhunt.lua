-- Team/role pick, shared by Manhunt's Hunter/Runner picker and Teams' A/B picker. The pick is a `team`
-- input; PVP.LOBBY.roster and team_id are read back from the view (entry_screen.lua), never set here.
function PVP.pvp_set_team(team_id)
	PVP.entry_screen.pick_team(team_id)
end

-- Exactly one Runner is allowed per Manhunt lobby: true once some OTHER player has already claimed
-- the Runner slot (a check for the picker; the server decides at match start).
function PVP.is_runner_taken()
	local lobby = MPAPI.get_current_lobby()
	if not lobby or not PVP.LOBBY.roster then
		return false
	end
	for _, p in ipairs(lobby:get_players()) do
		if p.id ~= lobby.player_id and PVP.LOBBY.roster[p.id] == "RUNNER" then
			return true
		end
	end
	return false
end
