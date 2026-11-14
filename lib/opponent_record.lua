-- Readers of what the server recorded about the opponent: their sells (Taxes) and their blind slots
-- (Penny Pincher), and who my Nemesis was in an ante. Pure: plain tables in, plain tables out, no
-- game globals. Nothing is stored here: the server's "pvp.opponent" and "pvp.nemesis" states are the
-- record, and an unknown fact stays unknown (nil), never a 0.
PVP.OPPONENT_RECORD = {}
local R = PVP.OPPONENT_RECORD

-- The most a shop spend may be (the server refuses a larger one).
R.MAX_SPEND = 1e6

local function same_run(value, run_id)
	return type(value) == "table" and value.runId ~= nil and run_id ~= nil and tostring(value.runId) == tostring(run_id)
end

-- JSON object keys arrive as strings, so an ante is read under either spelling.
function R.by_ante(map, ante)
	if type(map) ~= "table" or ante == nil then return nil end
	local value = map[ante]
	if value ~= nil then return value end
	return map[tostring(ante)]
end

-- Whether a shop spend is one the server can take: a whole number from 0 up to MAX_SPEND (so never nan or inf).
function R.valid_spend(spent)
	return type(spent) == "number" and spent == spent and spent >= 0 and spent <= R.MAX_SPEND
		and spent == math.floor(spent)
end

-- The ante the server says player `id` is at ("pvp.round" players[id].ante), nil while unknown.
function R.player_ante(round, run_id, id)
	if not same_run(round, run_id) or type(round.players) ~= "table" then return nil end
	local entry = round.players[id]
	local ante = type(entry) == "table" and entry.ante or nil
	return type(ante) == "number" and ante or nil
end

-- My Nemesis row for `ante` ("pvp.nemesis"): { each = { ids }, one = id or nil }. nil is unknown (the
-- server has not frozen that ante yet); a row with no `one` is known: nobody was my Nemesis then.
function R.nemesis_row(nemesis, run_id, ante)
	if not same_run(nemesis, run_id) or type(nemesis.byAnte) ~= "table" then return nil end
	local row = R.by_ante(nemesis.byAnte, ante)
	return type(row) == "table" and row or nil
end

-- One player's record in "pvp.opponent": { sells, slots, closed }, nil while unknown.
function R.player(opponent, run_id, id)
	if not same_run(opponent, run_id) or type(opponent.players) ~= "table" or id == nil then return nil end
	local record = opponent.players[id]
	return type(record) == "table" and record or nil
end

-- Slot `k` of a player's record ({ ante, spent } | { ante, skipped } | { ante, refused }), nil while unrecorded.
function R.slot(opponent, run_id, id, k)
	local record = R.player(opponent, run_id, id)
	local slots = record and record.slots
	if type(slots) ~= "table" or type(k) ~= "number" then return nil end
	return type(slots[k]) == "table" and slots[k] or nil
end

-- Taxes: sells this ante, plus every earlier ante until PvP has been reached.
function R.taxes_mult_gain(sells_by_ante, ante, pvp_start_round, mult_gain)
	-- The sells map is sparse: an ante with no entry is an ante nothing was sold in, a recorded 0.
	local sells = R.by_ante(sells_by_ante, ante) or 0
	if ante <= pvp_start_round then
		for i = 1, ante - 1 do
			-- Same sparse map: no entry for an earlier ante means nothing sold in it.
			sells = sells + (R.by_ante(sells_by_ante, i) or 0)
		end
	end
	return sells * mult_gain
end

R.DOLLARS = "dollars"
R.NONE = "none"
R.PENDING = "pending"

-- Penny Pincher: what the shop of slot `s` of my Nemesis pays. `row` is my Nemesis row for the ante of my
-- own slot `s`, `target` that Nemesis' record in "pvp.opponent". Returns { status, dollars }:
--   dollars  the slot is a spend: floor(spent / divisor) * dollars
--   none     $0 by a written rule: no slot yet (s < 1), no opponent that ante, a skipped or refused
--            slot, or a player who left
--   pending  the fact is not known yet; the payout waits and is never taken as $0
function R.pincher_payout(row, target, s, divisor, dollars)
	if type(s) ~= "number" or s < 1 then return { status = R.NONE, reason = "no slot" } end
	if row == nil then return { status = R.PENDING } end
	if row.one == nil then return { status = R.NONE, reason = "no opponent" } end
	if target == nil then return { status = R.PENDING } end
	local slot = type(target.slots) == "table" and target.slots[s] or nil
	if slot == nil then
		if target.closed == true then return { status = R.NONE, reason = "left" } end
		return { status = R.PENDING }
	end
	if slot.skipped == true or slot.refused ~= nil then return { status = R.NONE, reason = "no shop" } end
	if not R.valid_spend(slot.spent) then return { status = R.NONE, reason = "bad slot" } end
	return { status = R.DOLLARS, dollars = math.floor(slot.spent / divisor) * dollars }
end
