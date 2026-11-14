-- Who this player's opponent is, from the server's "pvp.targets" match state.
--
-- Nothing is requested or stored here: the server pairs the players. PVP.TargetsNet.opponent_id()
-- reads the state on every call (lib/targets_view.lua decides; this file gathers the inputs),
-- so PVP.current_target_id() (pvp_api/lobby_bridge.lua) keeps answering after PVP.GAME is
-- rebuilt by a rejoin or a reconnect, with no new push.
--
-- When the state changes, and from N.on_connected() (lobby_bridge calls it on CONNECTED), the things
-- that depend on the opponent are updated: the enemy lives, the opponent's name in the lobby
-- mirror, the Royale score label and the ante's Nemesis. Nemesis-pairing, Royale and Manhunt
-- lobbies read this state.

local KEY = "pvp.targets"
local RULES_KEY = "pvp.rules"

PVP.TargetsNet = PVP.TargetsNet or {}
local N = PVP.TargetsNet

local pvp_lobby = PVP.NetBasics.pvp_lobby

-- known, opponent_id for this player right now.
local function read()
	local lobby = MPAPI.get_current_lobby()
	return PVP.TargetsView.opponent(MPAPI.get_state(KEY), PVP.current_run_id(), lobby and lobby.player_id)
end

-- The opponent's player id, or nil when there is none (or the server has not said yet).
function N.opponent_id()
	local _, opponent_id = read()
	return opponent_id
end

-- Whether the server has said who the opponent is for the current run (a bye is an answer too).
function N.known()
	local known = read()
	return known
end

-- Royale's safe marker for this player: true or false once the server has ranked them, nil
-- before (and in every other mode).
function N.safe()
	local lobby = MPAPI.get_current_lobby()
	local known, safe = PVP.TargetsView.safe(MPAPI.get_state(KEY), PVP.current_run_id(), lobby and lobby.player_id)
	if not known then return nil end
	return safe
end

-- How many players the current run started with: the server's "pvp.rules" once it has said (the
-- server picks the rules from that count, so a seat that leaves does not change them), the live
-- seat count before (the lobby screen).
function N.player_count(lobby)
	return PVP.LivesView.started_count(MPAPI.get_state(RULES_KEY), PVP.current_run_id()) or #lobby:get_players()
end

-- Whether this lobby takes its opponent from the state: Nemesis pairing, and Royale and Manhunt
-- (more than two players; in Manhunt a Hunter's is the Runner, the Runner's the best-scoring
-- Hunter). A duel is left alone: it names the other player without the state, and the state would
-- only add a second update. Teams has no opponent in the state (its map is empty): the card
-- target comes from PVP.TeamsNet.
local function follows_targets(lobby)
	if PVP.LOBBY.config.nemesis_pairing then return true end
	if PVP.LOBBY.config.team_based then return false end
	return N.player_count(lobby) > 2
end

-- Reads the state again and updates what follows the opponent. Also called on CONNECTED: the
-- run may have gone live after the last push.
function N.refresh()
	local lobby = pvp_lobby()
	if not lobby or not follows_targets(lobby) then return end
	PVP.refresh_target_lives()
	if PVP.CURRENT_LOBBY then PVP.mirror_players(PVP.CURRENT_LOBBY) end
	if PVP.UI and PVP.UI.refresh_enemy_score_label then PVP.UI.refresh_enemy_score_label() end
end

-- CONNECTED: the run may have gone live after the last push.
function N.on_connected()
	N.refresh()
end

if MPAPI.on_state then MPAPI.on_state(KEY, N.refresh) end
