-- Shared plant/disguise/reveal plumbing for Trap consumables (objects/consumables/traps.lua).
-- A Trap card is taken by the Trapper but sits, face-down, in their Nemesis's own
-- G.consumeables until its trigger condition fires. The server owns the record of every trap
-- ("pvp.traps": who planted it, who holds it, whether it fired); a client plants with a request,
-- builds the traps the record says it holds, and reports a fire. These are the pieces every one of
-- the 16 cards' use/calculate/reward triple reuses, so each card stays a small, uniform amount of code.
PVP.TRAP = PVP.TRAP or {}

PVP.TRAP.KEY = {
	ARCANE_LOCK = "c_mp_trap_arcane_lock",
	MAGIC_MOUTH = "c_mp_trap_magic_mouth",
	FORBIDDANCE = "c_mp_trap_forbiddance",
	MENTAL_PRISON = "c_mp_trap_mental_prison",
}

local TRAPS_KEY = "pvp.traps"

local function self_id()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.player_id
end
PVP.TRAP.self_id = self_id

-- The owner's reward of each trap, by the trap's center key: { [key] = function(data) }, filled by
-- objects/consumables/traps.lua. A handler checks the fired data against the game's own tables (the server
-- checks only its shape) and returns nothing when it paid, or false and the reason when the check failed.
PVP.TRAP.REWARDS = PVP.TRAP.REWARDS or {}

-- Fires from a Trap card's own use() -- the ONLY moment use() ever runs, since a Trap can only
-- be obtained by taking it from a Trap pack (Card:use_consumeable removes the card from
-- G.pack_cards and never adds it anywhere else). The server decides who holds it: the planter's
-- frozen targets (every hunter for a Manhunt runner), or the planter when an Arcane Lock bounces it.
function PVP.TRAP.plant(card)
	PVP.OpponentNet.send_request("pvp.trap_plant", { key = card.config.center.key })
end

-- A planted trap of this center key that is still hidden and has not fired, in the player's own consumables.
-- For a Manhunt runner these are the copies the hunters planted, so a hunter's lock still stops the runner's plant.
function PVP.TRAP.find_planted(key)
	for _, held in ipairs(G.consumeables and G.consumeables.cards or {}) do
		if held.config.center.key == key and held.ability.mp_trap_hidden and not held.ability.mp_trap_fired then
			return held
		end
	end
end

-- Face-down and unsellable, so a planted trap always eventually fires -- it can't be
-- discarded away by the Nemesis. Consumables normally CAN be sold in this game (G.consumeables'
-- CardArea uses the same config.type='joker' selling gate jokers do -- see the can_sell_card
-- wrap below), so this needs an explicit block, not just a worthless sell_cost.
function PVP.TRAP.disguise(card)
	-- CONFIRMED LIVE BUG, fixed by the sprite_facing line: Card:draw() branches on
	-- sprite_facing, not facing -- facing only feeds sprite_facing via Card:flip()'s
	-- animated transition (see Card:update()'s f2b/b2f handling) or Card:load()'s
	-- save-data round-trip, neither of which runs here. A card built fresh
	-- constructs with the Card:init() default sprite_facing='front', so without
	-- this line the trap silently keeps rendering its real front art (fully revealing
	-- which trap it is, and that it's a trap at all) despite facing already reading
	-- 'back' -- reproduced live over a real multiplayer connection: the Nemesis's
	-- client showed "TRAP" with the Trap card's actual icon in plain view. Set
	-- directly rather than via card:flip(), which would toggle facing back to
	-- 'front' (it inspects the already-'back' facing set above and flips the other
	-- way) and play a visible reveal animation -- this needs to silently already BE
	-- face-down the moment it lands, the same way Card:load()'ing a saved back-facing
	-- card would look, not animate a flip that would itself tip off the Nemesis.
	card.facing = "back"
	card.sprite_facing = "back"
	card.ability.mp_trap_hidden = true
	-- Steamodded counts a card as #cards + sum(extra_slots_used) against the area's limit, so -1 cancels
	-- this card's own slot. It lives in card.ability, so it round-trips through save and load, and the
	-- area recounts without the card as soon as the card leaves it. The card is already in its area when
	-- this runs (add_card emplaces it), so the area recounts now, not on its next update.
	card.ability.extra_slots_used = -1
	if card.area then card.area:handle_card_limit() end
end

local can_sell_card_ref = Card.can_sell_card
function Card:can_sell_card(context)
	if not PVP.in_session() then
		return can_sell_card_ref(self, context)
	end
	if self.ability and self.ability.mp_trap_hidden then
		return false
	end
	return can_sell_card_ref(self, context)
end

-- Runs on the Nemesis's client (wherever the card physically, disguised, sits): move the trap to
-- the middle of the screen, flip it face-up, then dissolve it, like a used Tarot. The fire request to the
-- server is sent by PVP.TRAP.fire, not here.
function PVP.TRAP.reveal_and_consume(card)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0.1,
		blockable = false,
		func = function()
			-- Taken out of every area and placed by hand, as vanilla use_card does for a card used
			-- from a pack: emplacing in G.play would let the end-of-hand sweep discard the trap into
			-- the Nemesis's deck when it fires mid-hand.
			G.consumeables:remove_card(card)
			card.ability.mp_trap_hidden = nil
			card.T.x = G.play.T.x + G.play.T.w / 2 - card.T.w / 2
			card.T.y = G.play.T.y + G.play.T.h / 2 - card.T.h / 2
			-- flip() turns a 'back' card to the front; facing is left 'back' from disguise().
			card:flip()
			card:juice_up(0.8, 0.5)
			play_sound("tarot2")
			return true
		end,
	}))
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0.9,
		blockable = false,
		func = function()
			card:start_dissolve()
			return true
		end,
	}))
end

-- One of the traps' id sets kept with the run ("traps_sent", "traps_applied"): { runId, ids = { [tostring(id)] } }.
-- A set of another run than `run_id` starts again; one with no run yet (a rejoin's catch-up) is kept and
-- takes the run when it is known.
local function id_set(key, run_id)
	local record = PVP.GAME[key]
	if type(record) == "table" and record.runId ~= nil and run_id ~= nil and tostring(record.runId) ~= run_id then
		record = nil
	end
	if type(record) ~= "table" then
		record = { runId = run_id, ids = {} }
		PVP.GAME[key] = record
	end
	if record.runId == nil then record.runId = run_id end
	return record.ids
end

-- Fires a trap: marks it fired so nothing re-fires it during the reveal delay, remembers its id as sent
-- (so reconcile does not rebuild it before the server's record settles), reveals and removes it, and
-- reports the fire to the server with the shape of data its key takes.
function PVP.TRAP.fire(trap, data)
	local id = trap.ability.mp_trap_id
	trap.ability.mp_trap_fired = true
	PVP.TRAP.reveal_and_consume(trap)
	if id == nil then
		PVP.match_log("info", "[pvp] error: trap " .. tostring(trap.config.center.key) .. " fired with no server id")
		return
	end
	PVP.TRAP.remember_report(id, "pvp.trap_fire", data)
end

-- Fires a trap that has nothing to pay (a Snare with no recorded tag): it is revealed and spent, and the server
-- is told it was lost, so it settles with no reward.
function PVP.TRAP.fire_unpaid(trap)
	local id = trap.ability.mp_trap_id
	trap.ability.mp_trap_fired = true
	PVP.TRAP.reveal_and_consume(trap)
	if id == nil then
		PVP.match_log("info", "[pvp] error: trap " .. tostring(trap.config.center.key) .. " spent with no server id")
		return
	end
	PVP.TRAP.remember_report(id, "pvp.trap_lost")
end

-- Keeps a report the server has not settled in the run's saved record, then tries to send it. `data` is nil for
-- the keys that carry none (it must stay absent: an empty table would be written as an array). The record is
-- the queue: whatever cannot go out now (not live, a crash) goes at the next connect, while the trap is live.
function PVP.TRAP.remember_report(id, kind, data)
	id_set("traps_sent", PVP.current_run_id())[tostring(id)] = { kind = kind, data = data }
	PVP.TrapsNet.report(id)
end

-- The reports still to send. Pure: the record's traps still live that I have a report for.
--   value  the "pvp.traps" value of the run, nil while unknown
--   sent   { [tostring(id)] = { kind, data, given_up } } (a bare `true` is no report; given_up: the server refused it for good)
-- Returns { { id, kind, data } } in the record's order.
function PVP.TRAP.pending_reports(value, sent)
	local out = {}
	if type(value) ~= "table" or type(value.traps) ~= "table" then return out end
	for _, trap in ipairs(value.traps) do
		local entry = sent[tostring(trap.id)]
		if trap.state == "live" and type(entry) == "table" and not entry.given_up then
			out[#out + 1] = { id = trap.id, kind = entry.kind, data = entry.data }
		end
	end
	return out
end

-- The "use" animation played on the Trapper's own screen when their planted trap
-- fires remotely -- they never see the Nemesis's reveal directly, just this local flourish.
function PVP.UI.show_trap_fired_animation(name)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0.1,
		blockable = false,
		func = function()
			attention_text({
				text = name .. " Triggered!",
				scale = 0.8,
				colour = PVP.COLOURS.DARK_PINK,
				pos = { x = G.consumeables.T.x + G.consumeables.T.w / 2, y = G.consumeables.T.y },
				align = "cm",
				hold = 1.2,
			})
			play_sound("tarot2")
			return true
		end,
	}))
end

-- A trap fires once: reveal_and_consume only removes the card after a short delay, so events in
-- that gap would fire it again. Wrapping calculate here gives every trap the check.
function PVP.TRAP.fire_once(calculate)
	if not calculate then
		return nil
	end
	return function(self, card, context)
		if card.ability.mp_trap_fired then
			return
		end
		local result = calculate(self, card, context)
		if result then
			card.ability.mp_trap_fired = true
		end
		return result
	end
end

-- Builds the card of a trap record this client holds, face-down, in its consumables. The card carries the
-- server's id: that id is what a fire and a lost report name.
function PVP.TRAP.build(trap)
	local card = SMODS.add_card({ key = trap.key, set = "Trap", area = G.consumeables })
	if not card then
		PVP.match_log("info", "[pvp] error: trap " .. tostring(trap.id) .. " (" .. tostring(trap.key) .. ") could not be built")
		return nil
	end
	card.ability.mp_trap_id = trap.id
	PVP.TRAP.disguise(card)
	return card
end

-- What to do so this client's traps match the server's record. Pure: plain tables in, plain tables out.
--   value     the "pvp.traps" value of the run
--   my_id     this player
--   held      the trap cards in my consumables: { { id, fired } } (fired: already revealing and leaving)
--   sent      ids I fired or reported lost and have not seen settle, { [tostring(id)] = true }
--   consumed  ids of cards already consumed because the server's record is past them
-- Returns { build = { trap records to build }, consume = { ids of cards to consume }, settled = { ids of
-- `sent` the record has settled, to forget } }.
--   * a trap I hold with no card here is built once, unless I fired it (it is in `sent`) or its card was
--     already consumed; a fired or lost one is never built
--   * a card whose trap the record says is fired or lost is consumed once
function PVP.TRAP.reconcile_plan(value, my_id, held, sent, consumed)
	local plan = { build = {}, consume = {}, settled = {} }
	if type(value) ~= "table" or type(value.traps) ~= "table" then return plan end
	-- A state that is neither live nor spent is unknown: nothing is done for it.
	local function spent(trap)
		return trap.state == "lost" or type(trap.state) == "table"
	end
	local by_id = {}
	for _, trap in ipairs(value.traps) do
		by_id[tostring(trap.id)] = trap
	end
	local present = {}
	for _, card in ipairs(held) do
		local id = tostring(card.id)
		present[id] = true
		local trap = by_id[id]
		if trap and spent(trap) and not card.fired and not consumed[id] then
			plan.consume[#plan.consume + 1] = card.id
		end
	end
	for _, trap in ipairs(value.traps) do
		local id = tostring(trap.id)
		if spent(trap) then
			if sent[id] then plan.settled[#plan.settled + 1] = trap.id end
		elseif trap.state == "live" and trap.holder == my_id and not present[id] and not sent[id] and not consumed[id] then
			plan.build[#plan.build + 1] = trap
		end
	end
	return plan
end

-- Makes this client's trap cards match the server's record (pvp_api/traps_net.lua runs it after every update,
-- on a load and at every connect). A trap the record says I hold and I have no card for (a plant made while I
-- was away, a lost save) is built; a card the record says is spent is consumed.
function PVP.TRAP.reconcile()
	local run_id = PVP.current_run_id()
	local value = MPAPI.get_state(TRAPS_KEY)
	if not (G.consumeables and PVP.StateValue.same_run(value, run_id)) then return end
	local held = {}
	for _, card in ipairs(G.consumeables.cards) do
		local ability = card.ability
		if ability.mp_trap_hidden and ability.mp_trap_id ~= nil then
			held[#held + 1] = { id = ability.mp_trap_id, fired = ability.mp_trap_fired == true, card = card }
		end
	end
	local sent, consumed = id_set("traps_sent", run_id), id_set("traps_applied", run_id)
	local plan = PVP.TRAP.reconcile_plan(value, self_id(), held, sent, consumed)
	for _, id in ipairs(plan.settled) do
		sent[tostring(id)] = nil
	end
	for _, id in ipairs(plan.consume) do
		consumed[tostring(id)] = true
		for _, entry in ipairs(held) do
			if entry.id == id then
				entry.card.ability.mp_trap_fired = true
				PVP.TRAP.reveal_and_consume(entry.card)
			end
		end
	end
	for _, trap in ipairs(plan.build) do
		PVP.TRAP.build(trap)
	end
end

-- A hidden, unfired trap destroyed by the game while it is live (an explicit destroy, not a reload and not
-- its own fire) is reported lost, so the server stops counting it as held and nothing rebuilds it.
local start_dissolve_ref = Card.start_dissolve
function Card:start_dissolve(...)
	local ability = self.ability
	if
		PVP.in_session()
		and ability
		and ability.mp_trap_hidden
		and not ability.mp_trap_fired
		and ability.mp_trap_id ~= nil
		and self.area == G.consumeables
	then
		ability.mp_trap_fired = true
		PVP.TRAP.remember_report(ability.mp_trap_id, "pvp.trap_lost")
	end
	return start_dissolve_ref(self, ...)
end
