-- Pure rules for applying each effect an opponent's card had on this player exactly once.
--
-- The server records every Asteroid, Pizza and Let's Go Gambling trigger against the actor's Nemesis and
-- publishes it to the target in "pvp.effects" (contract: pvp.effects): { runId, me = { incoming =
-- { { from, n, kind, amount } ... } } }, append-only inside a run. `from` is the actor and `n` the effect's
-- position in my incoming list (1, 2, 3 ...), so n names one effect for good. The client saves `applied` with
-- the run: { runId, count = <highest n applied> }. Whatever arrives (a push, a snapshot, the same state again,
-- an older state after a newer one) only the effects past the count give work, and the count never goes back.
-- A different runId starts again from nothing.
--
-- Nothing applies while `can_apply` is false (mid-scoring, a rejoin's catch-up): the mark stays, and the same
-- effects come back on the next call. The amounts are the server's: a record with no whole positive amount, an
-- unknown kind or no actor or number is refused (reported, never guessed at). A refused record that names
-- its actor and number is counted, so it does not hold up the ones behind it.
--
-- No game state here: pvp_api/effects_net.lua gathers the context, calls `step`, and applies what it returns.

PVP.AppliedOpponentEffects = {}
local AppliedOpponentEffects = PVP.AppliedOpponentEffects

local is_table = PVP.StateValue.is_table
local same_run = PVP.StateValue.same_run

-- The kinds a client applies (the server's EFFECT_KINDS that fan to a target).
AppliedOpponentEffects.KINDS = { asteroid = true, pizza = true, gambling = true }

function AppliedOpponentEffects.new_applied(run_id)
	return { runId = run_id, count = 0 }
end

local function whole_positive(value)
	return type(value) == "number" and value == math.floor(value) and value > 0 and value < math.huge
end

-- Why one record cannot be applied, or nil.
local function refusal(record)
	if not is_table(record) then return "a record is not a table" end
	if not AppliedOpponentEffects.KINDS[record.kind] then return "unknown kind " .. tostring(record.kind) end
	if not whole_positive(record.amount) then return record.kind .. " has no whole positive amount" end
	return nil
end

local function has_name(record)
	return is_table(record) and type(record.from) == "string" and record.from ~= "" and whole_positive(record.n)
end

local function in_order(a, b)
	return a.n < b.n
end

-- Decides from the state value, this client's record and the context ctx = { can_apply, run_id }: whether now is an
-- apply point, and the lobby's current run (nil when no run is live).
-- Returns the effects to apply now, in order of n ({ from, n, kind, amount } each), the record to keep, a list of
-- reasons for the records refused, and whether effects are still waiting for an apply point.
function AppliedOpponentEffects.step(value, applied, ctx)
	local run_id, can_apply = ctx.run_id, ctx.can_apply
	if not is_table(value) or value.runId == nil then return {}, applied, {}, false end
	local value_run = tostring(value.runId)
	-- A state of another run than the lobby's current one is stale: it changes nothing.
	if run_id ~= nil and value_run ~= tostring(run_id) then return {}, applied, {}, false end
	local mine = is_table(value.me) and value.me or nil
	local incoming = mine and is_table(mine.incoming) and mine.incoming or nil
	if not incoming then return {}, applied, {}, false end
	if not same_run(applied, value_run) then applied = AppliedOpponentEffects.new_applied(value_run) end

	local fresh, refused = {}, {}
	local nameless = {}
	for _, record in ipairs(incoming) do
		if has_name(record) then
			if record.n > applied.count then fresh[#fresh + 1] = record end
		else
			nameless[#nameless + 1] = "a record names no actor or number"
		end
	end
	if #fresh == 0 then return {}, applied, nameless, false end
	-- No live run, or not an apply point: the effects wait and nothing is marked.
	if run_id == nil or not can_apply then return {}, applied, nameless, true end

	table.sort(fresh, in_order)
	local count = applied.count
	local effects = {}
	for _, record in ipairs(fresh) do
		-- A record listed twice (the same n) applies once.
		if record.n > count then
			count = record.n
			local reason = refusal(record)
			if reason then
				refused[#refused + 1] = record.from .. " #" .. record.n .. ": " .. reason
			else
				effects[#effects + 1] = { from = record.from, n = record.n, kind = record.kind, amount = record.amount }
			end
		end
	end
	for _, reason in ipairs(nameless) do
		refused[#refused + 1] = reason
	end
	return effects, { runId = value_run, count = count }, refused, false
end
