-- What Taxes and Penny Pincher read of the opponent's run (sells per ante, dollars spent per shop,
-- from the view; run_screen.lua writes them). Pure: plain tables in, plain numbers out, no game globals.
PVP.OPPONENT_RECORD = {}

-- Taxes: sells this ante, plus every earlier ante until PvP has been reached. No sells known, no gain.
function PVP.OPPONENT_RECORD.taxes_mult_gain(sells_per_ante, ante, pvp_start_ante, mult_gain)
	if not sells_per_ante then return 0 end
	local sells = sells_per_ante[ante] or 0
	if ante <= pvp_start_ante then
		for i = 1, ante - 1 do
			sells = sells + (sells_per_ante[i] or 0)
		end
	end
	return sells * mult_gain
end

-- Penny Pincher: dollars for the shop at `index`, or 0 if there is none.
function PVP.OPPONENT_RECORD.pincher_payout(spent_in_shop, index, divisor, dollars)
	local spent = spent_in_shop and spent_in_shop[index]
	if not spent then
		return 0
	end
	return math.floor(spent / divisor) * (dollars or 1)
end
