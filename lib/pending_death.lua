-- The blind key of a pending death: the server rules a death pending on one
-- non-PvP blind, and the client names that blind the same way.

PVP.PendingDeath = {}
local PendingDeath = PVP.PendingDeath

-- One non-PvP blind: its ante and its slot ("Small", "Big" or "Boss").
function PendingDeath.blind_key(ante, blind)
	return tostring(ante) .. ":" .. tostring(blind)
end
