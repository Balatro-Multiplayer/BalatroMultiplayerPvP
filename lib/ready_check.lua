-- Pure rules for the ready check that gates the start of a PvP blind.
--
-- The referee remembers who pressed Ready, but that memory can be stale: a Ready
-- that reaches the host after the blind it belonged to already started stays set,
-- and the next time the opponent readies the host would start the blind for a
-- player who is still in the previous blind. So when everyone looks ready the host
-- asks each of them, under a fresh nonce, whether they are ready right now, and
-- starts only once all have said yes. No game state, broadcasts or timers here:
-- the referee (pvp_api/referee.lua) feeds this module and acts on the answer.

PVP.ReadyCheck = {
	Outcome = { PENDING = "pending", CONFIRMED = "confirmed", REFUSED = "refused" },
}
local RC = PVP.ReadyCheck

-- A check of `ids` under `nonce`. `trigger` is the player whose Ready opened it.
function RC.new(nonce, ids, trigger)
	return { nonce = nonce, ids = ids, trigger = trigger, answers = {} }
end

local function is_asked(check, id)
	for _, asked in ipairs(check.ids) do
		if asked == id then
			return true
		end
	end
	return false
end

-- Where the check stands: REFUSED (with the first refusing id) as soon as anyone
-- says no, CONFIRMED once every asked player said yes, else PENDING.
function RC.status(check)
	local all_yes = true
	for _, id in ipairs(check.ids) do
		local answer = check.answers[id]
		if answer == false then
			return RC.Outcome.REFUSED, id
		end
		if answer ~= true then
			all_yes = false
		end
	end
	return all_yes and RC.Outcome.CONFIRMED or RC.Outcome.PENDING
end

-- Records one answer and returns the new status. An answer under another nonce, or
-- from a player who was not asked, changes nothing.
function RC.answer(check, nonce, id, ready)
	if check.nonce == nonce and is_asked(check, id) then
		check.answers[id] = ready and true or false
	end
	return RC.status(check)
end

-- The check ran out of time: players who never answered are clients that do not know
-- the check (older versions), so they count as ready, as they did before checks
-- existed. Only an explicit no refuses.
function RC.on_timeout(check)
	local outcome, refuser = RC.status(check)
	if outcome == RC.Outcome.REFUSED then
		return outcome, refuser
	end
	return RC.Outcome.CONFIRMED
end
