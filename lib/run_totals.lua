-- How many times this run has done each counted action (sells, skips, effects, traps...), kept in
-- G.GAME.pvp_net.totals so every Run save holds them. next_total and count_sent are the only writers.
PVP.run_totals = {}

-- The total after one more under `key`, with nothing written; nil and why when it cannot be counted.
-- pvp_net is G.GAME.pvp_net, whose totals table net.start_run made.
local function after_one_more(pvp_net, key)
	if type(pvp_net) ~= "table" then return nil, "no run to count in" end
	if type(key) ~= "string" or key == "" then return nil, "the key must be text" end
	if type(pvp_net.totals) ~= "table" then return nil, "no totals" end
	return (pvp_net.totals[key] or 0) + 1
end

-- Adds 1 to the total under `key` and returns it; nil and why when it cannot be counted.
function PVP.run_totals.next_total(pvp_net, key)
	local total, why = after_one_more(pvp_net, key)
	if not total then return nil, why end
	pvp_net.totals[key] = total
	return total
end

-- Counts one more under `key` only if `send(total)` accepts it: send gets the would-be total and
-- answers its input number, or nil when the input was not sent. A refused send leaves the total as it was.
function PVP.run_totals.count_sent(pvp_net, key, send)
	local total, why = after_one_more(pvp_net, key)
	if not total then return nil, why end
	local sent, reason = send(total)
	if not sent then return nil, reason end
	pvp_net.totals[key] = total
	return sent
end

return PVP.run_totals
