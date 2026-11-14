-- Team/role assignment, shared by Manhunt's Hunter/Runner picker and Teams' A/B
-- picker. Lobby-phase-only: a pick is a pvp.team request, the server settles the final
-- team of every player at start (pvp.teams), and PVP.LOBBY.roster is a best-effort UI
-- mirror of it, not the source of truth.
function PVP.pvp_set_team(team_id)
	local lobby = MPAPI.get_current_lobby()
	if not lobby then return end
	-- A refused pick shows the server's roster again (pvp_api/teams_net.lua).
	MPAPI.request("pvp.team", { team = team_id }, function(ok)
		if not ok then PVP.TeamsNet.refresh() end
	end)
	-- Our own pick shows at once; the server's pvp.teams state is the truth.
	PVP.LOBBY.roster = PVP.LOBBY.roster or {}
	PVP.LOBBY.roster[lobby.player_id] = team_id
	PVP.LOBBY.team_id = team_id
end

-- Exactly one Runner allowed per Manhunt lobby: true once some OTHER player has
-- already claimed the Runner slot (best-effort UI check; the server is the
-- actual authority at match start).
function PVP.is_runner_taken()
	local lobby = MPAPI.get_current_lobby()
	if not lobby or not PVP.LOBBY.roster then return false end
	for _, p in ipairs(lobby:get_players()) do
		if p.id ~= lobby.player_id and PVP.LOBBY.roster[p.id] == "RUNNER" then return true end
	end
	return false
end

-- Manhunt's Hieroglyph/Petroglyph replacements (objects/vouchers/manhunt_vouchers.lua)
-- call this when the RUNNER redeems one: every Hunter gains +1 life as
-- compensation for the Runner buying themselves more time to evade.
-- The server knows the keys without our "_manhunt" suffix (v_mp_hieroglyph / v_mp_petroglyph).
function PVP.pvp_redeem_ante_voucher(voucher_key)
	local run_id = PVP.current_run_id()
	if run_id then PVP.RoundNet.voucher({ runId = run_id, voucherKey = (voucher_key:gsub("_manhunt$", "")) }) end
end
