-- Pure rules for the PvP version gate: every player in one game runs the same
-- MultiplayerPvP X.Y.Z. The server enforces it too (it refuses to match or start
-- players on different versions); this module only lets the client say so early.
-- No game state or UI here.

PVP.VersionGate = {}
local Gate = PVP.VersionGate

-- The server's refusal reason for a start across versions (nakama VERSION_MISMATCH).
Gate.SERVER_REASON = "version_mismatch"

local PVP_MOD_ID = "MultiplayerPvP"

-- "1.0.3-beta.1" -> "1.0.3". nil if there is no leading X.Y.Z.
function Gate.prefix(version)
	if type(version) ~= "string" then
		return nil
	end
	return version:match("^v?(%d+%.%d+%.%d+)")
end

-- The X.Y.Z of the PvP entry ("<SMODS id>-<version>") in a mod list, or nil.
function Gate.pvp_prefix(mods)
	for _, entry in ipairs(type(mods) == "table" and mods or {}) do
		if type(entry) == "string" and entry:sub(1, #PVP_MOD_ID + 1) == PVP_MOD_ID .. "-" then
			return Gate.prefix(entry:sub(#PVP_MOD_ID + 2))
		end
	end
	return nil
end

-- { player, our, their } for each other player whose PvP X.Y.Z differs from ours.
-- A player whose list shows no PvP version is not judged here (the server decides).
function Gate.mismatches(our_version, players, own_id)
	local ours = Gate.prefix(our_version)
	local found = {}
	if not ours then
		return found
	end
	for _, player in ipairs(players or {}) do
		if player.id ~= own_id then
			local theirs = Gate.pvp_prefix(player.mods)
			if theirs and theirs ~= ours then
				found[#found + 1] = { player = player, our = ours, their = theirs }
			end
		end
	end
	return found
end

-- True when a start refusal from the server is the version gate.
function Gate.is_server_refusal(err)
	return tostring(err and err.message or err) == Gate.SERVER_REASON
end
