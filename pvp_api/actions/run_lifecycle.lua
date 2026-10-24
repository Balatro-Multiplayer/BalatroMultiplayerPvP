local A = PVP._pvp_action_helpers.A
local relay = PVP._pvp_action_helpers.relay

-- Builds the MPAPI.BanPick config for `gm_def`'s deck+stake draft -- shared
-- between the normal on_receive flow below (a fresh draft, kicked off by
-- the pvp_start_game broadcast) and ui/lobby/reconnect.lua's crash-relaunch
-- resume path (MPAPI.BanPick.resume into a draft already in progress) --
-- both need the exact same shape, so this is the one place it's written.
function PVP._ban_pick_config_for(gm_def)
	local bp = gm_def.ban_pick
	return {
		pool_size = bp.pool_size,
		keep = bp.keep,
		schedule = bp.schedule,
		-- 9 distinct random deck backs, each paired with a random stake. The stake
		-- cap mirrors PVP's own (ui/lobby/lobby.lua:346): PVP.DECK.MAX_STAKE when a
		-- compatibility mod restricts it, else all 8.
		build_pool = function()
			local cap = (PVP.DECK and PVP.DECK.MAX_STAKE and PVP.DECK.MAX_STAKE > 0) and PVP.DECK.MAX_STAKE or 8
			local keys = {}
			for _, center in ipairs(G.P_CENTER_POOLS.Back or {}) do
				keys[#keys + 1] = center.key
			end
			for i = #keys, 2, -1 do
				local j = math.random(i)
				keys[i], keys[j] = keys[j], keys[i]
			end
			local pool = {}
			for i = 1, math.min(bp.pool_size, #keys) do
				pool[i] = { key = keys[i], stake = math.random(cap) }
			end
			return pool
		end,
		-- Stamp the stake sticker onto each deck back (see the game's back_sticker DrawStep).
		decorate_tile = function(card, item)
			if type(item) == "table" and item.stake then
				card.sticker = G.sticker_map[SMODS.stake_from_index(item.stake)]
			end
		end,
		state_action = "pvp_ban_pick_state",
		ban_action = "pvp_ban_pick_ban",
		on_refresh = function()
			if PVP.lobby and PVP.lobby.refresh_mm_status then
				PVP.lobby.refresh_mm_status()
			end
		end,
	}
end

-- Builds the on_complete callback for `gm_def`'s draft -- also shared with
-- the reconnect-resume path. `seed`/`fallback_stake` are passed explicitly
-- rather than closed over a pvp_start_game action message's own params: a
-- resumed draft has no such message (the reconnecting client crashed before
-- or during the original broadcast), so it reads net.lua's own
-- lobby-metadata mirror instead (see that file's ROUTES.startGame) --
-- passing them in explicitly keeps this one function correct for both
-- callers instead of needing two near-duplicate versions.
function PVP._ban_pick_on_complete_for(gm_def, lobby, seed, fallback_stake)
	return function(survivors)
		-- picked is a { key, stake } item (deck+stake draft) or nil.
		local picked = survivors and survivors[1]
		local deck_ref, stake
		if type(picked) == "table" then
			deck_ref, stake = picked.key, picked.stake
		else
			deck_ref = picked
		end
		if deck_ref then
			-- Ban-pick survivors are center KEYS (e.g. 'b_red'); PVP's run start wants a deck
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
			PVP.publish_drafted_loadout(lobby, PVP.LOBBY.config.back, stake)
			PVP.referee_reset(PVP.LOBBY.config.starting_lives)
		end
		PVP.dispatch_action("startGame", { seed = seed, stake = stake or fallback_stake })
	end
end

-- Lobby metadata keys PvP shares with the server. Mirrored by hand in
-- BalatroMultiplayerServer nakama/src/actions/registry.ts (DRAFTED_STAKE_KEY).
PVP.LOBBY_METADATA = {
	-- The stake the host drafted: what the server restarts a server-run game on.
	-- The host clears it (empty string) when a new game starts.
	DRAFTED_STAKE = "drafted_stake",
}
local NO_DRAFTED_STAKE = ""

-- The host writes the drafted deck and stake over the queued ones in the lobby
-- metadata. The metadata mirror (pvp_api/lobby_bridge.lua) copies it back into
-- PVP.LOBBY on every metadata change, so a stale queued stake there would undo the
-- draft (and a Reseed would then start on it). LOBBY_METADATA.DRAFTED_STAKE is what
-- the server reads to restart a server-run game on the drafted stake.
function PVP.publish_drafted_loadout(lobby, back, stake)
	local patch = {}
	if back then
		patch.deck = back
	end
	if stake then
		patch.stake = tostring(stake)
		patch[PVP.LOBBY_METADATA.DRAFTED_STAKE] = tostring(stake)
	end
	if next(patch) then
		lobby:set_metadata(patch)
	end
end

-- Every client's start of a game (params = { seed, stake }): run off the
-- pvp_start_game broadcast (host-refereed lobbies) or off GAME_STARTED
-- (server-refereed lobbies, see pvp_api/lobby_bridge.lua) -- the same body.
function PVP.on_game_start(params)
	if PVP.stop_ready_resync then
		PVP.stop_ready_resync()
	end
	if PVP.reset_ready_state then
		PVP.reset_ready_state()
	end

	local lobby = MPAPI.get_current_lobby()
	local meta = (lobby and lobby:get_metadata()) or {}
	-- A draft belongs to one game: clear the last game's before this one starts, so a
	-- start without a draft cannot restart later on an old drafted stake.
	local drafted_stake_key = PVP.LOBBY_METADATA.DRAFTED_STAKE
	if lobby and lobby.is_host and (meta[drafted_stake_key] or NO_DRAFTED_STAKE) ~= NO_DRAFTED_STAKE then
		lobby:set_metadata({ [drafted_stake_key] = NO_DRAFTED_STAKE })
	end
	local gm_def = meta.queue_mode and MPAPI.GameModes[meta.queue_mode]

	-- picked is a { key, stake } item (deck+stake draft), a plain deck key/name, or nil.
	local function proceed(picked)
		local deck_ref, stake
		if type(picked) == "table" then
			deck_ref, stake = picked.key, picked.stake
		else
			deck_ref = picked
		end
		if deck_ref then
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

	-- Matchmaking with a ban_pick config: run the deck+stake draft first, in
	-- lockstep off this same broadcast; the picked deck+stake then starts the run.
	-- Two shapes exist (gamemodes.lua): BAN_PICK's explicit schedule hardcodes
	-- exactly two alternating actor slots (the four ruleset-only entries, also
	-- casual-queueable up to 16 -- §17.4), so those only draft at exactly 2
	-- players and skip straight to proceed() otherwise, same as before this
	-- change. ROTATING_BAN_PICK (§17.7, Royale/Manhunt/Teams) has no schedule --
	-- its derived schedule (derive_schedule/resolve_actor) rotates through
	-- however many players are actually in the draft, so it runs at any N >= 2.
	local n = lobby and #lobby:get_players() or 0
	local bp = gm_def and gm_def.ban_pick
	local n_ok = bp and (bp.schedule and n == 2 or (not bp.schedule and n >= 2))
	if bp and PVP.is_matchmaking and PVP.is_matchmaking() and lobby and n_ok then
		MPAPI.BanPick.start(
			lobby,
			PVP._ban_pick_config_for(gm_def),
			PVP._ban_pick_on_complete_for(gm_def, lobby, params.seed, params.stake)
		)
	else
		proceed(meta.deck)
	end
end

A("pvp_start_game", function(_at, from, params)
	PVP.on_game_start(params)
end)

relay("pvp_stop_game", "stopGame")
