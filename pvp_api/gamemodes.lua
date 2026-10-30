-- Bridge GameModes: thin MPAPI.GameMode entry points that delegate into PVP's own
-- ruleset/gamemode/pool-gating machinery (the BRIDGE approach — PVP's composition
-- system stays authoritative; see the plan). Each maps a server/website game-mode
-- key (pvp_nemesis/pvp_smallworld/pvp_royale/pvp_manhunt/pvp_teams — the exact
-- keys the matchmaking server + web leaderboard expect, queried as `ranked:<key>`)
-- onto a PVP ruleset + shape. Ranked queueing is ruleset-scoped instead
-- (pvp_api/queue.lua's PVP._join_ranked_ruleset), not routed through a per-ruleset
-- gamemode key.
--
-- These MUST be loaded inside MPAPI.on_loaded so their GameObjects are tagged to
-- this mod (per-lobby action/gamemode routing depends on the owning mod id).
--
-- Blind selection and ante progression are intentionally NO-OPS here: PVP's own
-- ui/game/round.lua + lovely wiring drive the nemesis/showdown blinds off
-- PVP.LOBBY.config, so the API's reset_blinds/ease_ante overlay (api/gamemode/hooks.lua)
-- must not also mutate the blinds. get_blinds_by_ante returns nothing so the API
-- overlay is a harmless no-op; on_ante_change does nothing. The one API-side hook we
-- do use is on_player_forfeit -> check_single_survivor (win when the opponent quits).

-- The defined winning code path: a gamemode's on_player_forfeit just returns
-- { winner = player_id } and never touches an ActionType or a lobby object.
MPAPI.on_winner_declared(function(winner_id)
	local lobby = MPAPI.get_current_lobby()
	if lobby and MPAPI.ActionTypes["pvp_player_won"] then
		lobby:action(MPAPI.ActionTypes["pvp_player_won"]):broadcast({ player_id = winner_id })
	end
end)

-- The default/fallback queue mode key, referenced as a raw string across several
-- consumer files (flow.lua, queue.lua, pvp_leaderboard.lua) -- kept as one named
-- constant here, next to its definition in PVP.PVP_GAMEMODES below, so those call
-- sites can't drift from this table's actual key. Also the default ruleset every
-- shape (Nemesis/Royale/Manhunt/Teams) creates a private lobby on, overridable
-- afterward via the in-lobby ruleset picker (ui/lobby/lobby_options.lua).
PVP.GamemodeKey = { PVP_NEMESIS = "pvp_nemesis" }

-- There is no separate "plain 1v1" shape: Nemesis's rotating pairing degenerates
-- identically to a plain pairwise 1v1 at exactly 2 players (see referee.lua's
-- try_resolve_round comments), so every ruleset-only entry below IS Nemesis --
-- one shape covers both. Ranked play is always exactly 2 players (matchmaking's
-- ELO/forfeit resolution -- BalatroMultiplayerServer's autoForfeitMatch -- is
-- hardcoded for a 2-player result and would tie multiple players for 1st with
-- more); casual Nemesis is 1v1 too, private lobbies go up to 16 (§17.4).
--
-- pvp_nemesis/pvp_smallworld are the only two ruleset-only entries left as
-- MPAPI.GameMode registrations. pvp_nemesis (the renamed former ranked format)
-- is the private-lobby/practice-mode fallback and casual Nemesis's queue key;
-- ranked queues by ruleset directly (PVP._join_ranked_ruleset,
-- pvp_api/queue.lua) rather than through this gamemode key. Every casual
-- queue plays its gamemode key's own default ruleset.
PVP.PVP_GAMEMODES = {
	pvp_nemesis = { ruleset = "ruleset_mp_balanced", gamemode = "gamemode_mp_attrition", display = "Nemesis", has_ranked = true, custom_bridge = true, nemesis_pairing = true, public_max_players = 2 },
	-- Plays the Royale shape (no pairing): a 2-player game, ranked included, is a plain 1v1.
	pvp_smallworld = { ruleset = "ruleset_mp_smallworld", gamemode = "gamemode_mp_attrition", display = "Small World", has_ranked = true, custom_bridge = true, public_max_players = 16 },
	-- Royale/Manhunt/Teams (2-16 players): never ranked (no per-ruleset ELO ladder
	-- for these), default to the Balanced ruleset like everything else (swappable
	-- in Lobby Options for private lobbies), casual-queueable at up to 16 players.
	pvp_royale = { ruleset = "ruleset_mp_balanced", gamemode = "gamemode_mp_attrition", display = "Royale", has_ranked = false, custom_bridge = true },
	pvp_manhunt = { ruleset = "ruleset_mp_balanced", gamemode = "gamemode_mp_attrition", display = "Manhunt", has_ranked = false, custom_bridge = true, manhunt = true },
	pvp_teams = { ruleset = "ruleset_mp_balanced", gamemode = "gamemode_mp_attrition", display = "Teams", has_ranked = false, custom_bridge = true, team_based = true },
	-- §17.6/§17.3: Experimental is a real, working ruleset (rulesets/experimental/
	-- experimental.lua) that was never wired into any player-facing picker at all --
	-- not a matchmaking gap, an everywhere gap. Deliberately NOT added to the
	-- ipairs registration loop below (no GameMode/matchmaking entry, no ranked
	-- ladder): it stays practice/private-lobby-local, the same scope the doc's
	-- §17.6 item asks for.
	pvp_experimental = { ruleset = "ruleset_mp_experimental", gamemode = "gamemode_mp_attrition", display = "Experimental", has_ranked = false, custom_bridge = true, nemesis_pairing = true },
}

-- Pre-run deck+stake draft (matchmaking only, exactly 2 players -- see
-- run_lifecycle.lua's ban_pick gate): 9 random deck+stake pairs. A random player
-- bans 1, the other bans 3, the first bans 3, then the other PICKS one of the
-- final 2 to play on. Rendered in the matchmaking lobby status panel. Shared by
-- the two ranked-eligible entries below.
local BAN_PICK = {
	pool_size = 9,
	schedule = {
		{ actor = 1, action = "ban", count = 1 },
		{ actor = 2, action = "ban", count = 3 },
		{ actor = 1, action = "ban", count = 3 },
		{ actor = 2, action = "pick", count = 1 },
	},
}

-- §17.7: Royale/Manhunt/Teams's own draft. The legacy {pool_size,keep} shape
-- (no explicit schedule) instead of BAN_PICK above -- BAN_PICK's hand-authored
-- schedule only ever addresses actor slots 1/2, so it silently degenerates to
-- a 2-player draft regardless of lobby size. The legacy shape's derived
-- schedule (derive_schedule/resolve_actor, generalized to N actors this
-- session) genuinely rotates through however many players are actually in
-- the draft, matching the same shape SPDRN's own N-player drafts (All Deck,
-- Challenge, Seed Scout) already ship live with. keep=1: ban every deck+stake
-- pairing down to the one survivor, same "one deck decided by everyone" result
-- BAN_PICK's own pick-step produces, without needing a schedule's explicit
-- final pick action.
local ROTATING_BAN_PICK = {
	pool_size = 9,
	keep = 1,
}

-- The two ranked-eligible entries: identical registration shape, parameterized
-- per ruleset. Ranked is 2 players; the shape at N>2 comes from the entry's
-- flags (Nemesis pairs, Small World ranks like Royale).
for _, key in ipairs({ "pvp_nemesis", "pvp_smallworld" }) do
	local def = PVP.PVP_GAMEMODES[key]
	MPAPI.GameMode({
		key = key,
		-- Keep the literal `pvp_*` key (the server/web matchmaking taxonomy expects it);
		-- otherwise SMODS prefixes it to "mp_pvp_*" and MPAPI.GameModes[key] lookups miss.
		prefix_config = { key = false },
		display_name = def.display,
		has_ranked_mode = def.has_ranked,
		ban_pick = BAN_PICK,
		min_players = 2,
		max_players = { public = def.public_max_players, private = 16, ranked = 2 },
		-- PVP.LOBBY.config.ruleset/gamemode are already correctly populated by the
		-- metadata mirror (lobby_bridge.lua's mirror_metadata) by the time start_run
		-- runs -- setting them here from `def` would stomp a ruleset the host chose
		-- via the in-lobby picker (Lobby Options), reverting it back to this
		-- gamemode key's default every time the match actually starts.
		start_run = function(self, deck_name, seed)
			if deck_name then
				PVP.LOBBY.deck.back = deck_name
			end
			G.FUNCS.lobby_start_run(nil, { seed = seed })
		end,
		-- PVP drives blinds itself; keep the API overlay inert (see header note).
		get_blinds_by_ante = function(self, ante)
			return nil, nil, nil
		end,
		-- Host-authoritative: when the opponent forfeits/leaves, the last player
		-- standing wins. The registered winner handler above performs the broadcast.
		on_player_forfeit = function(self, player_id)
			-- More than two players at the start: the referee knocks the
			-- forfeiter out and ends the match once one player is left.
			if PVP.referee_n_player_forfeit(player_id) then
				return
			end
			local winner_id = self:check_single_survivor(player_id)
			if not winner_id then
				return
			end
			return { winner = winner_id }
		end,
	})
end

-- Royale: rotating N-player draft via ROTATING_BAN_PICK (§17.7). Elimination
-- math (rank-and-cut bottom half) lives in pvp_api/referee.lua.
do
	local def = PVP.PVP_GAMEMODES.pvp_royale
	MPAPI.GameMode({
		key = "pvp_royale",
		prefix_config = { key = false },
		display_name = def.display,
		has_ranked_mode = def.has_ranked,
		ban_pick = ROTATING_BAN_PICK,
		min_players = 2,
		max_players = { public = 16, private = 16 },
		start_run = function(self, deck_name, seed)
			if deck_name then
				PVP.LOBBY.deck.back = deck_name
			end
			G.FUNCS.lobby_start_run(nil, { seed = seed })
		end,
		get_blinds_by_ante = function(self, ante)
			return nil, nil, nil
		end,
		on_player_forfeit = function(self, player_id)
			-- More than two players at the start: the referee knocks the
			-- forfeiter out and ends the match once one player is left.
			if PVP.referee_n_player_forfeit(player_id) then
				return
			end
			local winner_id = self:check_single_survivor(player_id)
			if not winner_id then
				return
			end
			return { winner = winner_id }
		end,
	})
end

-- Manhunt: same bridge shape as Royale, including the rotating draft. Win/loss
-- is asymmetric (Runner vs best-Hunter, not "last one standing"), so forfeit
-- handling calls the dedicated referee helper instead of the generic
-- check_single_survivor -- a Hunter leaving doesn't end the match by itself.
do
	local def = PVP.PVP_GAMEMODES.pvp_manhunt
	MPAPI.GameMode({
		key = "pvp_manhunt",
		prefix_config = { key = false },
		display_name = def.display,
		has_ranked_mode = def.has_ranked,
		ban_pick = ROTATING_BAN_PICK,
		min_players = 2,
		max_players = { public = 16, private = 16 },
		start_run = function(self, deck_name, seed)
			if deck_name then
				PVP.LOBBY.deck.back = deck_name
			end
			G.FUNCS.lobby_start_run(nil, { seed = seed })
		end,
		get_blinds_by_ante = function(self, ante)
			return nil, nil, nil
		end,
		-- Broadcasts pvp_win (winner_team_id) itself -- unlike check_single_survivor's
		-- callers above, NOT returned as { winner = ... }: MPAPI._handle_gamemode_result
		-- would hand a team_id string ("HUNTER") to the generic on_winner_declared
		-- handler above, which broadcasts pvp_player_won with THAT as player_id -- a
		-- string no real client id ever matches, so every client would wrongly resolve
		-- to "I lost".
		on_player_forfeit = function(self, player_id)
			PVP.referee_manhunt_on_forfeit(player_id)
		end,
	})
end

-- Teams: same bridge shape, including the rotating draft. A whole team's
-- roster leaving ends the match for the other team; a single member leaving
-- does not (see PVP.referee_teams_on_forfeit).
do
	local def = PVP.PVP_GAMEMODES.pvp_teams
	MPAPI.GameMode({
		key = "pvp_teams",
		prefix_config = { key = false },
		display_name = def.display,
		has_ranked_mode = def.has_ranked,
		ban_pick = ROTATING_BAN_PICK,
		min_players = 2,
		max_players = { public = 16, private = 16 },
		start_run = function(self, deck_name, seed)
			if deck_name then
				PVP.LOBBY.deck.back = deck_name
			end
			G.FUNCS.lobby_start_run(nil, { seed = seed })
		end,
		get_blinds_by_ante = function(self, ante)
			return nil, nil, nil
		end,
		-- Same reason as Manhunt's forfeit hook above: broadcasts pvp_win itself,
		-- not returned as { winner = ... }.
		on_player_forfeit = function(self, player_id)
			PVP.referee_teams_on_forfeit(player_id)
		end,
	})
end
