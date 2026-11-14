-- Pure rules for the round facts this client sends and applies: whether a hand counts, and how many
-- PvP-timer run-outs of the round still have to take their hand off the client's own count. No game
-- state, requests or UI here: pvp_api/round_net.lua feeds this module and acts on the answer.

PVP.RoundFacts = {}
local RoundFacts = PVP.RoundFacts
local same_run = PVP.StateValue.same_run

-- Whether a hand of this client is a fact of round `my_round_id`: the server still has
-- that round of `run_id` open. `round` is the "pvp.round" state. The game also reports a
-- hand when any blind is selected; outside a PvP round that names no open round.
function RoundFacts.hand_counts(round, run_id, my_round_id)
	if type(round) ~= "table" or run_id == nil or my_round_id == nil then return false end
	if not same_run(round, run_id) or round.phase ~= "playing" then return false end
	return tonumber(round.roundId) == tonumber(my_round_id)
end

-- How many of round `my_round_id`'s PvP-timer run-outs this client has already taken a hand off for.
-- `applied` is { run, round, count } (nil = none yet), kept in G.GAME so a crash rejoin restores it
-- together with the hands it matches. Zero is a real count: none taken yet.
function RoundFacts.applied_count(applied, run_id, my_round_id)
	if applied ~= nil and applied.run == tostring(run_id) and applied.round == tonumber(my_round_id) then
		return applied.count
	end
	return 0
end

-- The furthest blind to report once the player selects `blind` ("Small", "Big" or "Boss") of `ante`,
-- on the encoding of a skip (ante * 10 + the blind index, Small 1, Big 2, Boss 3): the server reads it
-- as the blind start that re-arms the team's life guard. Nil when nothing is to be reported: an
-- unknown blind or ante, or no step past `current` (the furthest blind sent so far, nil = none).
local BLIND_INDEX = { Small = 1, Big = 2, Boss = 3 }
function RoundFacts.selected_furthest(ante, blind, current)
	local index = BLIND_INDEX[blind]
	if index == nil or type(ante) ~= "number" or ante < 1 then return nil end
	local furthest = ante * 10 + index
	if current ~= nil and furthest <= current then return nil end
	return furthest
end

-- The PvP-timer run-outs of the open round that have not taken their hand off yet: the server's
-- count (`players[me].timerLosses`, which it owns) minus the ones already applied. `applied` is
-- { run, round, count } as returned here (nil = none yet); it is never changed.
-- Returns `delta` (hands to take off, 0 when nothing is open, the count is not a number or all
-- are applied) and the record to keep: the same count again changes nothing, so it is safe on
-- every push and on a rejoin.
function RoundFacts.timer_losses_to_apply(round, run_id, my_round_id, me, applied)
	if not RoundFacts.hand_counts(round, run_id, my_round_id) then return 0, applied end
	local entry = type(round.players) == "table" and round.players[me] or nil
	local losses = type(entry) == "table" and entry.timerLosses or nil
	if type(losses) ~= "number" then return 0, applied end
	local already = RoundFacts.applied_count(applied, run_id, my_round_id)
	local delta = math.max(0, losses - already)
	return delta, { run = tostring(run_id), round = tonumber(my_round_id), count = math.max(already, losses) }
end

-- What a crash rejoin into the open round takes from the server's entry of this player (`entry`, the
-- "pvp.round" players[me]): the hands and score it counted. `mine` is { hands_left, score } as the
-- client holds them (`score` is score text). The server's hands left stand, and its score stands when
-- it is higher than mine (a hand logged on the client whose request was lost keeps its score).
-- The server has no "done" field: a player is out of hands when `handsSpent` is true or `handsLeft` is 0.
-- Returns { hands_left, score, run_hands_spent }: `hands_left` is the count to write (nil = write nothing),
-- `score` the server's score text (nil = keep mine), `run_hands_spent` that the client runs its
-- hands-spent effect once (the server counted every hand but has not spent them). When the server has
-- spent the hands (`handsSpent` true) the hands are left alone: RoundEndView applies that fact once.
-- Returns nil and a reason when there is no entry, its handsLeft is not a number or its handsSpent is not
-- a boolean: nothing is guessed, the client keeps what it has.
function RoundFacts.resume_counts(mine, entry)
	if type(entry) ~= "table" then return nil, "no server entry" end
	if type(entry.handsLeft) ~= "number" then return nil, "server handsLeft unknown" end
	if type(entry.handsSpent) ~= "boolean" then return nil, "server handsSpent unknown" end
	local plan = { hands_left = entry.handsLeft, score = nil, run_hands_spent = false }
	if entry.handsSpent then
		plan.hands_left = nil
	elseif entry.handsLeft == 0 and type(mine.hands_left) == "number" and mine.hands_left > 0 then
		plan.hands_left = nil
		plan.run_hands_spent = true
	end
	if PVP.Score.parse(entry.score) ~= nil and PVP.Score.greater(entry.score, mine.score) then
		plan.score = PVP.Score.parse(entry.score)
	end
	return plan
end
