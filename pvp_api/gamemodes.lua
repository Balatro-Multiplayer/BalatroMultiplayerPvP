-- Bridge GameModes: thin MPAPI.GameMode entry points that delegate into PVP's own
-- ruleset/gamemode/pool-gating machinery (the BRIDGE approach — PVP's composition
-- system stays authoritative; see the plan). Each maps a server/website game-mode
-- key (pvp_nemesis/pvp_smallworld/pvp_royale/pvp_manhunt/pvp_teams — the exact
-- keys the matchmaking server + web leaderboard expect, queried as `ranked:<key>`)
-- onto a PVP ruleset + shape. Ranked queueing is ruleset-scoped instead
-- (pvp_api/queue.lua's PVP.QUEUE.join_ranked), not routed through a per-ruleset
-- gamemode key.
--
-- These MUST be loaded inside MPAPI.on_loaded so their GameObjects are tagged to
-- this mod (per-lobby action/gamemode routing depends on the owning mod id).
--
-- Blind selection and ante progression are intentionally NO-OPS here: PVP's own
-- ui/game/round.lua + lovely wiring drive the nemesis/showdown blinds off
-- PVP.LOBBY.config, so the API's reset_blinds/ease_ante overlay (api/gamemode/hooks.lua)
-- must not also mutate the blinds. get_blinds_by_ante returns nothing so the API
-- overlay is a harmless no-op; on_ante_change does nothing. Who wins, and a leaver's
-- forfeit, are the server's (server_link.lua).

-- The default/fallback queue mode key, referenced as a raw string across several
-- consumer files (flow.lua, queue.lua, pvp_leaderboard.lua) -- kept as one named
-- constant here, next to its definition in PVP.RULES.MODES below, so those call
-- sites can't drift from this table's actual key.
PVP.RULES.GamemodeKey = { PVP_NEMESIS = "pvp_nemesis" }

-- There is no separate "plain 1v1" shape: Nemesis's rotating pairing degenerates
-- identically to a plain pairwise 1v1 at exactly 2 players, so every
-- ruleset-only entry below IS Nemesis -- one shape covers both. Ranked play is always exactly 2 players (matchmaking's
-- ELO/forfeit resolution -- BalatroMultiplayerServer's autoForfeitMatch -- is
-- hardcoded for a 2-player result and would tie multiple players for 1st with
-- more); casual Nemesis is 1v1 too, private lobbies go up to 16.
--
-- pvp_nemesis/pvp_smallworld are the only two ruleset-only entries left as
-- MPAPI.GameMode registrations. pvp_nemesis (the renamed former ranked format)
-- is the private-lobby/practice-mode fallback and casual Nemesis's queue key;
-- ranked queues by ruleset directly (PVP.QUEUE.join_ranked,
-- pvp_api/queue.lua) rather than through this gamemode key. Queues play
-- `ruleset`; private lobbies open on `private_ruleset` if set (see
-- PVP.RULES.default_ruleset), and the host can change it in Lobby Options.
PVP.RULES.MODES = {
	pvp_nemesis = { ruleset = "ruleset_mp_balanced", private_ruleset = "ruleset_mp_expanded", gamemode = "gamemode_mp_attrition", display = "Nemesis", has_ranked = true, custom_bridge = true, nemesis_pairing = true, public_max_players = 2 },
	-- Plays the Royale shape (no pairing): a 2-player game, ranked included, is a plain 1v1.
	pvp_smallworld = { ruleset = "ruleset_mp_smallworld", gamemode = "gamemode_mp_attrition", display = "Small World", has_ranked = true, custom_bridge = true, public_max_players = 16 },
	-- Royale/Manhunt/Teams: 2-16 players, casual only (no ELO ladder for these).
	pvp_royale = { ruleset = "ruleset_mp_balanced", private_ruleset = "ruleset_mp_expanded", gamemode = "gamemode_mp_attrition", display = "Royale", has_ranked = false, custom_bridge = true },
	pvp_manhunt = { ruleset = "ruleset_mp_balanced", private_ruleset = "ruleset_mp_expanded", gamemode = "gamemode_mp_attrition", display = "Manhunt", has_ranked = false, custom_bridge = true, manhunt = true },
	pvp_teams = { ruleset = "ruleset_mp_balanced", private_ruleset = "ruleset_mp_expanded", gamemode = "gamemode_mp_attrition", display = "Teams", has_ranked = false, custom_bridge = true, team_based = true },
	-- Experimental stays practice/private-lobby-local: not in the registration loop below (no
	-- matchmaking entry, no ranked ladder).
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

-- Royale/Manhunt/Teams's own draft. The legacy {pool_size,keep} shape
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
	local def = PVP.RULES.MODES[key]
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
	})
end

-- Royale: rotating N-player draft via ROTATING_BAN_PICK.
do
	local def = PVP.RULES.MODES.pvp_royale
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
	})
end

-- Manhunt: same bridge shape as Royale, including the rotating draft.
do
	local def = PVP.RULES.MODES.pvp_manhunt
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
	})
end

-- Teams: same bridge shape, including the rotating draft.
do
	local def = PVP.RULES.MODES.pvp_teams
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
	})
end
