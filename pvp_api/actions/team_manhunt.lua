-- Team/role assignment, shared by Manhunt's Hunter/Runner picker and Teams' A/B
-- picker. Lobby-phase-only broadcast: each client tells everyone else its own
-- team_id; every receiver (host and guests alike) populates PVP.LOBBY.roster
-- (everyone's current assignment) and, for its own sender, PVP.LOBBY.team_id. The
-- host stamps ref_player().team_id from this roster once the match actually
-- starts (PVP.referee_reset, pvp_api/referee.lua) -- exclusivity/defaults there are
-- authoritative; this roster is a best-effort UI mirror, not the source of truth.
local A = PVP._pvp_action_helpers.A
local self_id = PVP._pvp_action_helpers.self_id
local host_only = PVP._pvp_action_helpers.host_only

function PVP.pvp_set_team(team_id)
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		lobby:action(MPAPI.ActionTypes["pvp_set_team"]):broadcast({ team_id = team_id })
	end
end

A("pvp_set_team", function(_at, from, params)
	PVP.LOBBY.roster = PVP.LOBBY.roster or {}
	PVP.LOBBY.roster[from] = params.team_id
	if from == self_id() then
		PVP.LOBBY.team_id = params.team_id
	end
end)

-- Host -> all, sent once at match start (PVP.referee_reset): the FINAL, real
-- team_id for every player, including anyone who never opened the picker and got
-- a server-computed default. Authoritative, unlike the best-effort pvp_set_team
-- mirror above (which only ever reflects players who actively picked a role).
MPAPI.ActionType({
	key = "pvp_team_roster",
	prefix_config = { key = false },
	parameters = { { key = "roster", type = "table", required = true } },
	on_receive = host_only("pvp_team_roster", function(_at, _from, params)
		PVP.LOBBY.roster = params.roster or {}
		local sid = self_id()
		if sid then
			PVP.LOBBY.team_id = PVP.LOBBY.roster[sid]
		end
	end),
})

-- Exactly one Runner allowed per Manhunt lobby: true once some OTHER player has
-- already claimed the Runner slot (best-effort UI check; PVP.referee_reset is the
-- actual authority at match start, see its header comment).
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

-- Teams' shared-pool life sync (host -> all). Feeds the Teams lives HUD
-- (PVP.GAME.team_lives); individual pl.lives/pvp_player_lives keep flowing
-- separately for the existing per-player lives-reading code (see referee.lua's
-- resolve_teams_round/team_lose_life, which broadcast both).
MPAPI.ActionType({
	key = "pvp_team_lives",
	prefix_config = { key = false },
	parameters = {
		{ key = "team_id", type = "string", required = true },
		{ key = "lives", type = "number", required = true },
	},
	on_receive = host_only("pvp_team_lives", function(_at, _from, params)
		PVP.GAME.team_lives = PVP.GAME.team_lives or {}
		PVP.GAME.team_lives[params.team_id] = tonumber(params.lives)
	end),
})

-- Teams' score-DISPLAY board (host -> all): the true summed opposing-team score,
-- recomputed on every score update (see referee.lua's sum_team_scores/
-- broadcast_live_targets). Separate from pvp_team_card_target below, which is
-- joker/consumable TRIGGERING, not display -- a team's combined score isn't any
-- single member's raw broadcast, so this can't reuse the nemesis blind's
-- per-sender relay the way Royale/Manhunt's id-only broadcasts do.
MPAPI.ActionType({
	key = "pvp_team_score_board",
	prefix_config = { key = false },
	parameters = { { key = "team_scores", type = "table", required = true } },
	on_receive = host_only("pvp_team_score_board", function(_at, _from, params)
		if not PVP.LOBBY.config.team_based or not PVP.LOBBY.team_id then
			return
		end
		local enemy_team = (PVP.LOBBY.team_id == "A") and "B" or "A"
		local raw = params.team_scores and params.team_scores[enemy_team]
		if not raw then
			return
		end
		local score = PVP.Score.or_zero(raw)
		PVP.UI.ease_enemy_score(score)
		PVP.GAME.enemy.real_score = score
		PVP.GAME.enemy.info_received = true
	end),
})

-- Teams' card-targeting rotation (host -> all, re-picked once per ante): a flat
-- id -> target-id-or-"" map, same shape/handling as pvp_nemesis_pairing. Used for
-- joker/consumable triggering (Asteroid/Taxes/Penny Pincher), NOT the score
-- display above.
MPAPI.ActionType({
	key = "pvp_team_card_target",
	prefix_config = { key = false },
	parameters = { { key = "pairing", type = "table", required = true } },
	on_receive = host_only("pvp_team_card_target", function(_at, _from, params)
		local sid = self_id()
		local target = params.pairing and params.pairing[sid]
		PVP.GAME.team_card_target_id = (target and target ~= "") and target or nil
	end),
})

-- Manhunt Runner's live target (host -> all): whichever Hunter currently holds
-- the highest score, recomputed on every score update (referee.lua's
-- broadcast_live_targets). Hunters ignore this -- their target (the Runner) is
-- resolved locally from the static roster instead (PVP.current_target_id()).
MPAPI.ActionType({
	key = "pvp_manhunt_target",
	prefix_config = { key = false },
	parameters = { { key = "target_id", type = "string", required = false } },
	on_receive = host_only("pvp_manhunt_target", function(_at, _from, params)
		if PVP.LOBBY.team_id ~= "RUNNER" then
			return
		end
		PVP.GAME.manhunt_target_id = (params.target_id and params.target_id ~= "") and params.target_id or nil
	end),
})

-- Manhunt's Hieroglyph/Petroglyph replacements (objects/vouchers/manhunt_vouchers.lua)
-- call this when the RUNNER redeems one: every Hunter gains +1 life as
-- compensation for the Runner buying themselves more time to evade.
function PVP.pvp_redeem_ante_voucher()
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		lobby:action(MPAPI.ActionTypes["pvp_redeem_ante_voucher"]):broadcast({})
	end
end

A("pvp_redeem_ante_voucher", function(_at, from, _params)
	PVP.referee_on_redeem_ante_voucher(from)
end)
