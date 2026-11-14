-- Pure view of the server's "pvp.teams" and "pvp.targets" match state, for the team modes
-- (contract: pvp.teams, pvp.targets).
--
-- `pvp.teams` holds `{ runId, teams = { [player id] = "A" | "B" | "RUNNER" | "HUNTER" } }`: in the lobby
-- (runId nil) the picks so far, during a run the settled roster. `pvp.targets` carries the Teams parts:
-- `cardTargets` (who each player's cards aim at) and `teamScores` (each team's summed score).
-- Nothing is stored on the client: every read derives the answer from the state, so a rejoin and a new
-- run have nothing to wipe or restore. pvp_api/teams_net.lua gathers the inputs and acts on the answer.

PVP.TeamsView = {}
local TeamsView = PVP.TeamsView

local same_run = PVP.StateValue.same_run

local OTHER_TEAM = { A = "B", B = "A" }

-- The `{ [player_id] = team }` map: the lobby's picks (value without a runId) or the roster of
-- the current run; `{}` for no value, a value of another run, or anything malformed. An entry
-- that is not a non-empty string is left out.
function TeamsView.roster(teams_value, run_id)
	if type(teams_value) ~= "table" or type(teams_value.teams) ~= "table" then return {} end
	if teams_value.runId ~= nil and not same_run(teams_value, run_id) then return {} end
	local roster = {}
	for player_id, team in pairs(teams_value.teams) do
		if type(player_id) == "string" and type(team) == "string" and team ~= "" then roster[player_id] = team end
	end
	return roster
end

-- The score text of the team opposing `my_team` ("A" or "B"), or nil when the state is not of
-- the current run, has no team scores (outside Teams: JSON null reaches Lua as a missing key),
-- or `my_team` is not a Teams team.
function TeamsView.enemy_score(targets_value, run_id, my_team)
	local enemy_team = OTHER_TEAM[my_team]
	if not enemy_team or not same_run(targets_value, run_id) or type(targets_value.teamScores) ~= "table" then
		return nil
	end
	local score = targets_value.teamScores[enemy_team]
	if type(score) ~= "string" or score == "" then return nil end
	return score
end

-- The player's Teams card target id, or nil for none (a missing key is a JSON null), a value of
-- another run, or a malformed one.
function TeamsView.card_target(targets_value, run_id, player_id)
	if not same_run(targets_value, run_id) or type(targets_value.cardTargets) ~= "table" then return nil end
	local target = targets_value.cardTargets[player_id]
	if type(target) ~= "string" or target == "" then return nil end
	return target
end
