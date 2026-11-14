-- Three plain-data checks every view and net makes on a match-state value. Pure: no game, no engine.
-- Loads first (the leading underscore), so a view can alias these at the top of its file.

PVP.StateValue = {}
local StateValue = PVP.StateValue

function StateValue.is_table(value)
	return type(value) == "table"
end

-- Whether a match-state value is the one of run `run_id`. Run ids arrive as a string or a
-- number, so both sides are compared as strings. A value with no run, or no run asked for, is
-- of no run.
function StateValue.same_run(value, run_id)
	return type(value) == "table" and value.runId ~= nil and run_id ~= nil and tostring(value.runId) == tostring(run_id)
end

-- Whether a match-state value is positively of another run than `run_id`: both are known and they
-- differ. A value with no run, or no run asked for, is not (the lenient twin of same_run).
function StateValue.of_other_run(value, run_id)
	return type(value) == "table" and value.runId ~= nil and run_id ~= nil and tostring(value.runId) ~= tostring(run_id)
end

-- Whether a match-state value names a run that is not known to be `run_id`: the value has a run and
-- either `run_id` is unknown (nil) or the two differ. Unknown is a value, never a wildcard, so a
-- caller that applies something from the state uses this, not of_other_run. An idle value (no run)
-- is not unmatched.
function StateValue.unmatched_run(value, run_id)
	return type(value) == "table" and value.runId ~= nil and (run_id == nil or tostring(value.runId) ~= tostring(run_id))
end
