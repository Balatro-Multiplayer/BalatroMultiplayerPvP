-- The enemy's score on the HUD, from the server's "pvp.round" match state.
--
-- The server leaves the score out until this player has played a hand of the round (the score
-- mask), and nothing else carries it: the peer bus sends skips and lives only. So the HUD shows
-- "???" until a push for this round has the score (PVP.GAME.enemy.score_known), then counts up to
-- it. lib/enemy_score_view.lua decides what the state says; this file gathers the inputs and acts.
-- Teams has its own source (pvp_api/teams_net.lua, the team sum), so a team lobby is skipped here.
--
-- Read on a "pvp.round" push (a new score), on a "pvp.targets" push (the opponent can change) and
-- from N.on_connected() (the run may have gone live after the last push).

local ROUND_KEY = "pvp.round"
local TARGETS_KEY = "pvp.targets"

PVP.EnemyScoreNet = PVP.EnemyScoreNet or {}
local N = PVP.EnemyScoreNet

local pvp_lobby = PVP.NetBasics.pvp_lobby

-- Reads the state again and shows the enemy score when it is known for this round.
function N.refresh()
	if not pvp_lobby() or PVP.LOBBY.config.team_based then return end
	local enemy = PVP.GAME and PVP.GAME.enemy
	if not enemy then return end
	local run_id = PVP.current_run_id()
	local round_value = MPAPI.get_state(ROUND_KEY)
	if not PVP.EnemyScoreView.round_is_mine(round_value, run_id, PVP.GAME.round_id) then return end
	local target = PVP.current_target_id()
	-- The hands left are never masked and are the server's alone (the replay tail and the peer bus do
	-- not carry them): nil is unknown (the opponent's blind_start has not landed), and stays nil.
	enemy.hands = PVP.EnemyScoreView.hands(round_value, run_id, target)
	local score = PVP.EnemyScoreView.score(round_value, run_id, target)
	if score == nil then return end

	local known_before = enemy.score_known
	enemy.score_known = true
	local highest = PVP.EnemyScoreView.highest(round_value, run_id, target)
	if highest == nil then
		PVP.match_log("info", "[pvp] error: the server sent a score with no highest score: highest left unset")
	elseif enemy.highest_score == nil or PVP.Score.greater(highest, enemy.highest_score) then
		enemy.highest_score = highest
	end
	-- Same score again (a push for another reason): nothing to count up.
	if known_before and enemy.real_score == score then return end
	enemy.real_score = score
	PVP.UI.ease_enemy_score(score)
end

function N.on_connected()
	N.refresh()
	-- TeamsNet reads before ReadyNet restores the round id, so on a rejoin its sum is not yet known
	-- to be this round's: read it again now that ReadyNet has run.
	if PVP.LOBBY and PVP.LOBBY.config and PVP.LOBBY.config.team_based and PVP.TeamsNet then PVP.TeamsNet.refresh() end
end

if MPAPI.on_state then
	MPAPI.on_state(ROUND_KEY, N.refresh)
	MPAPI.on_state(TARGETS_KEY, N.refresh)
end
