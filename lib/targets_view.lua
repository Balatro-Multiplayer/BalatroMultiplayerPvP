-- Pure view of the server's "pvp.targets" match state (contract: pvp.targets).
--
-- The server says who each player faces: `opponents` maps a player id to that player's
-- opponent id, or to null when the player has none (a bye). Nothing is stored on the client:
-- every read derives the answer from the state, so a rejoin, a reconnect and a new run have
-- nothing to wipe or restore. pvp_api/targets_net.lua gathers the inputs and acts on the answer.

PVP.TargetsView = {}
local TargetsView = PVP.TargetsView

local same_run = PVP.StateValue.same_run

-- known, opponent_id for one player.
--   known: the state is of the lobby's current run (`run_id`) and pairs at least one player, so
--     its answer counts, even when the answer is "no opponent". False for no value, a value of
--     another run, no run yet, or a run the server has paired nobody in (an empty map means
--     "no pairing", not "everyone has a bye").
--   opponent_id: the player's opponent, or nil for none. A JSON null reaches Lua as a missing
--     key (MPAPI's decoder drops it), and an empty or non-string entry is treated the same.
function TargetsView.opponent(value, run_id, player_id)
	if not same_run(value, run_id) then return false, nil end
	if type(value.opponents) ~= "table" or next(value.opponents) == nil then return false, nil end
	local opponent = value.opponents[player_id]
	if type(opponent) ~= "string" or opponent == "" then return true, nil end
	return true, opponent
end

-- known, safe for one player (Royale: a safe player is in the surviving half).
--   known: the state is of the current run and has a boolean entry for the player. `safe` is
--     `{}` outside Royale, so every other mode, and a player the server has not ranked, is
--     not known.
--   safe: that entry; false when not known.
function TargetsView.safe(value, run_id, player_id)
	if not same_run(value, run_id) or type(value.safe) ~= "table" then return false, false end
	local safe = value.safe[player_id]
	if type(safe) ~= "boolean" then return false, false end
	return true, safe
end

-- The ante the state's Nemesis pairing was made for, or nil (outside Nemesis, no pairing yet,
-- another run). A JSON null reaches Lua as a missing key.
function TargetsView.pairing_ante(value, run_id)
	if not same_run(value, run_id) or type(value.pairingAnte) ~= "number" then return nil end
	return value.pairingAnte
end
