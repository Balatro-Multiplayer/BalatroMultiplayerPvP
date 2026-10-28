-- Shared plant/disguise/reveal plumbing for Trap consumables (objects/consumables/traps.lua).
-- A Trap card is taken by the Trapper but sits, face-down, in their Nemesis's own
-- G.consumeables until its trigger condition fires -- these are the pieces every one of the
-- 16 cards' use/calculate/receive triple reuses, so each card stays a small, uniform amount
-- of code.
PVP.TRAP = PVP.TRAP or {}

PVP.TRAP.KEY = {
	ARCANE_LOCK = "c_mp_trap_arcane_lock",
	MAGIC_MOUTH = "c_mp_trap_magic_mouth",
	FORBIDDANCE = "c_mp_trap_forbiddance",
	MENTAL_PRISON = "c_mp_trap_mental_prison",
}

local function self_id()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.player_id
end
PVP.TRAP.self_id = self_id

-- Fires from a Trap card's own use() -- the ONLY moment use() ever runs, since a Trap can only
-- be obtained by taking it from a Trap pack (Card:use_consumeable removes the card from
-- G.pack_cards and never adds it anywhere else). Sent directly to the ante's Nemesis,
-- NOT the per-object sync bus, since there is no existing card instance on the receiving side yet
-- for `receive` to key off of.
function PVP.TRAP.plant(card)
	local lock = PVP.TRAP.find_planted(PVP.TRAP.KEY.ARCANE_LOCK)
	if lock then
		PVP.TRAP.bounce_to_taker(card, lock)
		return
	end
	local lobby = MPAPI.get_current_lobby()
	local targets = PVP.ante_nemesis_ids()
	if not (lobby and #targets > 0) then
		return
	end
	card.ability.mp_trap_owner_id = self_id() -- stamp before serializing; round-trips via card:save()/:load()
	local params = { card = MPAPI.serialize_card(card), owner = self_id() }
	-- A Manhunt runner has every hunter as a Nemesis: each one gets its own copy, which fires and pays on its own.
	for _, target in ipairs(targets) do
		lobby:action(PVP.TRAP.plant_action):send(target, params)
	end
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
	-- save-data round-trip, neither of which runs here. rebuild_card() constructs
	-- this card fresh with the Card:init() default sprite_facing='front', so without
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
	-- this runs (rebuild_card emplaces it), so the area recounts now, not on its next update.
	card.ability.extra_slots_used = -1
	if card.area then card.area:handle_card_limit() end
	card.ability.mp_trap_card_id = card.ability.mp_trap_card_id or PVP.TRAP_ROW.new_card_id()
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
-- the middle of the screen, flip it face-up, then dissolve it, like a used Tarot. The effect
-- notification to the Trapper happens via the card's own calculate return
-- (PVP.TRAP.notify_owner), not here.
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

-- Fires a trap from outside its calculate (a hooked vanilla function): marks it fired so nothing
-- re-fires it during the reveal delay, reveals and removes it, and sends the notice to the Trapper.
function PVP.TRAP.fire(trap, data)
	trap.ability.mp_trap_fired = true
	PVP.TRAP.reveal_and_consume(trap)
	trap.config.center:sync(PVP.TRAP.notify_owner(trap, data).send)
end

-- Every trap's calculate replies with this exact shape. `send` is the only thing that goes out
-- on the wire (see BalatroMultiplayerAPI's synced_mixin.calculate). The owner id is carried
-- explicitly -- NOT resolved via PVP.current_target_id() at fire time, since a trap's Trapper
-- was fixed when the card was taken and that Trapper's Nemesis may have since rotated
-- to someone else. Every trap's receive must gate on `context.data.owner == PVP.TRAP.self_id()`.
function PVP.TRAP.notify_owner(card, data)
	data = data or {}
	data.owner = card.ability.mp_trap_owner_id
	return { send = data }
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

PVP.TRAP.plant_action = MPAPI.ActionType({
	key = "pvp_trap_plant",
	-- Explicit prefix_config: "pvp_trap_plant" doesn't start with this mod's own
	-- prefix ("mp"), so SMODS would otherwise prepend it -> "mp_pvp_trap_plant",
	-- breaking the direct-reference capture below (still matches the wire key,
	-- but drifts from every other pvp_* ActionType's literal-key convention).
	prefix_config = { key = false },
	parameters = {
		{ key = "card", type = "string", required = true },
		{ key = "owner", type = "string", required = true },
	},
	on_receive = function(_at, from, params)
		local card = MPAPI.rebuild_card(params.card, G.consumeables)
		if not card then
			return
		end
		card.ability.mp_trap_owner_id = params.owner
		PVP.TRAP.disguise(card)
	end,
})
