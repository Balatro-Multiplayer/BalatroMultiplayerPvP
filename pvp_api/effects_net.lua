-- Opponent effects over the server's match state: Asteroid, Pizza and Let's Go Gambling.
--
-- Sending: each trigger is one "pvp.effect" request { runId, kind } through PVP.OpponentNet. The client names no
-- amount: the server has the table and records the effect against my frozen Nemesis (pvp.nemesis), so a bystander
-- is never hit.
--
-- Receiving: the server's "pvp.effects" lists the effects recorded against me. Each is applied exactly once,
-- only at an apply point (PVP.OpponentNet.can_apply(): never mid-scoring, never during a crash rejoin's
-- catch-up), from the index PVP.GAME.opponent_applied, which is saved with the run and carried across a rejoin
-- (lib/applied_opponent_effects.lua decides; this file gathers and acts). An effect recorded while I was
-- reconnecting is in the state when it comes back, so it applies once then.

PVP.EffectsNet = PVP.EffectsNet or {}
local N = PVP.EffectsNet
local pvp_lobby = PVP.NetBasics.pvp_lobby

local KEY = "pvp.effects"

-- The state value last looked at, and whether effects may still be waiting. A new value (a push, a snapshot,
-- a rejoin's re-read) or a wait for an apply point is looked at again on the next frame.
local seen_value = nil
local pending = false
local reported_value = nil
local listening = false

-- One effect of `kind`, from this player's card.
function N.send_effect(kind)
	PVP.OpponentNet.send_request("pvp.effect", { kind = kind })
end

local APPLY = {
	-- One level per Asteroid, each picked again from the hands as they stand.
	asteroid = function(amount)
		for _ = 1, amount do
			PVP.UI.show_asteroid_hand_level_up()
		end
	end,
	pizza = function(amount)
		PVP.RLOG.record(MPAPI.OPCODE.NET_PIZZA, amount, "action:netPizza,discards:" .. tostring(amount))
		PVP.GAME.pizza_discards = PVP.GAME.pizza_discards + amount
		G.GAME.round_resets.discards = G.GAME.round_resets.discards + amount
		ease_discard(amount)
	end,
	gambling = function(amount)
		local copy = PVP.UTILS.get_phantom_joker("j_mp_lets_go_gambling")
		if copy then copy:juice_up() end
		ease_dollars(amount)
	end,
}

-- Applies the effects not applied yet, in order, once the run is live and the game is at an apply point.
function N.apply_new()
	-- No lobby: the effects wait (pending stays set) until one is attached.
	local lobby = pvp_lobby()
	if not lobby then return end
	local ctx = { can_apply = PVP.OpponentNet.can_apply(), run_id = PVP.current_run_id() }
	local value = MPAPI.get_state(KEY)
	local effects, applied, refused, waiting = PVP.AppliedOpponentEffects.step(
		value,
		PVP.GAME.opponent_applied,
		ctx
	)
	pending = waiting
	-- A refusal is a contract violation of the server's record: logged as an error, once per state value.
	if #refused > 0 and value ~= reported_value then
		reported_value = value
		for _, reason in ipairs(refused) do
			PVP.match_log("info", "[pvp] error: opponent effect not applied: " .. reason)
		end
	end
	PVP.GAME.opponent_applied = applied
	for _, effect in ipairs(effects) do
		APPLY[effect.kind](effect.amount)
	end
end

-- Per frame (pvp_api/frame.lua): looks again at a state that changed, and at effects that waited.
function N.update()
	-- A rejoin or reconnect attaches without necessarily replacing the state's table: look again then.
	if not listening and PVP.OpponentNet then
		listening = true
		PVP.OpponentNet.on_connected(function()
			pending = true
		end)
	end
	local value = MPAPI.get_state(KEY)
	if value ~= seen_value then
		seen_value = value
		pending = true
	end
	if pending then N.apply_new() end
end

-- A push: the state value may have been changed in place, so look again whatever the value's identity.
if MPAPI.on_state then
	MPAPI.on_state(KEY, function()
		pending = true
		reported_value = nil
	end)
end
