-- Pure rules for applying the server's round end and pending deaths.
--
-- The server decides each PvP round ("pvp.round".lastResult) and each pending death
-- ("pvp.lives".pending; contract section 4). Every client reads them and calls its own
-- local handlers, each exactly once. `decide` turns the two state values into a plain
-- list of commands plus the new applied marks; pvp_api/round_end_net.lua latches the
-- marks per run and interprets the commands. No game state, requests or UI here.

PVP.RoundEndView = {}
local RoundEndView = PVP.RoundEndView

local is_table = PVP.StateValue.is_table
local same_run = PVP.StateValue.same_run

local function contains(list, id)
	for _, entry in ipairs(is_table(list) and list or {}) do
		if entry == id then return true end
	end
	return false
end

local function copy_set(set)
	local out = {}
	for key, value in pairs(is_table(set) and set or {}) do
		out[key] = value
	end
	return out
end

-- The applied marks of a run with nothing applied yet.
function RoundEndView.fresh()
	return { rounds = {}, pending = {}, mine = nil, spent = nil }
end

-- The key a pending entry is applied once under.
function RoundEndView.pending_key(entry)
	return tostring(entry.playerId) .. "|" .. tostring(entry.blindKey)
end

-- The opponent a pending death waits on: the one id of a one-entry wait list, and only in a game
-- that started with exactly 2 players (`started_count` nil = unknown: the list length decides).
function RoundEndView.opponent_of(waits_on, started_count)
	if not is_table(waits_on) or #waits_on ~= 1 then return nil end
	if started_count ~= nil and started_count ~= 2 then return nil end
	return waits_on[1]
end

-- The "pvp.teams" team map { [player_id] = team } of run `run_id` (Manhunt, Teams), or nil.
function RoundEndView.team_map(teams_value, run_id)
	if not same_run(teams_value, run_id) then return nil end
	return teams_value.teams
end

-- The team a pending entry belongs to: `playerId` is the one who died, and the whole team of
-- that player is pending. nil when no map names a team for that player (every entry is then one
-- player's).
local function team_of(entry, teams)
	return teams[entry.playerId]
end

-- Whether a pending entry is mine: I am the player, or on the team the entry belongs to.
local function entry_is_mine(entry, me, teams)
	local team = team_of(entry, teams)
	return entry.playerId == me or (team ~= nil and teams[me] == team)
end

-- What to apply now: `commands, applied`. One input table:
--   round_value / lives_value: the "pvp.round" and "pvp.lives" state values
--   me:         this player's id
--   run_id:     the run the lobby says is current; a value of another run applies nothing
--   applied:    the marks returned by the last call (nil = none yet). Marks of another run than
--               `run_id` are dropped: the round numbers and pending entries of an old run mean
--               nothing in this one. The returned marks carry `run_id`.
--   result_set: a "pvp.result" is set, so the pending screen is ended by the result, not here.
--   eliminated: this client was told it is out: the rounds the others play on are not its, so
--               no end_pvp (the round is still marked).
--   current:    { round_id, in_pvp_blind }: the round this client started (PVP.GAME.round_id) and
--               whether it is in the PvP blind now. A round's end runs only for the round the
--               player is in (see below); with no `current` nothing runs and the round is only
--               marked.
--   started_count: how many players the run started with ("pvp.rules".startedCount). A pending
--               death names an opponent only when it is 2 (the duel's wait); with 3 or more
--               started, a wait list that shrank to one is still the many-player branch. Without
--               it (nil) the length of the wait list decides.
--   teams:      the team map of RoundEndView.team_map (Manhunt, Teams). A pending entry whose
--               player it names a team for is that team's: the command carries team_id, and the
--               entry is mine when I am the player or on that team. Without it (nil) every entry
--               is one player's.
--   hands_left: this client's own hands left now (G.GAME.current_round.hands_left). The server's
--               "hands spent" (`players[me].handsSpent`) is applied only while it is above 0.
-- Commands, in order:
--   { kind = "hands_spent", roundId = n }  (at most once per round, before an end_pvp)
--   { kind = "end_pvp", lost = bool, roundId = n }
--   { kind = "death_pending", player_id, opponent_id, blind_key, team_id }
--   { kind = "end_pending_death" }
-- `applied` is never changed; the returned marks are a new table.
function RoundEndView.decide(input)
	local marks = input.applied
	if marks == nil or marks.run_id ~= input.run_id then marks = RoundEndView.fresh() end
	local out = {
		run_id = input.run_id,
		rounds = copy_set(marks.rounds),
		pending = copy_set(marks.pending),
		mine = marks.mine,
		spent = marks.spent,
	}
	local commands = {}
	if input.run_id == nil then return commands, out end
	local run_id = tostring(input.run_id)
	local me = input.me
	local started_count = tonumber(input.started_count)

	local round_value = input.round_value
	if same_run(round_value, run_id) then
		-- The server spent my hands (the backstop) while the round is still open: the loss is applied
		-- once per round, before any result, so the jokers see the hands that were left.
		local current = input.current
		local entry = is_table(round_value.players) and round_value.players[me] or nil
		local round_id = tonumber(round_value.roundId)
		if
			is_table(entry)
			and entry.handsSpent == true
			and round_id ~= nil
			and out.spent ~= round_id
			and not input.eliminated
			and current
			and current.in_pvp_blind
			and current.round_id == round_id
			and type(input.hands_left) == "number"
			and input.hands_left > 0
		then
			out.spent = round_id
			commands[#commands + 1] = { kind = "hands_spent", roundId = round_id }
		end

		local last = round_value.lastResult
		local id = is_table(last) and tonumber(last.roundId) or nil
		if id ~= nil and not out.rounds[id] then
			out.rounds[id] = true
			-- The round ends here only for the round this client is in: its id is `id` (one round
			-- number on both sides, set when the blind starts or a rejoin adopts lastStart) and it
			-- is in the PvP blind. Otherwise the player is already past round `id` (in the shop, or
			-- in a later blind after a rejoin that replays the log): the round is only marked, so
			-- a late end_pvp cannot leave a flag that ends the next PvP blind after one hand.
			local current = input.current
			if not input.eliminated and current and current.in_pvp_blind and current.round_id == id then
				commands[#commands + 1] = { kind = "end_pvp", lost = contains(last.losers, me), roundId = id }
			end
		end
	end

	local lives_value = input.lives_value
	if same_run(lives_value, run_id) then
		local mine = nil
		local teams = is_table(input.teams) and input.teams or {}
		for _, entry in ipairs(is_table(lives_value.pending) and lives_value.pending or {}) do
			local key = RoundEndView.pending_key(entry)
			if entry_is_mine(entry, me, teams) then mine = key end
			if not out.pending[key] then
				out.pending[key] = true
				commands[#commands + 1] = {
					kind = "death_pending",
					player_id = entry.playerId,
					-- Only a 2-player game's wait names an opponent; otherwise it is the N>2 branch of the
					-- handler (opponent_id nil). team_id is set when a team map names the player's team.
					opponent_id = RoundEndView.opponent_of(entry.waitsOn, started_count),
					blind_key = entry.blindKey,
					team_id = team_of(entry, teams),
				}
			end
		end
		if mine ~= nil then
			out.mine = mine
		elseif out.mine ~= nil then
			out.mine = nil
			if not input.result_set then commands[#commands + 1] = { kind = "end_pending_death" } end
		end
	end

	return commands, out
end
