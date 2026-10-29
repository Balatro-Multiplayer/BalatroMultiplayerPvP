local A = PVP._pvp_action_helpers.A
local relay = PVP._pvp_action_helpers.relay

-- The Draft's MPAPI.BanPick config for `gm_def` on the ruleset `ruleset`. The
-- host sends every allowed deck back and the stake cap; the server samples the
-- pool and rolls a stake per deck. The stake cap mirrors PVP's own
-- (ui/lobby/lobby.lua): PVP.DECK.MAX_STAKE when a compatibility mod restricts
-- it, else all 8.
function PVP._ban_pick_config_for(gm_def, ruleset)
	local bp = gm_def.ban_pick
	return {
		id = PVP.SETUP.Step.DRAFT,
		pool_size = bp.pool_size,
		keep = bp.keep,
		schedule = bp.schedule,
		build_pool = function()
			local backs = {}
			for _, center in ipairs(G.P_CENTER_POOLS.Back or {}) do
				backs[#backs + 1] = { key = center.key, mod_id = center.mod and center.mod.id }
			end
			local candidates = {}
			for i, key in ipairs(PVP.SETUP.draft_candidates(
				backs,
				MPAPI.resolve_ruleset_field(ruleset, "allowed_backs"),
				MPAPI.resolve_ruleset_field(ruleset, "banned_backs")
			)) do
				candidates[i] = { key = key }
			end
			return candidates
		end,
		max_stake = (PVP.DECK and PVP.DECK.MAX_STAKE and PVP.DECK.MAX_STAKE > 0) and PVP.DECK.MAX_STAKE or 8,
		-- Stamp the stake sticker onto each deck back (see the game's back_sticker DrawStep).
		decorate_tile = function(card, item)
			if type(item) == "table" and item.stake then
				card.sticker = G.sticker_map[SMODS.stake_from_index(item.stake)]
			end
		end,
		on_refresh = function()
			if PVP.lobby and PVP.lobby.refresh_mm_status then
				PVP.lobby.refresh_mm_status()
			end
		end,
	}
end

-- The host writes the drafted deck and stake over the queued ones in the lobby
-- metadata. The metadata mirror (pvp_api/lobby_bridge.lua) copies it back into
-- PVP.LOBBY on every metadata change, so a stale queued stake there would undo the
-- Draft (and a Reseed would then start on it). The server keeps the drafted stake
-- in the started game itself for a server-run restart.
function PVP.publish_drafted_loadout(lobby, back, stake)
	local patch = {}
	if back then
		patch.deck = back
	end
	if stake then
		patch.stake = tostring(stake)
	end
	if next(patch) then
		lobby:set_metadata(patch)
	end
end

-- Every client's start of a game (params = { seed, stake }): run off the
-- pvp_start_game broadcast (host-refereed lobbies) or off GAME_STARTED
-- (server-refereed lobbies, see pvp_api/lobby_bridge.lua) -- the same body.
-- A rejoin into a game still in Setup calls it again (pvp_api/reconnect.lua).
function PVP.on_game_start(params)
	if PVP.stop_ready_resync then
		PVP.stop_ready_resync()
	end
	if PVP.reset_ready_state then
		PVP.reset_ready_state()
	end

	local lobby = MPAPI.get_current_lobby()
	local meta = (lobby and lobby:get_metadata()) or {}
	local gm_def = meta.queue_mode and MPAPI.GameModes[meta.queue_mode]

	-- picked is a { key, stake } item (deck+stake Draft), a plain deck key/name, or nil.
	local function proceed(picked)
		local deck_ref, stake
		if type(picked) == "table" then
			deck_ref, stake = picked.key, picked.stake
		else
			deck_ref = picked
		end
		if deck_ref then
			-- Draft survivors are center KEYS (e.g. 'b_red'); PVP's run start wants a deck
			-- NAME. Resolve either form to a name, and pin it as the lobby deck so PVP's
			-- copy_host_deck (config.back -> deck.back) doesn't clobber the drafted deck.
			local center = G.P_CENTERS[deck_ref]
			local name = (center and center.name) or deck_ref
			PVP.LOBBY.config.back = name
			PVP.LOBBY.deck.back = name
		end
		if stake then
			PVP.LOBBY.config.stake = stake
			PVP.LOBBY.deck.stake = stake
		end
		if lobby and lobby.is_host then
			PVP.publish_drafted_loadout(lobby, deck_ref and PVP.LOBBY.config.back, stake)
			PVP.referee_reset(PVP.LOBBY.config.starting_lives)
		end
		PVP.dispatch_action("startGame", { seed = params.seed, stake = stake or params.stake })
	end

	-- Setup (pvp_api/setup.lua) runs on the server, so only a server-refereed
	-- lobby has one: the Casual votes, then the matchmaking Draft. Two Draft
	-- shapes exist (gamemodes.lua): BAN_PICK's explicit schedule addresses
	-- exactly two actor slots, so it only drafts at exactly 2 players.
	-- ROTATING_BAN_PICK (Royale/Manhunt/Teams) rotates through however many
	-- players are in the game, so it runs at any N >= 2.
	local plan = { votes = false, draft = false }
	if lobby and MPAPI.has_server_referee(lobby) then
		local started = lobby._game and lobby._game.started
		plan = PVP.SETUP.plan(
			meta.queue_mode,
			PVP._pvp_kind == PVP.LobbyAccess.CASUAL,
			PVP.is_matchmaking and PVP.is_matchmaking(),
			#((started and started.players) or lobby:get_players()),
			gm_def and gm_def.ban_pick
		)
	end
	if not (plan.votes or plan.draft) then
		proceed(meta.deck)
		return
	end
	PVP.SETUP.begin(lobby, plan, function(on_picked)
		-- The Draft's pool follows the ruleset the votes rolled (applied by the
		-- metadata mirror), else the queued one.
		MPAPI.BanPick.start(lobby, PVP._ban_pick_config_for(gm_def, PVP.LOBBY.config.ruleset), function(survivors)
			on_picked(survivors[1])
		end)
	end, function(picked)
		proceed(picked or (lobby:get_metadata() or {}).deck)
	end)
end

A("pvp_start_game", function(_at, from, params)
	PVP.on_game_start(params)
end)

relay("pvp_stop_game", "stopGame")
