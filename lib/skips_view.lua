-- Pure view of the server's "pvp.skips" match state (contract: pvp.skips).
--
-- The server owns every player's skip count and Ante bank. `skips` is null (unknown) until that
-- player's first skip of the run, never 0. pvp_api/skips_net.lua gathers the inputs and acts on
-- what this module answers.

PVP.SkipsView = {}
local SkipsView = PVP.SkipsView

local is_table = PVP.StateValue.is_table
local of_other_run = PVP.StateValue.of_other_run

-- Whole non-negative number or nil: anything else the server might send is not a fact.
local function whole(n)
	if type(n) ~= "number" or n < 0 or n % 1 ~= 0 then return nil end
	return n
end

-- The players of the state value as { [id] = { skips = integer|nil, bank_ms = integer|nil } }, or
-- nil when there is nothing to show: no value, or a value of another run than `current_run_id`.
function SkipsView.players(value, current_run_id)
	if not is_table(value) or not is_table(value.players) then return nil end
	if of_other_run(value, current_run_id) then return nil end
	local out = {}
	for id, player in pairs(value.players) do
		if is_table(player) then out[id] = { skips = whole(player.skips), bank_ms = whole(player.anteBankMs) } end
	end
	return out
end

-- What is remembered of a player between states: the skip total, or `false` for "known to be
-- unknown" (the server listed the player with null skips). nil means never seen.
function SkipsView.remember(player)
	if player.skips == nil then return false end
	return player.skips
end

-- How many skips the player made since `remembered` (SkipsView.remember of the state before).
-- Never seen (nil) is a baseline, not a rise: a snapshot after a rejoin carries the whole run.
function SkipsView.rise(remembered, player)
	if remembered == nil or player.skips == nil then return 0 end
	return math.max(player.skips - (remembered or 0), 0)
end
