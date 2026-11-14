-- Pure rules for applying each life change of this player exactly once.
--
-- The server keeps every player's lives events in the "pvp.lives" match state, append-only
-- inside a run (contract: pvp.lives). The client saves `applied` with the run:
-- { runId, events = <count per player id> }, the number of that player's events it has
-- already turned into effects. Whatever arrives (a push, a snapshot, the same state again, an
-- older state after a newer one) only the events past the count give effects, and the count
-- never goes back. A different runId starts again from 0.
--
-- No game state here: pvp_api/lives_net.lua gathers the context, calls `step`, and applies
-- the effects it returns.

PVP.AppliedEffects = {}
local AppliedEffects = PVP.AppliedEffects

local is_table = PVP.StateValue.is_table
local same_run = PVP.StateValue.same_run

function AppliedEffects.new_applied(run_id)
	return { runId = run_id, events = {} }
end

-- The key of the blind being played now, as the server writes it on a loss: "<ante>:<Small|Big|Boss>"
-- for a normal blind, "pvp:<roundId>" for the PvP blind.
function AppliedEffects.blind_key(is_pvp, round_id, ante, blind)
	if is_pvp then return "pvp:" .. tostring(round_id) end
	return PVP.PendingDeath.blind_key(ante, blind)
end

-- The effects of one event. `before` is the lives this player had before it. They match the
-- old playerInfo handler: the comeback gold, the lives, and dollars zeroed, but only for a
-- loss in the blind being played now (a catch-up in a later blind does not zero it). The gold
-- is for a lost life only: a gained one (the Manhunt voucher) pays nothing.
local function effects_of(event, delta, before, ctx)
	local effects = {}
	if ctx.gold_on_life_loss and before ~= 0 and delta < 0 then effects[#effects + 1] = { type = "comebackBonus" } end
	effects[#effects + 1] = { type = "easeLives", delta = delta, lives = before + delta }
	if delta < 0 and ctx.no_gold_on_round_loss and event.key ~= nil and event.key == ctx.blind_key then
		effects[#effects + 1] = { type = "zeroBlindDollars" }
	end
	return effects
end

-- Decides from the state value, this client's record and the context.
-- ctx = { my_id, run_id (the lobby's current run, or nil), gold_on_life_loss,
-- no_gold_on_round_loss, blind_key }.
-- Returns the effects to apply now, in order, and the record to keep. A value of another run
-- than the lobby's current one is stale and changes nothing; so does any value while the lobby's run is unknown. A lives total or delta that is not a
-- number applies nothing and keeps the record; the third value is then the reason, for the caller to log.
function AppliedEffects.step(value, applied, ctx)
	if not is_table(value) or value.runId == nil then return {}, applied end
	local run_id = tostring(value.runId)
	-- No known lobby run is not a wildcard: with it unset, a state of any run would reset the record and
	-- apply every event of that run again.
	if ctx.run_id == nil or run_id ~= tostring(ctx.run_id) then return {}, applied end
	if not same_run(applied, run_id) then applied = AppliedEffects.new_applied(run_id) end
	local player = is_table(value.players) and value.players[ctx.my_id] or nil
	local events = is_table(player) and is_table(player.events) and player.events or {}
	local done = tonumber(applied.events[ctx.my_id]) or 0
	local count = #events
	if count <= done then return {}, applied end
	-- Lives before each event come from the server's total, not from this client's own counter,
	-- so a catch-up of many events reads the same as the events arriving one by one.
	-- A lives total or a delta that is not a number is unknown: nothing is applied and the count stays.
	local before = tonumber(player.lives)
	if before == nil then return {}, applied, "the lives total is not a number" end
	local deltas = {}
	for i = done + 1, count do
		deltas[i] = tonumber(events[i].delta)
		if deltas[i] == nil then return {}, applied, "an event delta is not a number" end
		before = before - deltas[i]
	end
	local effects = {}
	for i = done + 1, count do
		for _, effect in ipairs(effects_of(events[i], deltas[i], before, ctx)) do
			effects[#effects + 1] = effect
		end
		before = before + deltas[i]
	end
	local counts = {}
	for id, n in pairs(applied.events) do
		counts[id] = n
	end
	counts[ctx.my_id] = count
	return effects, { runId = run_id, events = counts }
end
