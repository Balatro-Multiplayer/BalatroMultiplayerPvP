-- The team roster, the enemy team's score and the Teams card target, from the server's
-- "pvp.teams" and "pvp.targets" match state (Manhunt and Teams).
--
-- Nothing is requested or stored here: the server settles the teams and picks the card targets.
-- lib/teams_view.lua decides what the state says; this file gathers the inputs and acts. The roster
-- and this player's team are mirrored into PVP.LOBBY.roster / PVP.LOBBY.team_id, which the lobby
-- picker, the vouchers, the ante logic, the queue and lobby_bridge read in both modes.
-- PVP.TeamsNet.card_target_id() reads the state on every call, so PVP.current_target_id()
-- keeps answering after PVP.GAME is rebuilt by a rejoin or a reconnect, with no new push.
--
-- When either key changes, and from N.refresh() (called by the refused pick in PVP.pvp_set_team,
-- pvp_api/actions/team_manhunt.lua, and on CONNECTED in pvp_api/lobby_bridge.lua), the mirror is
-- redrawn and, in Teams, the enemy team's score and the enemy lives follow; in Manhunt a changed
-- roster fixes the ante's Nemesis again.

local TEAMS_KEY = "pvp.teams"
local TARGETS_KEY = "pvp.targets"
local ROUND_KEY = "pvp.round"

PVP.TeamsNet = PVP.TeamsNet or {}
local N = PVP.TeamsNet

local pvp_lobby = PVP.NetBasics.pvp_lobby

local function config()
	return PVP.LOBBY and PVP.LOBBY.config or {}
end

-- This player's card target id (Teams), or nil when there is none (or the server has not said yet).
function N.card_target_id()
	local lobby = MPAPI.get_current_lobby()
	return PVP.TeamsView.card_target(MPAPI.get_state(TARGETS_KEY), PVP.current_run_id(), lobby and lobby.player_id)
end

local function mirror_roster(lobby)
	local roster = PVP.TeamsView.roster(MPAPI.get_state(TEAMS_KEY), PVP.current_run_id())
	PVP.LOBBY.roster = roster
	PVP.LOBBY.team_id = roster[lobby.player_id]
end

-- Teams' HUD shows the other team's summed score, not any one member's.
local function show_enemy_score()
	local targets_value = MPAPI.get_state(TARGETS_KEY)
	local raw = PVP.TeamsView.enemy_score(targets_value, PVP.current_run_id(), PVP.LOBBY.team_id)
	if not raw or not (PVP.GAME and PVP.GAME.enemy) then return end
	local score = PVP.Score.parse(raw)
	if score == nil then
		return PVP.match_log("info", "[pvp] error: the other team's score is not a score: " .. tostring(raw))
	end
	PVP.UI.ease_enemy_score(score)
	PVP.GAME.enemy.real_score = score
	-- The score is shown only when it is this round's: a push for an older round carries its sum.
	if PVP.EnemyScoreView.round_is_mine(MPAPI.get_state(ROUND_KEY), PVP.current_run_id(), PVP.GAME.round_id) then
		PVP.GAME.enemy.score_known = true
	end
end

-- Reads the state again and updates what follows it. Does nothing outside a Manhunt or Teams lobby.
function N.refresh()
	local lobby = pvp_lobby()
	if not lobby or not (config().manhunt or config().team_based) then return end
	mirror_roster(lobby)
	if config().manhunt then return end
	show_enemy_score()
	-- The card target feeds the enemy lives (PVP.current_target_id).
	PVP.refresh_target_lives()
end

-- CONNECTED: the run may have gone live after the last push.
function N.on_connected()
	N.refresh()
end

if MPAPI.on_state then
	MPAPI.on_state(TEAMS_KEY, N.refresh)
	MPAPI.on_state(TARGETS_KEY, N.refresh)
end
