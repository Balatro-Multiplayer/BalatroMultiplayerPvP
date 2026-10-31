-- What the opponent did in their shop, recorded once and read by Taxes and
-- Penny Pincher. Pure: plain tables in, plain tables out, no game globals.
-- The recording used to sit inside the jokers' calculate, so it depended on
-- holding a copy (and ran once per copy, per Blueprint, and never when debuffed).
PVP.OPPONENT_RECORD = {}
PVP.OPPONENT_RECORD.MAX_SPEND = 1e9

local function copy_list(t)
	local out = {}
	for k, v in pairs(t or {}) do
		out[k] = v
	end
	return out
end

-- `record` is { sells, sells_per_ante, spent_in_shop }. Returns a new record
-- with the event applied; the input is left alone. Events from anyone but the
-- current target, or while byed, change nothing.
function PVP.OPPONENT_RECORD.apply(record, context, ante, target_id, byed)
	local out = {
		sells = (record and record.sells) or 0,
		sells_per_ante = copy_list(record and record.sells_per_ante),
		spent_in_shop = copy_list(record and record.spent_in_shop),
	}
	if byed or not context then
		return out
	end
	if target_id and context.from ~= target_id then
		return out
	end
	if context.opponent_selling_card then
		out.sells = out.sells + 1
		out.sells_per_ante[ante] = (out.sells_per_ante[ante] or 0) + 1
	end
	local spent = tonumber(context.opponent_spent_in_shop)
	if context.opponent_spent_in_shop ~= nil and spent then
		-- The amount comes from a peer: only a finite, non-negative number counts,
		-- capped at a sane maximum. Anything else is recorded as 0 so the shop
		-- index stays aligned.
		if spent ~= spent or spent < 0 or spent == math.huge then
			spent = 0
		end
		out.spent_in_shop[#out.spent_in_shop + 1] = math.min(spent, PVP.OPPONENT_RECORD.MAX_SPEND)
	end
	return out
end

-- Taxes: sells this ante, plus every earlier ante until PvP has been reached.
function PVP.OPPONENT_RECORD.taxes_mult_gain(sells_per_ante, ante, pvp_start_round, mult_gain)
	local sells = sells_per_ante[ante] or 0
	if ante <= pvp_start_round then
		for i = 1, ante - 1 do
			sells = sells + (sells_per_ante[i] or 0)
		end
	end
	return sells * mult_gain
end

-- Penny Pincher: dollars for the shop at `index`, or 0 if there is none.
function PVP.OPPONENT_RECORD.pincher_payout(spent_in_shop, index, divisor, dollars)
	local spent = spent_in_shop[index]
	if not spent then
		return 0
	end
	return math.floor(spent / divisor) * (dollars or 1)
end
