-- Pure rules for paying the owner's reward of each fired trap exactly once.
--
-- The server keeps every trap in the "pvp.traps" match state, append-only inside a run (contract:
-- pvp.traps): { runId, trapSeq, traps = [{ id, key, owner, holder, state }] } where a trap's state is
-- "live", "lost" or { fired = data }. The owner saves `trap_rewards_applied` with the run:
-- { runId, ids = { [tostring(id)] = true } }, the traps whose reward was already looked at. Traps fire in
-- any order, so the record is the set of ids, not a count. Whatever arrives (a push, a snapshot, the
-- same state again, an older state after a newer one) only a fired trap of mine not in the set gives a
-- reward, and an id never leaves the set. A different runId starts again with an empty set.
--
-- The id joins the set when the reward is handed out, whether or not the owner's own check of the data
-- then pays it (a failed membership check pays nothing and the trap is not looked at again).
--
-- No game state here: pvp_api/traps_net.lua gathers the context, calls `step` and pays the rewards.

PVP.AppliedTrapRewards = {}
local AppliedTrapRewards = PVP.AppliedTrapRewards

local is_table = PVP.StateValue.is_table
local same_run = PVP.StateValue.same_run

function AppliedTrapRewards.new_applied(run_id)
	return { runId = run_id, ids = {} }
end

-- Decides from the state value, this client's record and the context.
-- ctx = { my_id, run_id (the lobby's current run, or nil), can_apply }.
-- Returns the rewards to pay now ({ id, key, data }, in the server's order) and the record to keep. A value
-- of another run than the lobby's current one is stale and changes nothing. While `can_apply` is false
-- nothing is handed out and nothing is recorded. A fired trap of mine with no numeric id is left alone and
-- counted in the third value, for the caller to log.
function AppliedTrapRewards.step(value, applied, ctx)
	if not is_table(value) or value.runId == nil or not is_table(value.traps) then return {}, applied end
	local run_id = tostring(value.runId)
	if ctx.run_id ~= nil and run_id ~= tostring(ctx.run_id) then return {}, applied end
	if not ctx.can_apply then return {}, applied end
	if not same_run(applied, run_id) then applied = AppliedTrapRewards.new_applied(run_id) end
	local rewards, malformed = {}, 0
	local ids = applied.ids
	for _, trap in ipairs(value.traps) do
		if is_table(trap) and trap.owner == ctx.my_id and is_table(trap.state) and trap.state.fired ~= nil then
			if type(trap.id) ~= "number" then
				malformed = malformed + 1
			elseif not ids[tostring(trap.id)] then
				if ids == applied.ids then
					-- Copied once, so the record the caller holds is never changed in place.
					ids = {}
					for id in pairs(applied.ids) do
						ids[id] = true
					end
				end
				ids[tostring(trap.id)] = true
				rewards[#rewards + 1] = { id = trap.id, key = trap.key, data = trap.state.fired }
			end
		end
	end
	if #rewards == 0 then return {}, applied, malformed > 0 and malformed or nil end
	return rewards, { runId = run_id, ids = ids }, malformed > 0 and malformed or nil
end
