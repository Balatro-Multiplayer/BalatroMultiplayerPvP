-- Host-authoritative PvP referee.
--
-- In the old TCP model the server was the referee: it tracked both players' state,
-- decided who reached the blind first, compared scores, decremented lives, and
-- declared win/loss. The Nakama lobby relays actions but doesn't run PvP's rules, so
-- the HOST client runs that logic. This file is a faithful Lua port of the legacy
-- server's src/actionHandlers.ts + Client.ts resolution rules, operating on a
-- per-player-id table (PVP.REF). Every function is a no-op on non-host clients.
--
-- Authoritative outcomes are broadcast as pvp_* ActionTypes (see actions.lua); all
-- clients (including the host, via broadcast loopback) then apply them through the
-- existing client handlers, so the host and guest stay in lockstep.

PVP.REF = PVP.REF
	or {
		players = {},
		first_ready_at = nil,
		-- Nemesis-pairing (rotating no-repeat 1v1 duels, N>2): nemesis_of[id]=partner
		-- id for the current ante (absent = bye this ante); used_pairs is the
		-- no-repeat memory; last_bye_id lets bye assignment prefer rotating away
		-- from whoever byed last time.
		nemesis_of = {},
		used_pairs = {},
		nemesis_ante_computed_for = 0,
		last_bye_id = nil,
		-- Teams: shared per-team life pools ({A=n, B=n}). Unused by Manhunt, which
		-- keeps asymmetric per-player lives (Runner=1, Hunter=manhunt_hunter_lives)
		-- on the existing pl.lives field -- no pool needed there.
		team_lives = {},
		-- Teams: team_card_target[id] = one random opposing-team member id, re-picked
		-- once per ante (same cadence as nemesis_of), used for joker/consumable
		-- triggering (Asteroid/Taxes/Penny Pincher) -- separate from the team score
		-- SUM shown on the HUD (pvp_team_score_board), which isn't routed through a
		-- single target id at all.
		team_card_target = {},
		team_card_ante_computed_for = 0,
		-- eliminated[id] = true once that player has been told it is out (see
		-- announce_eliminations), so each player is told exactly once.
		eliminated = {},
		-- 2-player pending death (lib/pending_death.lua): { player_id, opponent_id,
		-- blind_key, held } while the dead player waits for the opponent, else nil.
		-- blind_results[player_id][blind_key] is each player's result per non-PvP blind.
		pending_death = nil,
		blind_results = {},
		-- Matches of 3 or more players: one entry per dead player (see
		-- PVP.PendingDeath.add_pending). many_hold is nil or a PVP.ManyHold state.
		pending_deaths = {},
		many_hold = nil,
		-- Manhunt (the Runner) or Teams (a team whose shared lives reached 0): { team_id,
		-- blind_key, held } while the other side must beat the blind, else nil.
		team_pending = nil,
	}

local function is_host()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.is_host
end

-- Forward-declared: PVP.referee_on_ready_blind (below) needs to call
-- broadcast_live_targets before its definition further down this file, since a
-- fresh round's board should show reset (0) values immediately rather than
-- stale ones from the round that just ended.
local broadcast_royale_targets, broadcast_live_targets

local function broadcast(key, params)
	local lobby = MPAPI.get_current_lobby()
	if lobby and MPAPI.ActionTypes[key] then
		lobby:action(MPAPI.ActionTypes[key]):broadcast(params or {})
	end
end

local function ref_player(id)
	PVP.REF.players[id] = PVP.REF.players[id]
		or {
			id = id,
			score = PVP.Score.ZERO,
			highest_score = PVP.Score.ZERO,
			hands_left = 4,
			lives = PVP.LOBBY.config.starting_lives or 4,
			skips = 0,
			ante = 1,
			furthest_blind = 0,
			played_this_blind = false,
			is_ready = false,
			first_ready = false,
			lives_blocker = false,
			-- Manhunt ("HUNTER"/"RUNNER") or Teams ("A"/"B"); nil for every other mode.
			-- Stamped from PVP.LOBBY.roster in PVP.referee_reset.
			team_id = nil,
		}
	return PVP.REF.players[id]
end

-- The starting hands each of `ids` reported when readying the blind, keyed by id
-- (only those that reported one).
local function starting_hands_by_id(ids)
	local by_id = {}
	for _, id in ipairs(ids) do
		local hands = PVP.REF.players[id] and PVP.REF.players[id].starting_hands
		if hands then
			by_id[id] = hands
		end
	end
	return by_id
end

-- The two participant ids (host is the local player when we are host).
local function both_players()
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return {}
	end
	local ids = {}
	for _, p in ipairs(lobby:get_players()) do
		ids[#ids + 1] = p.id
	end
	return ids
end

local function opponent_of(id)
	for _, oid in ipairs(both_players()) do
		if oid ~= id then
			return oid
		end
	end
	return nil
end

-- Recomputed fresh every call (never cached): self-heals on disconnect via the
-- existing PLAYER_LEFT-pruned both_players() roster, no separate table to maintain.
local function alive_ids()
	local ids = {}
	for _, id in ipairs(both_players()) do
		if ref_player(id).lives > 0 then
			ids[#ids + 1] = id
		end
	end
	return ids
end

-- A match with more than two players goes on after someone loses their last
-- life. Only pvp_win used to end a client's run, so an eliminated player kept
-- playing (and kept reporting hands) until the whole match was over. Tells each
-- newly eliminated player once, through pvp_eliminated, that it is out.
local announce_eliminations

-- Roster the pending-death rules read: whether each started player is still in
-- the lobby and their lives.
local function pending_roster()
	local present = {}
	for _, id in ipairs(both_players()) do
		present[id] = true
	end
	local roster = {}
	for id, pl in pairs(PVP.REF.players) do
		roster[id] = { present = present[id] == true, lives = pl.lives }
	end
	return roster
end

-- True while the dead player still waits for another player's result.
local function waits_for_result(id)
	local team_pending = PVP.REF.team_pending
	if team_pending and ref_player(id).team_id == team_pending.team_id then
		return true
	end
	local pending = PVP.PendingDeath.find_pending(PVP.REF.pending_deaths, id)
	return pending ~= nil and not PVP.PendingDeath.many_resolved({ pending }, PVP.REF.blind_results, pending_roster())
end

function announce_eliminations()
	PVP.REF.eliminated = PVP.REF.eliminated or {}
	for _, id in ipairs(both_players()) do
		if ref_player(id).lives <= 0 and not PVP.REF.eliminated[id] and not waits_for_result(id) then
			PVP.REF.eliminated[id] = true
			broadcast("pvp_eliminated", { player_id = id })
		end
	end
end

-- Declares pvp_win once exactly one player remains alive (Royale's N-player analog
-- of the 2-player "opponent hit 0 lives" check) -- or a draw if the last life(ves)
-- lost eliminated everyone still standing simultaneously (no single survivor).
-- Returns true if it fired.
local settle_many_pending

local function check_alive_win()
	local alive = alive_ids()
	if #PVP.REF.pending_deaths > 0 then
		-- A pending death in a 3+ player match: the survivors play on, and the
		-- match ends only once every pending death has its answer.
		if #alive > 1 then
			announce_eliminations()
			return false
		end
		announce_eliminations()
		settle_many_pending()
		return true
	end
	if #alive == 0 then
		broadcast("pvp_win", { draw = true })
		return true
	end
	if #alive == 1 then
		broadcast("pvp_win", { winner_id = alive[1] })
		return true
	end
	announce_eliminations()
	return false
end

-- Manhunt/Teams analog of check_alive_win(): the generic "last player standing"
-- rule doesn't apply to either -- Manhunt's Runner has exactly 1 life and dying
-- ends the match for the WHOLE Hunter team regardless of remaining Hunter
-- headcount (not "last person standing"), and Teams' shared pool hitting 0 ends
-- the match regardless of individual teammates' states. Returns true if a win
-- fired. A no-op (and returns false) when neither mode is active.
local resolve_team_pending

local function check_team_win()
	if PVP.REF.team_pending then
		if PVP.LOBBY.config.manhunt then
			announce_eliminations()
		end
		return resolve_team_pending()
	end
	if PVP.LOBBY.config.manhunt then
		local any_hunter_alive = false
		for _, id in ipairs(both_players()) do
			local pl = ref_player(id)
			if pl.team_id == "RUNNER" and pl.lives <= 0 then
				broadcast("pvp_win", { winner_id = "", winner_team_id = "HUNTER" })
				return true
			end
			if pl.team_id == "HUNTER" and pl.lives > 0 then
				any_hunter_alive = true
			end
		end
		if not any_hunter_alive then
			broadcast("pvp_win", { winner_id = "", winner_team_id = "RUNNER" })
			return true
		end
		announce_eliminations()
		return false
	end
	if PVP.LOBBY.config.team_based then
		if (PVP.REF.team_lives.A or 1) <= 0 then
			broadcast("pvp_win", { winner_id = "", winner_team_id = "B" })
			return true
		end
		if (PVP.REF.team_lives.B or 1) <= 0 then
			broadcast("pvp_win", { winner_id = "", winner_team_id = "A" })
			return true
		end
		return false
	end
	return false
end

-- Dispatches to whichever win-check applies to the active mode.
local function check_any_win()
	if PVP.LOBBY.config.manhunt or PVP.LOBBY.config.team_based then
		return check_team_win()
	end
	return check_alive_win()
end

-- A 2-player Nemesis/Royale match (not Manhunt or Teams) that started with two players.
local function is_two_player_match()
	if PVP.LOBBY.config.manhunt or PVP.LOBBY.config.team_based then
		return false
	end
	local started = 0
	for _ in pairs(PVP.REF.players) do
		started = started + 1
	end
	return started == 2
end

local function in_lobby(id)
	for _, other in ipairs(both_players()) do
		if other == id then
			return true
		end
	end
	return false
end

-- Settles the pending death when the opponent's blind results, lives or presence
-- decide it: broadcasts the final result through pvp_win. Returns true when it did.
local function resolve_pending_death()
	local pending = PVP.REF.pending_death
	if not pending then
		return false
	end
	local outcome, winner_id = PVP.PendingDeath.decide(
		pending,
		pending.opponent_id,
		PVP.REF.blind_results,
		{ present = in_lobby(pending.opponent_id), lives = ref_player(pending.opponent_id).lives }
	)
	if outcome == PVP.PendingDeath.Outcome.PENDING then
		return false
	end
	PVP.REF.pending_death = nil
	if outcome == PVP.PendingDeath.Outcome.DRAW then
		broadcast("pvp_win", { draw = true })
	else
		broadcast("pvp_win", { winner_id = winner_id })
	end
	return true
end

-- Asks the server to hold the run open for a pending death. is_current (optional)
-- says whether the pending death is still the one asked about; a hold that answers
-- after it settled is released at once. on_refused runs when the server cannot
-- hold runs: the match then ends as it always did. on_held(held) runs otherwise.
local function hold_run_open(is_current, on_refused, on_held)
	local lobby = MPAPI.get_current_lobby()
	PVP.hold_server_result(lobby, function(held, err)
		if is_current and not is_current() then
			if held then
				PVP.release_server_result(lobby)
			end
			return
		end
		if PVP.is_not_authoritative(err) then
			on_refused()
			check_any_win()
			PVP.referee_checkpoint()
			return
		end
		if err then
			sendWarnMessage("[pvp] could not hold the result: " .. tostring(err), "MULTIPLAYER")
		end
		PVP.GAME.result_held = held
		on_held(held)
	end)
end

-- A player lost their last life on a non-PvP blind. In a 2-player match this
-- waits for the opponent to beat the same blind instead of ending the match.
-- Returns true when it took over (a result or a pending death); false when the
-- caller should end the match as before.
local function begin_pending_death(dead)
	local blind_key = dead.failed_blind
	local opponent_id = opponent_of(dead.id)
	if not (is_two_player_match() and blind_key and opponent_id) or PVP.REF.pending_death then
		return false
	end
	PVP.REF.pending_death = { player_id = dead.id, opponent_id = opponent_id, blind_key = blind_key, held = 0 }
	if resolve_pending_death() then
		return true
	end
	local pending = PVP.REF.pending_death
	hold_run_open(function()
		return PVP.REF.pending_death == pending
	end, function()
		PVP.REF.pending_death = nil
	end, function(held)
		pending.held = held and 1 or 0
		broadcast("pvp_death_pending", {
			player_id = pending.player_id,
			opponent_id = pending.opponent_id,
			blind_key = pending.blind_key,
		})
		PVP.referee_checkpoint()
	end)
	return true
end

local function other_team_id(team_id)
	local others = { RUNNER = "HUNTER", HUNTER = "RUNNER", A = "B", B = "A" }
	return others[team_id]
end

-- Settles the pending death of a whole side (Manhunt's Runner, a Teams team) once
-- the other side's blind results, lives or presence decide it. Returns true when
-- it broadcast the final result through pvp_win.
function resolve_team_pending()
	local pending = PVP.REF.team_pending
	if not pending then
		return false
	end
	local roster = {}
	for id, pl in pairs(PVP.REF.players) do
		if pl.team_id ~= pending.team_id then
			roster[id] = { present = in_lobby(id) and not pl.forfeited, lives = pl.lives }
		end
	end
	local outcome = PVP.PendingDeath.decide_team(pending.blind_key, PVP.REF.blind_results, roster)
	if outcome == PVP.PendingDeath.Outcome.PENDING then
		return false
	end
	PVP.REF.team_pending = nil
	if outcome == PVP.PendingDeath.Outcome.DRAW then
		broadcast("pvp_win", { draw = true })
	else
		broadcast("pvp_win", { winner_id = "", winner_team_id = other_team_id(pending.team_id) })
	end
	return true
end

-- Whether this player's death empties their whole side: Manhunt's lone Runner or a
-- Teams shared pool at 0.
local function empties_side(dead)
	if PVP.LOBBY.config.manhunt then
		return dead.team_id == "RUNNER"
	end
	if not (PVP.LOBBY.config.team_based and dead.team_id) then
		return false
	end
	return (PVP.REF.team_lives[dead.team_id] or 1) <= 0
end

-- A Runner, or a team's last shared life, was lost on a non-PvP blind. The other
-- side must beat the same blind before the match ends. Returns true when it took
-- over (a result or a pending death); false when the caller ends the match as before.
local function begin_team_pending_death(dead)
	local blind_key = dead.failed_blind
	if not (blind_key and empties_side(dead)) or PVP.REF.team_pending then
		return false
	end
	local pending = { team_id = dead.team_id, blind_key = blind_key, held = 0 }
	PVP.REF.team_pending = pending
	if resolve_team_pending() then
		return true
	end
	hold_run_open(function()
		return PVP.REF.team_pending == pending
	end, function()
		PVP.REF.team_pending = nil
	end, function(held)
		pending.held = held and 1 or 0
		broadcast("pvp_death_pending", { team_id = pending.team_id, blind_key = pending.blind_key })
		PVP.referee_checkpoint()
	end)
	return true
end

-- A match that started with 3 or more players, not Manhunt or Teams.
local function is_many_player_match()
	if PVP.LOBBY.config.manhunt or PVP.LOBBY.config.team_based then
		return false
	end
	local started = 0
	for _ in pairs(PVP.REF.players) do
		started = started + 1
	end
	return started >= 3
end

-- Ends a 3+ player match once the last survivor stands and every pending death has
-- its answer. Broadcasts pvp_win with each player's place; players who tie share
-- one. Returns true when it did.
function settle_many_pending()
	local pendings = PVP.REF.pending_deaths
	if #pendings == 0 or PVP.REF.many_result_sent or #alive_ids() > 1 then
		return false
	end
	local roster = pending_roster()
	if not PVP.PendingDeath.many_resolved(pendings, PVP.REF.blind_results, roster) then
		return false
	end
	local ids = {}
	for id in pairs(PVP.REF.players) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	local places = PVP.PendingDeath.places(ids, pendings, PVP.REF.blind_results, roster)
	local first, winner_id = 0, nil
	for _, id in ipairs(ids) do
		if places[id] == 1 then
			first = first + 1
			winner_id = id
		end
	end
	PVP.REF.many_result_sent = true
	broadcast("pvp_win", { places = places, winner_id = first == 1 and winner_id or nil, draw = first ~= 1 or nil })
	return true
end

-- A player lost their last life on a non-PvP blind in a 3+ player match. Records
-- the pending death and holds the server's run open. The match goes on for the
-- survivors; the caller carries on with its usual checks. Returns true when it
-- recorded one.
local function begin_many_pending_death(dead)
	local blind_key = dead.failed_blind
	if not (is_many_player_match() and blind_key) or PVP.PendingDeath.find_pending(PVP.REF.pending_deaths, dead.id) then
		return false
	end
	local out_before = {}
	for id, pl in pairs(PVP.REF.players) do
		if pl.lives <= 0 and id ~= dead.id then
			out_before[id] = true
		end
	end
	PVP.PendingDeath.add_pending(PVP.REF.pending_deaths, dead.id, blind_key, out_before)
	local function announce()
		broadcast("pvp_death_pending", { player_id = dead.id, blind_key = blind_key })
		PVP.referee_checkpoint()
	end
	if PVP.REF.many_hold ~= nil then
		if PVP.REF.many_hold ~= PVP.ManyHold.ASKING then
			announce()
		end
		-- While the first hold answer is out, its callback announces every pending death.
		return true
	end
	PVP.REF.many_hold = PVP.ManyHold.ASKING
	hold_run_open(nil, function()
		PVP.REF.pending_deaths = {}
		PVP.REF.many_hold = PVP.ManyHold.NONE
	end, function(held)
		PVP.REF.many_hold = held and PVP.ManyHold.HELD or PVP.ManyHold.NONE
		for _, pending in ipairs(PVP.REF.pending_deaths) do
			broadcast("pvp_death_pending", { player_id = pending.player_id, blind_key = pending.blind_key })
		end
		PVP.referee_checkpoint()
		settle_many_pending()
	end)
	return true
end

local function pair_key(a, b)
	if a > b then
		a, b = b, a
	end
	return a .. ":" .. b
end

-- Standard round-robin circle method: fix ids[1], rotate the remaining ids by
-- `offset` positions, then pair (1,2),(3,4),... Deterministic (unlike shuffle-and-
-- retry, which degenerates badly at small N) -- every rotation 0..#ids-2 yields a
-- distinct perfect matching, together covering every possible pair exactly once.
local function circle_round(ids, offset)
	local n = #ids
	local rotated = { ids[1] }
	for i = 1, n - 1 do
		local src = ((i - 1 + offset) % (n - 1)) + 2
		rotated[#rotated + 1] = ids[src]
	end
	local out = {}
	for i = 1, n, 2 do
		out[#out + 1] = { rotated[i], rotated[i + 1] }
	end
	return out
end

-- Recomputes PVP.REF.nemesis_of for the current ante from the given alive roster:
-- a no-repeat (until every possible pair has been used, at which point the cycle
-- restarts) round-robin pairing, with a bye for odd counts that prefers not
-- repeating whoever byed last time.
local function compute_nemesis_pairing(alive)
	PVP.REF.nemesis_of = {}
	if #alive < 2 then
		return
	end

	local ids = {}
	for _, id in ipairs(alive) do
		ids[#ids + 1] = id
	end
	for i = #ids, 2, -1 do
		local j = math.random(i)
		ids[i], ids[j] = ids[j], ids[i]
	end

	local bye_id = nil
	if #ids % 2 == 1 then
		local idx = 1
		for i, id in ipairs(ids) do
			if id ~= PVP.REF.last_bye_id then
				idx = i
				break
			end
		end
		bye_id = table.remove(ids, idx)
	end

	local n = #ids
	local chosen = nil
	if n >= 2 then
		for offset = 0, n - 2 do
			local candidate = circle_round(ids, offset)
			local ok = true
			for _, p in ipairs(candidate) do
				if PVP.REF.used_pairs[pair_key(p[1], p[2])] then
					ok = false
					break
				end
			end
			if ok then
				chosen = candidate
				break
			end
		end
		if not chosen then
			-- Every possible pair among the current alive set has already been used --
			-- the no-repeat cycle restarts.
			PVP.REF.used_pairs = {}
			chosen = circle_round(ids, 0)
		end
		for _, p in ipairs(chosen) do
			PVP.REF.nemesis_of[p[1]] = p[2]
			PVP.REF.nemesis_of[p[2]] = p[1]
			PVP.REF.used_pairs[pair_key(p[1], p[2])] = true
		end
	end
	PVP.REF.last_bye_id = bye_id
end

-- Broadcasts the current ante's pairing to everyone (flat id -> partner-id-or-"" map
-- for every currently-alive id) so each client can resolve PVP.current_target_id().
local function broadcast_nemesis_pairing()
	local payload = {}
	for _, id in ipairs(alive_ids()) do
		payload[id] = PVP.REF.nemesis_of[id] or ""
	end
	broadcast("pvp_nemesis_pairing", { pairing = payload, ante = PVP.REF.nemesis_ante_computed_for })
end

-- Recomputes PVP.REF.team_card_target for the current ante: each alive player is
-- assigned one random currently-alive OPPOSING-team member, for joker/consumable
-- triggering (Asteroid/Taxes/Penny Pincher). Re-picked once per ante, same cadence
-- as compute_nemesis_pairing -- kept separate from the team score SUM shown on the
-- HUD (pvp_team_score_board), which isn't routed through a target id at all.
local function compute_team_card_targets(alive)
	PVP.REF.team_card_target = {}
	local by_team = { A = {}, B = {} }
	for _, id in ipairs(alive) do
		local team_id = ref_player(id).team_id
		if by_team[team_id] then
			table.insert(by_team[team_id], id)
		end
	end
	for _, id in ipairs(alive) do
		local my_team = ref_player(id).team_id
		local enemy_team = (my_team == "A") and "B" or "A"
		local candidates = by_team[enemy_team]
		if candidates and #candidates > 0 then
			PVP.REF.team_card_target[id] = candidates[math.random(#candidates)]
		end
	end
end

-- Broadcasts the current ante's team card-targeting assignments to everyone (flat
-- id -> target-id-or-"" map) so each client can resolve PVP.current_target_id().
local function broadcast_team_card_target()
	local payload = {}
	for _, id in ipairs(alive_ids()) do
		payload[id] = PVP.REF.team_card_target[id] or ""
	end
	broadcast("pvp_team_card_target", { pairing = payload })
end

-- Best PvP score for a player (host referee state) as score text, for the
-- matchmaking `metricText` (season-best score column). Host-only.
function PVP.pvp_score_text(player_id)
	local pl = PVP.REF and PVP.REF.players and PVP.REF.players[player_id]
	if not pl then
		return PVP.Score.ZERO
	end
	return PVP.Score.or_zero(pl.highest_score or pl.score)
end

-- The same best score as the old plain number (`metric`), which a score board
-- no longer reads. It stays for the report's shape: a whole number up to 1e15,
-- else 1e15.
function PVP.pvp_score_metric(player_id)
	local text = PVP.pvp_score_text(player_id)
	local cap = 1e15
	if text:find(",", 1, true) then
		return cap
	end
	return math.min(tonumber(text) or 0, cap)
end

-- Reset all referee state at game start and stamp starting lives (option override
-- else the gamemode default). Mirrors Lobby.setPlayersLives + resetPlayers.
-- A player who crashed and rejoined rebuilt its run from its own replay
-- stream, which leaves its PVP.GAME.lives at reset_game_states' 0. Its next
-- hand reports that 0 back here (referee_on_play_hand trusts it), so without
-- a resend a rejoin silently costs every remaining life. Re-send its lives.
-- Its client also starts over with nobody's lives known (both sides of its
-- Lives box read 0) and with nothing readied, so every player's lives go out,
-- and the readiness the referee still holds for it is dropped: left set, the
-- opponent's ready would start the PvP blind under a player still in its shop.
function PVP.referee_on_player_reconnected(player_id)
	if not is_host() then
		return
	end
	local pl = PVP.REF.players[player_id]
	if not (pl and pl.lives) then
		return
	end
	pl.is_ready = false
	if PVP.REF.ready_tracker then
		PVP.REF.ready_tracker:set(player_id, false)
	end
	-- The returning client rebuilt its game state (PVP.pvp_join_lobby resets it), which
	-- dropped who its opponent is: the pairing is only sent when an ante starts, so
	-- without this it never learns it again, and every lives update about its opponent
	-- (pvp_player_lives) is skipped as "not my target". Sent before the lives.
	if PVP.LOBBY.config.nemesis_pairing then
		broadcast_nemesis_pairing()
	elseif PVP.LOBBY.config.team_based then
		broadcast_team_card_target()
	end
	-- It also dropped the team roster (sent once, at the match start). A Manhunt
	-- Hunter finds its target (the Runner) in the roster, so this goes before the
	-- lives too, or the Hunter skips the Runner's lives.
	if PVP.LOBBY.config.manhunt or PVP.LOBBY.config.team_based then
		local roster = {}
		for id, other in pairs(PVP.REF.players) do
			roster[id] = other.team_id
		end
		broadcast("pvp_team_roster", { roster = roster })
	end
	for id, other in pairs(PVP.REF.players) do
		broadcast("pvp_player_lives", { player_id = id, lives = other.lives })
	end
	if PVP.LOBBY.config.team_based then
		for team_id, lives in pairs(PVP.REF.team_lives or {}) do
			broadcast("pvp_team_lives", { team_id = team_id, lives = lives })
		end
	end
	-- The rebuilt state also dropped the live target (sent on score updates): without
	-- it a Royale player or the Manhunt Runner has no target until the next score update.
	broadcast_live_targets()
end

-- The team each player of a server team plan ({ {ids}, {ids} }, a matchmade
-- Teams lobby's snapshot.teamPlan) plays on: { [id] = "A" | "B" }; empty for
-- no plan. Pure.
function PVP.roster_from_team_plan(plan)
	local roster = {}
	if type(plan) ~= "table" then
		return roster
	end
	for i, team in ipairs({ "A", "B" }) do
		for _, id in ipairs(type(plan[i]) == "table" and plan[i] or {}) do
			roster[id] = team
		end
	end
	return roster
end

function PVP.referee_reset(starting_lives)
	if not is_host() then
		return
	end
	PVP.REF.players = {}
	PVP.REF.first_ready_at = nil
	if PVP.REF.ready_tracker then
		PVP.REF.ready_tracker:reset()
	end
	PVP.REF.nemesis_of = {}
	PVP.REF.used_pairs = {}
	PVP.REF.nemesis_ante_computed_for = 0
	PVP.REF.last_bye_id = nil
	PVP.REF.team_lives = {}
	PVP.REF.team_card_target = {}
	PVP.REF.team_card_ante_computed_for = 0
	PVP.REF.eliminated = {}
	PVP.REF.pending_death = nil
	PVP.REF.pending_deaths = {}
	PVP.REF.many_hold = nil
	PVP.REF.team_pending = nil
	PVP.REF.many_result_sent = nil
	PVP.REF.blind_results = {}
	local lives = starting_lives or PVP.LOBBY.config.starting_lives or 4
	local total = both_players()
	for _, id in ipairs(total) do
		local pl = ref_player(id)
		pl.lives = lives
		pl.score = PVP.Score.ZERO
		pl.hands_left = 4
		pl.played_this_blind = false
		pl.is_ready = false
		pl.first_ready = false
		pl.lives_blocker = false
		pl.team_id = PVP.LOBBY.roster and PVP.LOBBY.roster[id] or nil
	end

	if PVP.LOBBY.config.manhunt then
		-- Exactly one Runner: the first player who actually claimed the slot (roster
		-- order isn't meaningful, so pick deterministically off both_players()'s
		-- order), else the first player by default so the mode never ends up with
		-- zero Runners (e.g. a fabricated test roster, or nobody having opened the
		-- picker). Any extra Runner claims (a UI race) are demoted to Hunter.
		local runner_id = nil
		for _, id in ipairs(total) do
			if ref_player(id).team_id == "RUNNER" and not runner_id then
				runner_id = id
			end
		end
		runner_id = runner_id or total[1]
		for _, id in ipairs(total) do
			local pl = ref_player(id)
			pl.team_id = (id == runner_id) and "RUNNER" or "HUNTER"
			pl.lives = (pl.team_id == "RUNNER") and 1 or (PVP.LOBBY.config.manhunt_hunter_lives or 7)
			broadcast("pvp_player_lives", { player_id = id, lives = pl.lives })
		end
	elseif PVP.LOBBY.config.team_based then
		-- A matchmade Teams lobby with groups in it comes with the server's team
		-- plan (each group kept whole on one team): it overrides any pick.
		local planned = PVP.roster_from_team_plan(PVP.CURRENT_LOBBY and PVP.CURRENT_LOBBY.team_plan)
		for _, id in ipairs(total) do
			if planned[id] then
				ref_player(id).team_id = planned[id]
			end
		end
		-- Anyone who never opened the picker (pl.team_id nil) needs a default --
		-- unlike Manhunt's single-Runner fallback, "or 'A'" here left EVERY unpicked
		-- player on the same team (confirmed live: a 4-player lobby with nobody
		-- picking ended up A=4/B=0, a non-functional match). Balance unassigned
		-- players onto whichever team currently has fewer members instead, so a
		-- lobby where nobody picks still comes out an even split.
		local counts = { A = 0, B = 0 }
		for _, id in ipairs(total) do
			local team = ref_player(id).team_id
			if team then
				counts[team] = (counts[team] or 0) + 1
			end
		end
		for _, id in ipairs(total) do
			local pl = ref_player(id)
			if not pl.team_id then
				local team = (counts.B < counts.A) and "B" or "A"
				pl.team_id = team
				counts[team] = counts[team] + 1
			end
		end
		PVP.REF.team_lives = { A = lives, B = lives }
		broadcast("pvp_player_lives", { player_id = "*all*", lives = lives })
		broadcast("pvp_team_lives", { team_id = "A", lives = lives })
		broadcast("pvp_team_lives", { team_id = "B", lives = lives })
	else
		-- Authoritative starting lives to both clients.
		broadcast("pvp_player_lives", { player_id = "*all*", lives = lives })
	end

	if PVP.LOBBY.config.manhunt or PVP.LOBBY.config.team_based then
		-- Authoritative final roster snapshot: a player who never opened the picker
		-- (accepting the server-computed default above) never broadcast their own
		-- pvp_set_team, so PVP.LOBBY.roster/team_id on EVERY client (including
		-- their own) would otherwise never reflect it -- breaking blind reskin
		-- (get_nemesis_key), Teams' cross-team targeting latch, and the pvp_win
		-- winner_team_id resolution in outcomes.lua. Broadcasting the real
		-- assignments once here (not the best-effort pvp_set_team mirror) is what
		-- makes them authoritative.
		local final_roster = {}
		for _, id in ipairs(total) do
			final_roster[id] = ref_player(id).team_id
		end
		broadcast("pvp_team_roster", { roster = final_roster })
	end

	if PVP.LOBBY.config.nemesis_pairing then
		compute_nemesis_pairing(alive_ids())
		PVP.REF.nemesis_ante_computed_for = 1
		broadcast_nemesis_pairing()
	elseif PVP.LOBBY.config.team_based then
		compute_team_card_targets(alive_ids())
		PVP.REF.team_card_ante_computed_for = 1
		broadcast_team_card_target()
	end
end

-- loseLife(): decrement once per round (guarded by lives_blocker, re-armed by
-- newRound). Broadcasts the loser's new life count to everyone. `lost` marks a
-- real loss (as opposed to the setup/restore/takeover broadcasts of a count),
-- so the loser's client can log life_lost for the achievements.
local function lose_life(pl)
	if pl.lives_blocker or pl.lives <= 0 then
		return
	end
	pl.lives = pl.lives - 1
	pl.lives_blocker = true
	broadcast("pvp_player_lives", { player_id = pl.id, lives = pl.lives, lost = 1 })
end

-- Teams-aware life loss for the fail_round/fail_timer/fail_pvp_timer paths below
-- (non-PvP-round failures: a vanilla boss blind loss, an ante timer expiry, a PvP
-- round timer expiry). Manhunt keeps ordinary per-player lives (lose_life
-- unchanged); Teams must decrement its SHARED pool once and mirror the new value
-- onto every teammate, or these paths would desync an individual's pl.lives from
-- their team's actual pool (the pool is the only thing check_team_win reads).
local function team_lose_life(pl)
	if not PVP.LOBBY.config.team_based then
		lose_life(pl)
		return
	end
	if pl.lives_blocker then
		return
	end
	pl.lives_blocker = true
	local team = pl.team_id
	PVP.REF.team_lives[team] = (PVP.REF.team_lives[team] or 1) - 1
	broadcast("pvp_team_lives", { team_id = team, lives = PVP.REF.team_lives[team] })
	for _, id in ipairs(both_players()) do
		local other = ref_player(id)
		if other.team_id == team then
			other.lives = PVP.REF.team_lives[team]
			broadcast("pvp_player_lives", { player_id = id, lives = other.lives, lost = 1 })
		end
	end
end

-- readyBlind: both ready -> compute firstPlayer, reset per-blind state, start blind.
-- The 2-player path (below) is untouched. For N>2 (Royale) there's no meaningful
-- "first player" HUD ordering, so that concept is dropped and readiness is just
-- "every alive player has readied", via MPAPI.ReadyTracker()'s set/is_ready/reset
-- primitives (checked against alive_ids() ourselves rather than its own all_ready(),
-- which loops the full lobby roster and would stall on eliminated spectators).
function PVP.referee_on_ready_blind(from, starting_hands)
	if not is_host() then
		return
	end
	ref_player(from).starting_hands = tonumber(starting_hands)

	if #both_players() > 2 then
		PVP.REF.ready_tracker = PVP.REF.ready_tracker or MPAPI.ReadyTracker()
		PVP.REF.ready_tracker:set(from, true)
		local alive = alive_ids()
		local all_ready = true
		for _, id in ipairs(alive) do
			if not PVP.REF.ready_tracker:is_ready(id) then
				all_ready = false
				break
			end
		end
		if all_ready then
			PVP.REF.ready_tracker:reset()
			for _, id in ipairs(alive) do
				local pl = ref_player(id)
				pl.score = PVP.Score.ZERO
				pl.hands_left = 4
				pl.played_this_blind = false
			end
			broadcast("pvp_start_blind", { first_player = "", starting_hands = starting_hands_by_id(alive) })
			-- Show fresh (0) values on the live target board immediately, not stale
			-- ones from the round that just ended.
			broadcast_live_targets()
		end
		return
	end

	local me = ref_player(from)
	me.is_ready = true
	local opp = opponent_of(from)
	local enemy = opp and ref_player(opp)

	if not me.first_ready and not (enemy and enemy.is_ready) and not (enemy and enemy.first_ready) then
		me.first_ready = true
	end

	if enemy and me.is_ready and enemy.is_ready then
		me.is_ready = false
		enemy.is_ready = false
		me.score = PVP.Score.ZERO
		enemy.score = PVP.Score.ZERO
		me.hands_left = 4
		enemy.hands_left = 4
		me.played_this_blind = false
		enemy.played_this_blind = false

		-- firstPlayer is the id of whichever player readied first.
		local first_id = me.first_ready and from or (enemy.first_ready and opp or nil)
		broadcast("pvp_start_blind", {
			first_player = first_id or "",
			starting_hands = starting_hands_by_id({ from, opp }),
		})
	end
end

function PVP.referee_on_unready_blind(from)
	if not is_host() then
		return
	end
	ref_player(from).is_ready = false
end

-- Pure: given the 2-player round-end state, decides whether the round is over
-- yet and, if so, who's ahead. Returns nil if the trailing player still has
-- hands left (round not over). roundWinner = the higher score; on an exact tie
-- the FIRST player (a) is the nominal winner (a_lt_b is false when scores are
-- equal) but no life is lost either way (see the equal-handling in
-- try_resolve_round below) -- extracted from try_resolve_round so this
-- decision is independently testable without a live lobby (see
-- ClaudeControl/suites/pvp/referee.lua, which verified this tie-break
-- direction live against the actual expression below).
function PVP.referee_resolve_2p_round(a, b)
	local a_lt_b = PVP.Score.greater(b.score, a.score) -- a.score < b.score
	local b_lt_a = PVP.Score.greater(a.score, b.score)
	local equal = PVP.Score.equal(a.score, b.score)

	local trigger = (a.hands_left < 1 and a_lt_b)
		or (b.hands_left < 1 and b_lt_a)
		or (a.hands_left < 1 and b.hands_left < 1)
	if not trigger then
		return nil
	end

	local winner = a_lt_b and b or a
	local loser = (winner.id == a.id) and b or a
	return { winner = winner, loser = loser, equal = equal }
end

-- Pure: given the Runner's ref_player table and an array of alive Hunters' ref_player
-- tables, decides which Hunters lose a life and whether the Runner is caught this
-- round. Ported from BalatroMultiplayerManhuntServer's BRModeManhunt.checkPVPDone --
-- NOT a rotating pairwise system like Nemesis: the Runner is compared once against
-- the single BEST Hunter score (they only have one life, so only the worst case
-- matters), while each Hunter is compared individually against the Runner (so
-- several Hunters can lose a life in the same round). A Hunter must STRICTLY beat
-- the Runner to survive; ties favor the Runner (they "evade" unless decisively
-- caught) UNLESS the Runner scored exactly 0, in which case a tied (0-0) Hunter is
-- not penalized.
function PVP.referee_resolve_manhunt_round(runner, hunters)
	local highest_hunter_score = PVP.Score.ZERO
	-- Defaults to the first hunter (not nil) so an all-0-0 tie still shows someone
	-- on the Runner's live target board rather than "no target yet".
	local highest_hunter_id = hunters[1] and hunters[1].id or nil
	for _, h in ipairs(hunters) do
		if PVP.Score.greater(h.score, highest_hunter_score) then
			highest_hunter_score = h.score
			highest_hunter_id = h.id
		end
	end

	local hunter_losers = {}
	for _, h in ipairs(hunters) do
		local hunter_behind = PVP.Score.greater(runner.score, h.score)
		local tied = PVP.Score.equal(h.score, runner.score)
		local runner_scored = not PVP.Score.equal(runner.score, PVP.Score.ZERO)
		if hunter_behind or (tied and runner_scored) then
			hunter_losers[#hunter_losers + 1] = h
		end
	end

	return {
		hunter_losers = hunter_losers,
		runner_caught = PVP.Score.greater(highest_hunter_score, runner.score),
		-- The Runner's live HUD target -- whichever Hunter currently holds the
		-- highest score (first-in-iteration-order tiebreak on exact ties). nil only
		-- if `hunters` is empty (shouldn't happen with a live match, but a fabricated
		-- test roster could hit it).
		highest_hunter_id = highest_hunter_id,
	}
end

-- Pure: sums a team's scores this round. Shared by the win/loss decision
-- (PVP.referee_resolve_teams_round below) and the live pvp_team_score_board
-- broadcast (broadcast_live_targets), so the summing rule can't drift between them.
local function sum_team_scores(team_players)
	local scores = {}
	for i, pl in ipairs(team_players) do scores[i] = pl.score end
	return PVP.Score.sum(scores, #team_players)
end

-- Pure: sums each team's scores this round and returns the losing team ("A"/"B"),
-- or equal=true on an exact tie (mirrors the 1v1/Royale "nobody loses on a tie" rule).
function PVP.referee_resolve_teams_round(team_a, team_b)
	local sum_a, sum_b = sum_team_scores(team_a), sum_team_scores(team_b)
	if PVP.Score.equal(sum_a, sum_b) then
		return { equal = true }
	end
	return { equal = false, loser_team = PVP.Score.greater(sum_b, sum_a) and "A" or "B" }
end

-- Pure: ranks alive players by score ascending and returns the same "bottom
-- floor(N/2) (min 1), ties folded down into the loser set" split
-- try_resolve_round's Royale branch has always used -- plus an is_loser lookup so
-- callers (round resolution AND the live pvp_royale_target broadcast) can
-- classify any alive id as currently safe/unsafe without duplicating the
-- cutoff/tie logic. Ties folding an EXTRA player past cutoff_idx into losers is
-- why callers must use is_loser, not just index vs. cutoff_idx, to know who's safe.
function PVP.referee_rank_royale(players)
	local ranked = {}
	for _, pl in ipairs(players) do
		ranked[#ranked + 1] = pl
	end
	table.sort(ranked, function(x, y)
		return PVP.Score.greater(y.score, x.score)
	end)

	local cutoff_idx = math.max(1, math.floor(#ranked / 2))
	local cutoff_score = ranked[cutoff_idx].score
	-- A tie at the cutoff that reaches the top score would fold every player into
	-- the losers, which try_resolve_round treats as a full tie (nobody loses) --
	-- letting a lone low scorer escape just because the others tied above it.
	-- Then the cut sits just under the top score: everyone strictly below it loses.
	local top_score = ranked[#ranked].score
	if not PVP.Score.greater(top_score, cutoff_score) then
		for i = #ranked, 1, -1 do
			if PVP.Score.greater(top_score, ranked[i].score) then
				cutoff_idx, cutoff_score = i, ranked[i].score
				break
			end
		end
	end
	local losers, is_loser = {}, {}
	for _, pl in ipairs(ranked) do
		if not PVP.Score.greater(pl.score, cutoff_score) then
			losers[#losers + 1] = pl
			is_loser[pl.id] = true
		end
	end

	return { ranked = ranked, cutoff_idx = cutoff_idx, losers = losers, is_loser = is_loser }
end

-- Effects wrapper for the Manhunt branch of try_resolve_round: splits the alive
-- roster into the Runner + Hunters, applies PVP.referee_resolve_manhunt_round's
-- outcome, and declares the match over via check_team_win() once appropriate.
local function resolve_manhunt_round(alive)
	local runner, hunters = nil, {}
	for _, id in ipairs(alive) do
		local pl = ref_player(id)
		pl.first_ready = false
		if pl.team_id == "RUNNER" then
			runner = pl
		else
			hunters[#hunters + 1] = pl
		end
	end
	if not runner then
		-- Runner already eliminated/disconnected this round -- forfeit handling
		-- (PVP.referee_manhunt_on_forfeit) already resolved the match.
		return
	end

	local outcome = PVP.referee_resolve_manhunt_round(runner, hunters)
	for _, h in ipairs(outcome.hunter_losers) do
		lose_life(h)
	end
	if outcome.runner_caught then
		lose_life(runner)
	end

	if not check_team_win() then
		broadcast("pvp_end_pvp", { loser_id = "", pvp_timer_lost = false })
	end
end

-- Effects wrapper for the Teams branch of try_resolve_round: sums each team's
-- scores, decrements the losing team's SHARED pool once (not once per member), and
-- keeps every teammate's individual pl.lives mirrored to that pool so the existing
-- per-player lives-reading code (HUD, jokers) keeps working unmodified.
local function resolve_teams_round(alive)
	local by_team = { A = {}, B = {} }
	for _, id in ipairs(alive) do
		local pl = ref_player(id)
		pl.first_ready = false
		if by_team[pl.team_id] then
			table.insert(by_team[pl.team_id], pl)
		end
	end
	local outcome = PVP.referee_resolve_teams_round(by_team.A, by_team.B)
	if not outcome.equal then
		local loser = outcome.loser_team
		PVP.REF.team_lives[loser] = (PVP.REF.team_lives[loser] or 1) - 1
		broadcast("pvp_team_lives", { team_id = loser, lives = PVP.REF.team_lives[loser] })
		for _, id in ipairs(both_players()) do
			local pl = ref_player(id)
			if pl.team_id == loser then
				pl.lives = PVP.REF.team_lives[loser]
				broadcast("pvp_player_lives", { player_id = id, lives = pl.lives, lost = 1 })
			end
		end
	end
	if not check_team_win() then
		broadcast("pvp_end_pvp", { loser_id = "", pvp_timer_lost = false })
	end
end

-- Broadcasts each alive Royale player's personalized live target: a SAFE player
-- (not currently losing a life) is shown the adjacent ranked player with the
-- next-LOWER score (their safety margin); an UNSAFE player is shown the adjacent
-- ranked player with the next-HIGHER score (what they need to beat). Carries ids
-- only -- once a client's PVP.current_target_id() resolves to the right id, the
-- existing raw per-sender score/hands/lives relay (objects/blinds/nemesis.lua)
-- displays the value, no separate score payload needed here.
function broadcast_royale_targets(rank)
	local payload = {}
	for i, pl in ipairs(rank.ranked) do
		local neighbor
		if rank.is_loser[pl.id] then
			neighbor = rank.ranked[i + 1] -- may be nil: the whole alive set tied (nobody loses)
		else
			neighbor = rank.ranked[i - 1] -- may be nil: i == 1, the lowest-ranked "safe" player (full-tie edge case)
		end
		payload[pl.id] = neighbor and neighbor.id or ""
	end
	broadcast("pvp_royale_target", { targets = payload })
end

-- Live (mid-round, not just round-end) target broadcast for N>2 modes, called on
-- every score update so the HUD tracks continuously. A no-op for 2-player lobbies
-- (mirrors try_resolve_round's own size-based branch), Nemesis-pairing (target is
-- the per-ante partner, unrelated to live score), and Manhunt Hunters (their
-- target -- the Runner -- never changes mid-match, resolved locally instead).
function broadcast_live_targets()
	if #both_players() <= 2 or PVP.LOBBY.config.nemesis_pairing then
		return
	end
	local alive = alive_ids()
	if #alive < 2 then
		return
	end

	if PVP.LOBBY.config.manhunt then
		local runner, hunters = nil, {}
		for _, id in ipairs(alive) do
			local pl = ref_player(id)
			if pl.team_id == "RUNNER" then
				runner = pl
			else
				hunters[#hunters + 1] = pl
			end
		end
		if runner and #hunters > 0 then
			local outcome = PVP.referee_resolve_manhunt_round(runner, hunters)
			broadcast("pvp_manhunt_target", { target_id = outcome.highest_hunter_id })
		end
	elseif PVP.LOBBY.config.team_based then
		local by_team = { A = {}, B = {} }
		for _, id in ipairs(alive) do
			local pl = ref_player(id)
			if by_team[pl.team_id] then
				table.insert(by_team[pl.team_id], pl)
			end
		end
		broadcast("pvp_team_score_board", {
			team_scores = {
				A = sum_team_scores(by_team.A),
				B = sum_team_scores(by_team.B),
			},
		})
	else
		local alive_players = {}
		for _, id in ipairs(alive) do
			alive_players[#alive_players + 1] = ref_player(id)
		end
		broadcast_royale_targets(PVP.referee_rank_royale(alive_players))
	end
end

-- The score-comparison round resolution (playHand path). Called after a player's
-- score/hands are updated. Ends the round when the trailing player is out of hands
-- or both are, decided by PVP.Score score with exact-equality = draw.
--
-- Branches on total lobby size (both_players()), not alive count: a lobby that
-- started at 2 always uses the pairwise rule below, untouched. A lobby that
-- started at N>2 always uses the rank-and-cut rule, even after it narrows down to
-- 2 alive -- at exactly 2 alive, floor(2/2)=1 degenerates to "the lower scorer of
-- the pair loses a life", so the ending plays out identically to a 1v1 anyway.
local function try_resolve_round()
	local total = both_players()
	if #total < 2 then
		return
	end

	-- Manhunt/Teams are gated BEFORE the #total==2 check below: both can have
	-- exactly 2 total players (1 Runner+1 Hunter, or a degenerate 1v1 Teams match)
	-- where the generic symmetric pairwise rule would otherwise wrongly apply.
	if PVP.LOBBY.config.manhunt or PVP.LOBBY.config.team_based then
		local alive = alive_ids()
		if #alive < 2 then
			return
		end
		for _, id in ipairs(alive) do
			if ref_player(id).hands_left >= 1 then
				return
			end
		end
		if PVP.LOBBY.config.manhunt then
			resolve_manhunt_round(alive)
		else
			resolve_teams_round(alive)
		end
		return
	end

	if #total == 2 then
		local a, b = ref_player(total[1]), ref_player(total[2])
		local outcome = PVP.referee_resolve_2p_round(a, b)
		if not outcome then
			return
		end
		local winner, loser, equal = outcome.winner, outcome.loser, outcome.equal

		if not equal then
			lose_life(loser)
			if a.lives <= 0 or b.lives <= 0 then
				local game_winner = (a.lives > b.lives) and a or b
				winner.first_ready = false
				loser.first_ready = false
				broadcast("pvp_win", { winner_id = game_winner.id })
				return
			end
		end

		winner.first_ready = false
		loser.first_ready = false
		broadcast("pvp_end_pvp", { loser_id = (not equal) and loser.id or "", pvp_timer_lost = false })
		return
	end

	-- N>2: wait until every alive player is out of hands, then resolve once for the
	-- whole lobby -- either Royale's rank-and-cut, or Nemesis's per-pair scoring.
	-- Sharing this gate means there is always exactly one pvp_end_pvp/pvp_win
	-- broadcast per round, never one per pair: pvp_end_pvp forces every client into
	-- NEW_ROUND, so a per-pair broadcast would corrupt other pairs' still-open rounds.
	local alive = alive_ids()
	if #alive < 2 then
		return
	end
	for _, id in ipairs(alive) do
		if ref_player(id).hands_left >= 1 then
			return
		end
	end

	if PVP.LOBBY.config.nemesis_pairing then
		-- Nemesis: resolve every still-live pair independently (a pair with one side
		-- now eliminated/disconnected is skipped -- the survivor is untouched this
		-- round, equivalent to a bye). Both sides are already guaranteed hands_left<1
		-- by the gate above, so no early-exit-while-trailing nuance is needed here
		-- (unlike the 2-player branch, where responsiveness matters more).
		local seen = {}
		for _, ida in ipairs(alive) do
			ref_player(ida).first_ready = false
			local idb = PVP.REF.nemesis_of[ida]
			if idb and not seen[ida] and not seen[idb] and ref_player(idb).lives > 0 then
				local a, b = ref_player(ida), ref_player(idb)
				if not PVP.Score.equal(a.score, b.score) then
					local loser = PVP.Score.greater(b.score, a.score) and a or b
					lose_life(loser)
				end
				seen[ida] = true
				seen[idb] = true
			end
		end
	else
		-- Royale: rank by score and the bottom floor(N/2) (min 1) lose a life. Ties at
		-- the cutoff are folded into the loser set (not a strict headcount) so a tied
		-- cluster isn't split arbitrarily -- unless the tie reaches every alive player,
		-- in which case (mirroring the 1v1 exact-tie "nobody loses" rule) nobody loses
		-- this round. See PVP.referee_rank_royale for the extracted, independently
		-- testable ranking/cutoff logic (also reused by the live target broadcast).
		local alive_players = {}
		for _, id in ipairs(alive) do
			alive_players[#alive_players + 1] = ref_player(id)
		end
		local rank = PVP.referee_rank_royale(alive_players)
		for _, pl in ipairs(rank.ranked) do
			pl.first_ready = false
		end

		if #rank.losers < #rank.ranked then
			for _, pl in ipairs(rank.losers) do
				lose_life(pl)
			end
		end
	end

	if not check_alive_win() then
		broadcast("pvp_end_pvp", { loser_id = "", pvp_timer_lost = false })
	end
end

-- playHand: store sender score/hands, then attempt resolution.
function PVP.referee_on_play_hand(from, params)
	if not is_host() then
		return
	end
	local known = PVP.REF.players[from] ~= nil
	local pl = ref_player(from)
	pl.score = PVP.Score.or_zero(params.score)
	pl.hands_left = math.floor(tonumber(params.handsLeft) or pl.hands_left)
	if params.skips then
		pl.skips = tonumber(params.skips) or pl.skips
	end
	-- Lives are the referee's own record (referee_reset, lose_life), never the
	-- sender's: a reported value used to overwrite it, so a client could restore
	-- its own lives, and a rejoined client reporting its reset 0 lost them all.
	-- A report is only taken for a player the referee has no record of yet.
	if params.lives and not known then
		pl.lives = tonumber(params.lives) or pl.lives
	end
	if PVP.Score.greater(pl.score, PVP.Score.ZERO) then
		pl.played_this_blind = true
	end
	if PVP.Score.greater(pl.score, pl.highest_score) then
		pl.highest_score = pl.score
	end
	broadcast_live_targets()
	try_resolve_round()
end

function PVP.referee_on_skip(from, params)
	if not is_host() then
		return
	end
	ref_player(from).skips = tonumber(params.skips) or 0
end

function PVP.referee_on_set_ante(from, params)
	if not is_host() then
		return
	end
	local pl = ref_player(from)
	pl.ante = tonumber(params.ante) or pl.ante

	-- Manhunt: the Runner "escapes" by clearing ante 8 (reaching ante 9) without
	-- ever being caught -- an immediate win, mirroring the ante>8 natural-stop
	-- precedent already used by PvP practice mode.
	if PVP.LOBBY.config.manhunt and pl.team_id == "RUNNER" then
		local ante = tonumber(params.ante)
		if ante and ante > 8 then
			broadcast("pvp_win", { winner_id = "", winner_team_id = "RUNNER" })
			return
		end
	end

	-- Nemesis-pairing: recompute once per ante, triggered by whichever alive
	-- player's ease_ante() reports it first. Safe against overlapping with an
	-- in-flight resolution for the OLD ante, because a client can only call
	-- ease_ante() (and thus report a new ante at all) after receiving that ante's
	-- pvp_end_pvp/pvp_win -- which itself can't be sent until try_resolve_round's
	-- batch-resolve for the old ante has already completed.
	if PVP.LOBBY.config.nemesis_pairing then
		local ante = tonumber(params.ante)
		if ante and ante > PVP.REF.nemesis_ante_computed_for then
			PVP.REF.nemesis_ante_computed_for = ante
			compute_nemesis_pairing(alive_ids())
			broadcast_nemesis_pairing()
		end
	elseif PVP.LOBBY.config.team_based then
		-- Teams' card-targeting rotation: same once-per-ante cadence as Nemesis
		-- pairing above (see that branch's comment for why this is race-safe).
		local ante = tonumber(params.ante)
		if ante and ante > PVP.REF.team_card_ante_computed_for then
			PVP.REF.team_card_ante_computed_for = ante
			compute_team_card_targets(alive_ids())
			broadcast_team_card_target()
		end
	end
end

-- Manhunt: the Runner redeemed an ante-skip voucher (manhunt_vouchers.lua) --
-- every Hunter gains +1 life as compensation. A no-op if `from` isn't the Runner
-- (defensive; the vouchers themselves only ever call this for the Runner).
function PVP.referee_on_redeem_ante_voucher(from)
	if not is_host() then
		return
	end
	if ref_player(from).team_id ~= "RUNNER" then
		return
	end
	for _, id in ipairs(both_players()) do
		local pl = ref_player(id)
		if pl.team_id == "HUNTER" then
			pl.lives = pl.lives + 1
			broadcast("pvp_player_lives", { player_id = id, lives = pl.lives })
		end
	end
end

function PVP.referee_on_set_furthest_blind(from, params)
	if not is_host() then
		return
	end
	local pl = ref_player(from)
	pl.furthest_blind = tonumber(params.furthestBlind) or pl.furthest_blind
end

-- newRound: re-arm loseLife for the next round (resetBlocker).
function PVP.referee_on_new_round(from)
	if not is_host() then
		return
	end
	ref_player(from).lives_blocker = false
end

-- failRound: mode-dependent life loss (death_on_round_loss) and match end.
--
-- The general (attrition/Royale/Nemesis) path used to declare pvp_win against
-- opponent_of(from) unconditionally -- at N>2 that's an arbitrary bystander, not
-- necessarily the actual sole survivor, since death_on_round_loss fires on any
-- failed blind, not just nemesis-boss rounds. Fixed to the same "exactly 1 alive"
-- check try_resolve_round uses. For N>2, whether or not this failure eliminated
-- them, force their hands_left to 0 and re-run try_resolve_round(): the batch-wait
-- gate there only progresses once every CURRENTLY alive player is done, and without
-- this nudge a failed-but-not-eliminated player's frozen hands_left (or a now-
-- excluded eliminated one, whose elimination might be exactly what the gate was
-- waiting on) would leave the rest of the lobby stuck.
function PVP.referee_on_fail_round(from)
	if not is_host() then
		return
	end
	local pl = ref_player(from)
	if PVP.LOBBY.config.death_on_round_loss then
		team_lose_life(pl)
	end
	if PVP.REF.pending_death then
		resolve_pending_death()
		return
	end
	if PVP.REF.team_pending then
		resolve_team_pending()
	end
	if pl.lives == 0 then
		if begin_pending_death(pl) or begin_team_pending_death(pl) then
			return
		end
		begin_many_pending_death(pl)
		if check_any_win() then
			return
		end
	end
	if PVP.LOBBY.config.manhunt or PVP.LOBBY.config.team_based or #both_players() > 2 then
		pl.hands_left = 0
		broadcast_live_targets()
		try_resolve_round()
	end
end

-- failTimer (non-PvP ante timer): sender loses a life; match ends only when exactly
-- one player remains alive. Same N>2 progress-nudge as referee_on_fail_round.
function PVP.referee_on_fail_timer(from)
	if not is_host() then
		return
	end
	local pl = ref_player(from)
	team_lose_life(pl)
	if PVP.REF.pending_death then
		resolve_pending_death()
		return
	end
	if PVP.REF.team_pending then
		resolve_team_pending()
	end
	if pl.lives == 0 then
		if begin_pending_death(pl) or begin_team_pending_death(pl) then
			return
		end
		begin_many_pending_death(pl)
		if check_any_win() then
			return
		end
	end
	if PVP.LOBBY.config.manhunt or PVP.LOBBY.config.team_based or #both_players() > 2 then
		pl.hands_left = 0
		broadcast_live_targets()
		try_resolve_round()
	end
end

-- A client's result for a non-PvP blind (pvp_blind_result): beaten or failed.
-- Only matches of 2 or more players use it, to settle pending deaths.
function PVP.referee_on_blind_result(from, params)
	local two_player = is_two_player_match()
	local team_mode = PVP.LOBBY.config.manhunt or PVP.LOBBY.config.team_based
	if not is_host() or not (two_player or is_many_player_match() or team_mode) then
		return
	end
	local blind_key = PVP.PendingDeath.blind_key(params.ante, params.blind)
	local beaten = params.beaten == true
	PVP.PendingDeath.record(PVP.REF.blind_results, from, blind_key, beaten)
	if not beaten then
		ref_player(from).failed_blind = blind_key
	end
	if team_mode then
		resolve_team_pending()
	elseif two_player then
		resolve_pending_death()
	else
		announce_eliminations()
		settle_many_pending()
	end
end

-- A player left while a pending death waits (called on every client from
-- PLAYER_LEFT and pvp_forfeit). The dead player leaving is not a forfeit. The
-- opponent leaving before beating the blind makes the dead player the winner.
-- Returns true when the leave belongs to the pending death, so the caller skips
-- the gamemode's forfeit hook.
function PVP.referee_pending_death_on_player_gone(player_id)
	if PVP.GAME.team_pending then
		-- Manhunt or Teams: nobody's leave is a forfeit while a side waits on the
		-- other. The dead side leaving changes nothing; the other side leaving without
		-- beating the blind counts toward a draw.
		if is_host() then
			local pl = PVP.REF.players[player_id]
			if pl and pl.team_id ~= PVP.GAME.team_pending.team_id then
				pl.forfeited = true
			end
			resolve_team_pending()
		end
		return true
	end
	if PVP.GAME.pending_deaths and PVP.GAME.pending_deaths[player_id] then
		-- A dead player of a 3+ player match leaves: not a forfeit.
		if is_host() then
			announce_eliminations()
			settle_many_pending()
		end
		return true
	end
	local pending = PVP.GAME.pending_death
	if not pending or not pending.opponent_id or (player_id ~= pending.player_id and player_id ~= pending.opponent_id) then
		return false
	end
	if is_host() then
		resolve_pending_death()
	end
	return true
end

-- failPvPTimer: sender loses the PvP round on the timer (always a life; round or
-- match). The 2-player path ends the round directly (there's only one round in
-- flight, so it's safe). For N>2, a single player's timeout must NOT broadcast
-- pvp_end_pvp directly -- that forces every client into NEW_ROUND, corrupting any
-- other pair/comparison still in progress -- so it defers to the same batch-wait
-- gate as everything else via try_resolve_round(). This also fixes a pre-existing
-- bug: this function used to broadcast pvp_end_pvp unconditionally even at N>2.
-- §17.12: previously this ended the whole PvP round outright (life loss +
-- broadcast pvp_end_pvp / force hands_left=0) the instant the PvP timer
-- expired. Per the design doc, running out of time on a single hand should
-- cost exactly that -- one hand, credited with the same time bonus a normal
-- hand-play would have earned -- not the life and the round. hands_left is
-- decremented here directly (the host's own authoritative mirror, kept in
-- sync from the client's own pvp_play_hand reports the same way
-- referee_on_play_hand already updates it) rather than round-tripping
-- through a client acknowledgment; the targeted pvp_timer_hand_lost
-- broadcast below only carries the LOCAL consequence (crediting the timer
-- bonus) back to the specific player who timed out, since score itself is
-- untouched by a timeout and doesn't need re-reporting.
function PVP.referee_on_fail_pvp_timer(from)
	if not is_host() then
		return
	end
	local pl = ref_player(from)
	pl.hands_left = math.max(0, (pl.hands_left or 0) - 1)
	broadcast("pvp_timer_hand_lost", { player_id = from })
	broadcast_live_targets()
	try_resolve_round()
end

-- Royale / N-player Nemesis on_player_forfeit: a player who forfeits or leaves
-- a match that started with more than two players is out, like a player who
-- lost their last life. check_single_survivor only counts lobby members, so a
-- forfeiter still sitting in the lobby (pause-menu forfeit), or an eliminated
-- player still watching, kept the match from ever ending, and the referee went
-- on waiting for the forfeiter's hands. Returns true when it handled the
-- forfeit (host, more than two players at the start), so the caller skips
-- the two-player check_single_survivor path.
function PVP.referee_n_player_forfeit(player_id)
	if not is_host() then
		return false
	end
	local started = 0
	for _ in pairs(PVP.REF.players) do
		started = started + 1
	end
	if started <= 2 or not PVP.REF.players[player_id] then
		return false
	end
	local pl = ref_player(player_id)
	if pl.lives > 0 then
		pl.lives = 0
		broadcast("pvp_player_lives", { player_id = player_id, lives = 0 })
	end
	pl.hands_left = 0
	if check_alive_win() then
		return true
	end
	broadcast_live_targets()
	try_resolve_round()
	return true
end

-- Manhunt's on_player_forfeit: the Runner leaving ends the match immediately in
-- the Hunters' favor (there is nothing left to "escape" against). A Hunter
-- who forfeits is out, like a Hunter who lost their last life: a pause-menu
-- forfeit leaves them in the lobby, so with their lives untouched they were
-- still "alive" to check_team_win -- the button did nothing and they played on
-- (in a 2-player match the Runner could never win by it). The last Hunter out
-- hands the Runner the match; otherwise the forfeiter gets its lose screen
-- (announce_eliminations) and the round resolves without its hands. Returns
-- the winning team_id if this call ended the match, else nil.
function PVP.referee_manhunt_on_forfeit(player_id)
	if not is_host() then
		return nil
	end
	local pl = ref_player(player_id)
	if pl.team_id == "RUNNER" and PVP.REF.team_pending then
		return nil
	end
	if pl.team_id == "RUNNER" then
		broadcast("pvp_win", { winner_id = "", winner_team_id = "HUNTER" })
		return "HUNTER"
	end
	if pl.team_id ~= "HUNTER" then
		return nil
	end
	if pl.lives > 0 then
		pl.lives = 0
		broadcast("pvp_player_lives", { player_id = player_id, lives = 0 })
	end
	pl.hands_left = 0
	if check_team_win() then
		return "RUNNER"
	end
	broadcast_live_targets()
	try_resolve_round()
	return nil
end

-- Teams' on_player_forfeit: if the leaver's whole team roster is now gone, the
-- other team wins immediately. Returns the winning team_id if this call ended
-- the match, else nil.
function PVP.referee_teams_on_forfeit(player_id)
	if not is_host() then
		return nil
	end
	local pl = ref_player(player_id)
	local team = pl.team_id
	if not team then
		return nil
	end
	-- A pause-menu forfeit leaves the forfeiter in the lobby: without this a
	-- team whose players all forfeited one after another never lost (each
	-- forfeit still found the earlier forfeiter as "a teammate remains").
	pl.forfeited = true
	for _, id in ipairs(both_players()) do
		if id ~= player_id and ref_player(id).team_id == team and not ref_player(id).forfeited then
			return nil -- a teammate remains
		end
	end
	local winner = (team == "A") and "B" or "A"
	broadcast("pvp_win", { winner_id = "", winner_team_id = winner })
	return winner
end

-- ── Hand-over ───────────────────────────────────────────────────────────────
-- The referee lives in the host's memory, but the host can crash. The server
-- then makes another player host (transferHostFrom in the Nakama lobby), whose
-- PVP.REF knew nobody: the crashed player came back with no lives, and nothing
-- could end the match. So after every referee entry point the host keeps a copy
-- of PVP.REF in the lobby metadata (CHECKPOINT_KEY). The server holds that
-- metadata for the lobby's whole life, hands it to every player in each
-- snapshot, and keeps it across a server restart, so whoever is made host
-- next finds the referee as the old host last left it and carries on
-- (PVP.referee_take_over, run off HOST_CHANGED in lobby_bridge.lua).
--
-- The host stays the rules engine; the server only stores. Moving the rules
-- themselves into the server (it is mod-agnostic, and the rules are
-- PvP's, with five modes and the PVP.Score scores) is the larger change this
-- leaves open.

local CHECKPOINT_KEY = "_pvp_ref"
PVP.REF_CHECKPOINT_KEY = CHECKPOINT_KEY

-- Ties a checkpoint to the run it was taken in, so a checkpoint left in the
-- metadata by an earlier match in the same lobby is never restored.
local function run_tag()
	local lobby = MPAPI.get_current_lobby()
	local started = lobby and lobby._game and lobby._game.started
	if started and started.run_id then
		return tostring(started.run_id)
	end
	local seed = G.GAME and G.GAME.pseudorandom and G.GAME.pseudorandom.seed
	return seed and ("seed:" .. tostring(seed)) or nil
end

local function score_out(v)
	return PVP.Score.or_zero(v)
end

local function score_in(v)
	return PVP.Score.or_zero(v)
end

-- Booleans as 0/1 and nil-able fields left out: the snapshot crosses JSON.
local function flag(b)
	return b and 1 or 0
end

local function snapshot()
	local players = {}
	for id, pl in pairs(PVP.REF.players) do
		players[id] = {
			score = score_out(pl.score),
			highest = score_out(pl.highest_score),
			hands = pl.hands_left,
			lives = pl.lives,
			skips = pl.skips,
			ante = pl.ante,
			furthest = pl.furthest_blind,
			played = flag(pl.played_this_blind),
			ready = flag(pl.is_ready),
			first = flag(pl.first_ready),
			blocker = flag(pl.lives_blocker),
			team = pl.team_id,
			failed_blind = pl.failed_blind,
			tracked_ready = flag(PVP.REF.ready_tracker and PVP.REF.ready_tracker:is_ready(id)),
		}
	end
	return {
		v = 1,
		tag = run_tag(),
		players = players,
		nemesis_of = PVP.REF.nemesis_of or {},
		used_pairs = PVP.REF.used_pairs or {},
		nemesis_ante = PVP.REF.nemesis_ante_computed_for or 0,
		last_bye = PVP.REF.last_bye_id,
		team_lives = PVP.REF.team_lives or {},
		team_card_target = PVP.REF.team_card_target or {},
		team_card_ante = PVP.REF.team_card_ante_computed_for or 0,
		eliminated = PVP.REF.eliminated or {},
		pending_death = PVP.REF.pending_death,
		pending_deaths = PVP.REF.pending_deaths,
		many_hold = PVP.REF.many_hold,
		team_pending = PVP.REF.team_pending,
		blind_results = PVP.REF.blind_results or {},
	}
end

local function restore(snap)
	PVP.REF.players = {}
	PVP.REF.ready_tracker = MPAPI.ReadyTracker()
	for id, s in pairs(snap.players or {}) do
		PVP.REF.players[id] = {
			id = id,
			score = score_in(s.score),
			highest_score = score_in(s.highest),
			hands_left = tonumber(s.hands) or 4,
			lives = tonumber(s.lives) or (PVP.LOBBY.config.starting_lives or 4),
			skips = tonumber(s.skips) or 0,
			ante = tonumber(s.ante) or 1,
			furthest_blind = tonumber(s.furthest) or 0,
			played_this_blind = s.played == 1,
			is_ready = s.ready == 1,
			first_ready = s.first == 1,
			lives_blocker = s.blocker == 1,
			team_id = s.team,
			failed_blind = s.failed_blind,
		}
		if s.tracked_ready == 1 then
			PVP.REF.ready_tracker:set(id, true)
		end
	end
	PVP.REF.first_ready_at = nil
	PVP.REF.nemesis_of = snap.nemesis_of or {}
	PVP.REF.used_pairs = snap.used_pairs or {}
	PVP.REF.nemesis_ante_computed_for = tonumber(snap.nemesis_ante) or 0
	PVP.REF.last_bye_id = snap.last_bye
	PVP.REF.team_lives = snap.team_lives or {}
	PVP.REF.team_card_target = snap.team_card_target or {}
	PVP.REF.team_card_ante_computed_for = tonumber(snap.team_card_ante) or 0
	PVP.REF.eliminated = snap.eliminated or {}
	PVP.REF.pending_death = type(snap.pending_death) == "table" and snap.pending_death or nil
	PVP.REF.pending_deaths = type(snap.pending_deaths) == "table" and snap.pending_deaths or {}
	PVP.REF.many_hold = snap.many_hold
	PVP.REF.team_pending = type(snap.team_pending) == "table" and snap.team_pending or nil
	PVP.REF.blind_results = snap.blind_results or {}
end

-- No checkpoint to take over (an old host on an older build, or one that
-- crashed before its first write): rebuild what this client saw itself. Lives
-- are the part that decides the match, and every client hears every change to
-- its own and its opponent's (pvp_player_lives). Scores and hands come back as
-- each player plays its next hand.
local function rebuild_from_local(lobby)
	PVP.REF.players = {}
	PVP.REF.ready_tracker = MPAPI.ReadyTracker()
	PVP.REF.eliminated = {}
	PVP.REF.blind_results = {}
	PVP.REF.pending_deaths = {}
	PVP.REF.many_hold = nil
	for id, blind_key in pairs(PVP.GAME.pending_deaths or {}) do
		PVP.PendingDeath.add_pending(PVP.REF.pending_deaths, id, blind_key, {})
		PVP.REF.many_hold = PVP.GAME.result_held and PVP.ManyHold.HELD or PVP.ManyHold.NONE
	end
	PVP.REF.team_pending = nil
	if PVP.GAME.team_pending then
		PVP.REF.team_pending = {
			team_id = PVP.GAME.team_pending.team_id,
			blind_key = PVP.GAME.team_pending.blind_key,
			held = PVP.GAME.result_held and 1 or 0,
		}
	end
	local seen = PVP.GAME.pending_death
	PVP.REF.pending_death = nil
	if seen and seen.blind_key and seen.opponent_id then
		PVP.REF.pending_death = {
			player_id = seen.player_id,
			opponent_id = seen.opponent_id,
			blind_key = seen.blind_key,
			held = PVP.GAME.result_held and 1 or 0,
		}
	end
	local target = PVP.current_target_id()
	for _, p in ipairs(lobby:get_players()) do
		local pl = ref_player(p.id)
		pl.team_id = PVP.LOBBY.roster and PVP.LOBBY.roster[p.id] or nil
		local lives
		if p.id == lobby.player_id then
			lives = PVP.GAME.lives
		elseif PVP._player_lives_cache and PVP._player_lives_cache[p.id] then
			lives = PVP._player_lives_cache[p.id]
		elseif p.id == target and PVP.GAME.enemy then
			lives = PVP.GAME.enemy.lives
		end
		if tonumber(lives) and tonumber(lives) > 0 then
			pl.lives = tonumber(lives)
		end
		pl.ante = (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or pl.ante
	end
	if PVP.LOBBY.config.team_based and PVP.GAME.team_lives then
		for team, lives in pairs(PVP.GAME.team_lives) do
			PVP.REF.team_lives[team] = tonumber(lives)
		end
	end
end

local last_written

-- Writes the referee into the lobby metadata when it changed since the last
-- write. Host-only.
function PVP.referee_checkpoint()
	if not is_host() then
		return
	end
	local lobby = MPAPI.get_current_lobby()
	if not lobby or not next(PVP.REF.players or {}) then
		return
	end
	local snap = snapshot()
	local ok, encoded = pcall(MPAPI.json_encode, snap)
	if not ok then
		sendWarnMessage("[pvp] referee checkpoint not encodable: " .. tostring(encoded), "MULTIPLAYER")
		return
	end
	if encoded == last_written then
		return
	end
	last_written = encoded
	lobby:set_metadata({ [CHECKPOINT_KEY] = snap })
end

-- Run on the player the server has just made host, mid-run. Returns how the
-- referee was rebuilt ("checkpoint" or "local"), or nil when nothing was done.
function PVP.referee_take_over()
	if not is_host() or G.STAGE ~= G.STAGES.RUN then
		return nil
	end
	-- The match is already decided (the old host left from the end screen).
	if PVP.GAME.won or PVP.GAME.eliminated or G.STATE == G.STATES.GAME_OVER then
		return nil
	end
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return nil
	end
	local snap = (lobby:get_metadata() or {})[CHECKPOINT_KEY]
	local source
	if type(snap) == "table" and snap.v == 1 and snap.tag ~= nil and snap.tag == run_tag() then
		restore(snap)
		source = "checkpoint"
	else
		rebuild_from_local(lobby)
		source = "local"
	end
	PVP.ensure_gamemode_instance(lobby)
	-- Blind results this client reported itself may have missed the old host.
	for blind_key, result in pairs((PVP.GAME.own_blind_results or {})[PVP.PendingDeath.SELF] or {}) do
		local beaten = result == PVP.PendingDeath.BlindResult.BEATEN
		PVP.PendingDeath.record(PVP.REF.blind_results, lobby.player_id, blind_key, beaten)
	end
	PVP.GAME.result_held = (PVP.REF.pending_death ~= nil and PVP.REF.pending_death.held == 1)
		or PVP.REF.many_hold == PVP.ManyHold.HELD
		or (PVP.REF.team_pending ~= nil and PVP.REF.team_pending.held == 1)
	sendDebugMessage("[pvp] took over the referee from " .. source, "MULTIPLAYER")
	PVP._ref_takeover = { source = source, at = love.timer and love.timer.getTime() or os.time() }
	-- Everyone's Lives box reads the referee's record from here on.
	for id, pl in pairs(PVP.REF.players) do
		broadcast("pvp_player_lives", { player_id = id, lives = pl.lives })
	end
	if PVP.LOBBY.config.team_based then
		for team_id, lives in pairs(PVP.REF.team_lives or {}) do
			broadcast("pvp_team_lives", { team_id = team_id, lives = lives })
		end
	end
	last_written = nil
	resolve_pending_death()
	resolve_team_pending()
	settle_many_pending()
	PVP.referee_checkpoint()
	return source
end

-- The per-run gamemode instance (forfeit/leave handling) was only ever made on
-- the host that started the match, so a host that took over had none and a
-- forfeit did nothing. Made here from the lobby's queue_mode when missing.
function PVP.ensure_gamemode_instance(lobby)
	lobby = lobby or MPAPI.get_current_lobby()
	if not lobby then
		return nil
	end
	local existing = lobby:get_gamemode_instance()
	if existing then
		return existing
	end
	local queue_mode = (lobby:get_metadata() or {}).queue_mode or PVP._pvp_gamemode
	local gm_def = queue_mode and MPAPI.GameModes[queue_mode]
	if gm_def and gm_def.new_instance then
		lobby:set_gamemode_instance(gm_def:new_instance())
	end
	return lobby:get_gamemode_instance()
end

-- Every entry point that changes the referee checkpoints after it runs.
for _, name in ipairs({
	"referee_reset",
	"referee_on_player_reconnected",
	"referee_on_ready_blind",
	"referee_on_unready_blind",
	"referee_on_play_hand",
	"referee_on_skip",
	"referee_on_set_ante",
	"referee_on_redeem_ante_voucher",
	"referee_on_set_furthest_blind",
	"referee_on_new_round",
	"referee_on_fail_round",
	"referee_on_fail_timer",
	"referee_on_fail_pvp_timer",
	"referee_on_blind_result",
	"referee_pending_death_on_player_gone",
	"referee_n_player_forfeit",
	"referee_manhunt_on_forfeit",
	"referee_teams_on_forfeit",
}) do
	local inner = PVP[name]
	PVP[name] = function(...)
		local result = inner(...)
		PVP.referee_checkpoint()
		return result
	end
end
