-- Lockstep clock + chaos timeout table (pure logic, no G / love dependencies).
--
-- Players move through blind select / round / shop in lockstep. Each player has
-- a time BANK (fischer-style: +increment on phase entry, capped). The bank is a
-- backstop, not a pace: when a decision runs out of time the game doesn't punish,
-- it rolls on the TIMEOUTS table and chaos makes the decision instead.
--
-- The game-side adapter (layers/lockstep_clock.lua) maps G.STATE onto phases,
-- feeds update(dt, can_tick), renders the telegraph and executes timeout keys.
--
-- State diagram (phases; [x] = pushed sub-phase, resolves back to its parent):
--
--             +--------------------------------------------------------+
--             v                                                        |
--   BLIND_SELECT --select--> ROUND --win--> CASH_OUT --cash out--> SHOP -+
--     |   ^                  |  ^ (each hand/discard = new TURN)       |  ^
--     |   |                  |  +--------+                             |  |
--     v   |                  v                                         v  |
--    [PACK] (skip-tag)    GAME_OVER / pvp loss -> (clock stopped)     [PACK]
--
--   Inside every phase/turn:
--
--     DECIDING --ready()--> WAITING --barrier opens / next phase--> (next)
--        |   ^                (clock frozen, bank kept)
--        |   +-- others_ready(): COLLAPSE (remaining = min(remaining, window))
--        |
--        +-- remaining <= warn_at --> TELEGRAPH (intensity 0 -> 1)
--        |
--        +-- remaining <= 0 -------> TIMEOUT (roll TIMEOUTS[phase], fire once,
--                                     re-arm after retry_after if the game state
--                                     didn't move, give up after max_retries)
--
--   Clock ticks only while the adapter says the player can act (no scoring
--   animations, no locked controller), so nobody loses time to juice.

local Lockstep = {}

Lockstep.PHASE = {
	BLIND_SELECT = "blind_select",
	ROUND = "round",
	CASH_OUT = "cash_out",
	SHOP = "shop",
	PACK = "pack",
}

Lockstep.CONFIG = {
	bank_start = 90,
	bank_cap = 150,
	-- floor on every decision so the telegraph always plays out and a bank-dry
	-- player still gets to act (just fast)
	grace = 4,
	warn_at = 5,
	-- first collapse when everyone else is ready; later turns in the same phase
	-- (more hands in a round) get the shorter followup window
	collapse_window = 15,
	collapse_followup = 8,
	retry_after = 3,
	max_retries = 3,
	phases = {
		-- increment: added to bank on phase entry
		-- turn_increment: added on each new turn after the first (round: per hand)
		-- phase_cap / turn_cap: max seconds spendable in the phase / in one turn
		blind_select = { increment = 20, phase_cap = 15, turn_cap = 15 },
		round = { increment = 20, turn_increment = 5, phase_cap = 150, turn_cap = 30 },
		cash_out = { increment = 0, phase_cap = 10, turn_cap = 10 },
		shop = { increment = 20, phase_cap = 75, turn_cap = 75 },
		-- packs ride on their parent's phase budget; own turn cap only
		pack = { increment = 0, turn_cap = 25, inherit_phase = true },
	},
}

-- ---------------------------------------------------------------------------
-- Timeout table
-- ---------------------------------------------------------------------------
-- Each entry: key (adapter executes it), weight, optional allowed(ctx),
-- optional force(ctx) -- a forced entry wins outright (first forced wins).
-- ctx is built by the adapter: plain numbers/bools, no game objects.
--
-- Design rules:
--  * the random result should be slightly WORSE than an average decision, so
--    idling is never the strategy
--  * chaos can sting but never single-handedly ends a run (mercy rule)
--  * blind select always takes the blind -- an accidental skip is brutal
Lockstep.TIMEOUTS = {
	blind_select = {
		{ key = "take_blind", weight = 1 },
	},
	round = {
		-- random 1-5 cards from the WHOLE hand, not your current selection
		{ key = "random_hand", weight = 3, allowed = function(ctx) return ctx.hands_left > 0 end },
		{ key = "random_discard", weight = 1, allowed = function(ctx) return ctx.discards_left > 0 end },
		-- mercy: last hand + discards left -> discard instead of a coin-flip loss
		{
			key = "random_discard",
			weight = 0,
			force = function(ctx) return ctx.hands_left <= 1 and ctx.discards_left > 0 end,
		},
	},
	cash_out = {
		{ key = "cash_out", weight = 1 },
	},
	shop = {
		{ key = "leave_shop", weight = 3 },
		-- buys one random affordable joker/consumable/voucher, then leaves
		{ key = "impulse_buy", weight = 1, allowed = function(ctx) return ctx.affordable > 0 end },
	},
	pack = {
		{ key = "random_pick", weight = 1, allowed = function(ctx) return ctx.pickable > 0 end },
		{ key = "skip_pack", weight = 0, force = function(ctx) return ctx.pickable <= 0 end },
	},
}

-- rng(n) -> integer in [1, n]. Adapter passes a seeded one; tests pass a stub.
function Lockstep.pick_timeout(phase, ctx, rng, table_override)
	local entries = (table_override or Lockstep.TIMEOUTS)[phase]
	if not entries then return nil end
	ctx = ctx or {}
	for _, e in ipairs(entries) do
		if e.force and e.force(ctx) then return e.key end
	end
	local pool, total = {}, 0
	for _, e in ipairs(entries) do
		if e.weight > 0 and (not e.allowed or e.allowed(ctx)) then
			pool[#pool + 1] = e
			total = total + e.weight
		end
	end
	if total <= 0 then return nil end
	local roll = rng(total)
	for _, e in ipairs(pool) do
		roll = roll - e.weight
		if roll <= 0 then return e.key end
	end
	return pool[#pool].key
end

-- ---------------------------------------------------------------------------
-- Clock
-- ---------------------------------------------------------------------------
local Clock = {}
Clock.__index = Clock

function Lockstep.new(config)
	config = config or Lockstep.CONFIG
	return setmetatable({
		cfg = config,
		bank = config.bank_start,
		stack = {}, -- phase frames, innermost last
		paused_reason = nil,
	}, Clock)
end

local function new_turn(frame, cfg)
	frame.turn_elapsed = 0
	frame.grace_left = cfg.grace
	frame.fired = false
	frame.retries = 0
	frame.retry_in = nil
	frame.warned = false
	frame.ready = false
	if frame.others_ready then
		frame.collapse_left = frame.collapsed_once and cfg.collapse_followup or cfg.collapse_window
		frame.collapsed_once = true
	else
		frame.collapse_left = nil
	end
end

function Clock:current()
	return self.stack[#self.stack]
end

function Clock:phase()
	local f = self:current()
	return f and f.phase
end

-- Enter a phase. Sub-phases (pack) push on top of the current frame; top-level
-- phases replace the whole stack.
function Clock:enter(phase)
	local pcfg = self.cfg.phases[phase]
	assert(pcfg, "lockstep: unknown phase " .. tostring(phase))
	if not pcfg.inherit_phase then self.stack = {} end
	self.bank = math.min(self.cfg.bank_cap, self.bank + (pcfg.increment or 0))
	local frame = { phase = phase, phase_elapsed = 0, turns = 1, others_ready = false }
	new_turn(frame, self.cfg)
	self.stack[#self.stack + 1] = frame
	return frame
end

-- Leave the innermost frame (pack closes). Parent's turn keeps its elapsed time.
function Clock:exit()
	table.remove(self.stack)
	local parent = self:current()
	if parent and parent.fired then
		-- parent ran out while we were inside the pack: let it fire again
		parent.fired = false
		parent.retry_in = nil
	end
end

-- New decision inside the same phase (round: next hand after play/discard).
function Clock:turn()
	local f = self:current()
	if not f then return end
	local pcfg = self.cfg.phases[f.phase]
	f.turns = f.turns + 1
	self.bank = math.min(self.cfg.bank_cap, self.bank + (pcfg.turn_increment or 0))
	new_turn(f, self.cfg)
end

function Clock:set_ready(ready)
	local f = self:current()
	if f then f.ready = ready and true or false end
end

-- Barrier signal from the network: everyone ELSE is ready for this phase.
function Clock:set_others_ready(ready)
	for _, f in ipairs(self.stack) do
		if ready and not f.others_ready then
			f.others_ready = true
			if f == self:current() and not f.collapse_left then
				f.collapse_left = f.collapsed_once and self.cfg.collapse_followup or self.cfg.collapse_window
				f.collapsed_once = true
			end
		elseif not ready then
			f.others_ready = false
			f.collapse_left = nil
		end
	end
end

function Clock:stop()
	self.stack = {}
end

-- Seconds left on the current decision (before grace floor is applied).
function Clock:raw_remaining()
	local f = self:current()
	if not f then return math.huge end
	local pcfg = self.cfg.phases[f.phase]
	local r = math.min(self.bank, pcfg.turn_cap - f.turn_elapsed)
	-- phase budget: packs consume their parent's
	local budget_frame, budget_cfg = f, pcfg
	if pcfg.inherit_phase and #self.stack > 1 then
		budget_frame = self.stack[#self.stack - 1]
		budget_cfg = self.cfg.phases[budget_frame.phase]
	end
	if budget_cfg.phase_cap then r = math.min(r, budget_cfg.phase_cap - budget_frame.phase_elapsed) end
	if f.collapse_left then r = math.min(r, f.collapse_left) end
	return r
end

function Clock:remaining()
	local f = self:current()
	if not f then return math.huge end
	return math.max(0, self:raw_remaining(), f.grace_left)
end

-- 0 = calm, 1 = about to fire. Drives jitter / dice fill.
function Clock:telegraph()
	local f = self:current()
	if not f or f.ready or f.fired then return 0 end
	local r = self:remaining()
	if r >= self.cfg.warn_at then return 0 end
	return 1 - (r / self.cfg.warn_at)
end

-- Advance the clock. can_tick: adapter says the player is actually able to act.
-- Returns a list of events: { type = "warn" } | { type = "timeout", phase = ... }
function Clock:update(dt, can_tick)
	local events = {}
	local f = self:current()
	if not f or f.ready or not can_tick then return events end

	if f.fired then
		-- action was dispatched; if the game didn't move on, try again
		if f.retry_in then
			f.retry_in = f.retry_in - dt
			if f.retry_in <= 0 then
				if f.retries >= self.cfg.max_retries then
					f.retry_in = nil -- give up quietly; never spam actions
				else
					f.retries = f.retries + 1
					f.retry_in = self.cfg.retry_after
					events[#events + 1] = { type = "timeout", phase = f.phase, retry = f.retries }
				end
			end
		end
		return events
	end

	self.bank = math.max(0, self.bank - dt)
	f.turn_elapsed = f.turn_elapsed + dt
	f.grace_left = math.max(0, f.grace_left - dt)
	if f.collapse_left then f.collapse_left = math.max(0, f.collapse_left - dt) end
	f.phase_elapsed = f.phase_elapsed + dt
	if self.cfg.phases[f.phase].inherit_phase and #self.stack > 1 then
		local parent = self.stack[#self.stack - 1]
		parent.phase_elapsed = parent.phase_elapsed + dt
	end

	local r = self:remaining()
	if not f.warned and r <= self.cfg.warn_at then
		f.warned = true
		events[#events + 1] = { type = "warn", phase = f.phase }
	end
	-- epsilon: float dt accumulation shouldn't leave a phantom extra frame
	if r <= 1e-6 then
		f.fired = true
		f.retry_in = self.cfg.retry_after
		events[#events + 1] = { type = "timeout", phase = f.phase }
	end
	return events
end

Lockstep.Clock = Clock

if PVP then PVP.Lockstep = Lockstep end
return Lockstep
