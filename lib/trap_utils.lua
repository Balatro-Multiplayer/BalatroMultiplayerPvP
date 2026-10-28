-- Shared plant/disguise/reveal plumbing for Trap consumables (objects/consumables/traps.lua).
-- A Trap card is taken by the Trapper but sits, face-down, in their Nemesis's own
-- G.consumeables until its trigger condition fires -- these are the pieces every one of the
-- 16 cards' use/calculate/receive triple reuses, so each card stays a small, uniform amount
-- of code.
PVP.TRAP = PVP.TRAP or {}

local function self_id()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.player_id
end
PVP.TRAP.self_id = self_id

-- Fires from a Trap card's own use() -- the ONLY moment use() ever runs, since a Trap can only
-- be obtained by taking it from a Trap pack (Card:use_consumeable removes the card from
-- G.pack_cards and never adds it anywhere else). Sent directly to whoever the Trapper's
-- current Nemesis resolves to right now -- NOT the per-object sync bus, since there is no
-- existing card instance on the receiving side yet for `receive` to key off of.
function PVP.TRAP.plant(card)
	local lock = PVP.TRAP.find_arcane_lock()
	if lock then
		PVP.TRAP.bounce_to_holder(card, lock)
		return
	end
	local lobby = MPAPI.get_current_lobby()
	local target = PVP.current_target_id()
	if not (lobby and target) then
		return
	end
	card.ability.mp_trap_owner_id = self_id() -- stamp before serializing; round-trips via card:save()/:load()
	lobby:action(PVP.TRAP.plant_action):send(target, { card = MPAPI.serialize_card(card), owner = self_id() })
end

-- An unfired Arcane Lock sitting in the taker's own consumables.
function PVP.TRAP.find_arcane_lock()
	for _, held in ipairs(G.consumeables and G.consumeables.cards or {}) do
		if
			held.config.center.key == "c_mp_trap_arcane_lock"
			and held.ability.mp_trap_hidden
			and not held.ability.mp_trap_fired
		then
			return held
		end
	end
end

-- Arcane Lock: the Trap card goes face-down into the taker's own consumables and the lock's
-- Trapper becomes its Trapper. The lock fires outside its calculate, so it sets the fired
-- mark itself and sends its notice straight from the center.
function PVP.TRAP.bounce_to_holder(card, lock)
	local trapper = lock.ability.mp_trap_owner_id
	lock.ability.mp_trap_fired = true
	card.ability.mp_trap_owner_id = trapper
	local bounced = MPAPI.rebuild_card(MPAPI.serialize_card(card), G.consumeables)
	if bounced then
		PVP.TRAP.disguise(bounced)
	end
	PVP.TRAP.reveal_and_consume(lock)
	lock.config.center:sync(PVP.TRAP.notify_owner(lock, {}).send)
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
end

local can_sell_card_ref = Card.can_sell_card
function Card:can_sell_card(context)
	if self.ability and self.ability.mp_trap_hidden then
		return false
	end
	return can_sell_card_ref(self, context)
end

-- Runs on the Nemesis's client (wherever the card physically, disguised, sits): flip face-up
-- with a reveal animation, then remove the spent card. The effect notification to the
-- Trapper happens via the card's own calculate return (PVP.TRAP.notify_owner), not here.
function PVP.TRAP.reveal_and_consume(card)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0.1,
		blockable = false,
		func = function()
			card.facing = "front"
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
			G.consumeables:remove_card(card)
			card:remove()
			return true
		end,
	}))
end

-- Decrease a scored playing card's rank by 1, floored at 2 (mirrors Strength's own
-- rank+1 pattern in card.lua, inverted).
local RANK_SUFFIX = { [10] = "T", [11] = "J", [12] = "Q", [13] = "K", [14] = "A" }
function PVP.TRAP.decrease_rank(playing_card)
	local suit_prefix = string.sub(playing_card.base.suit, 1, 1) .. "_"
	local id = math.max(2, playing_card.base.id - 1)
	local rank_suffix = RANK_SUFFIX[id] or tostring(id)
	playing_card:set_base(G.P_CARDS[suit_prefix .. rank_suffix])
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

-- Vanilla refills current_round.free_rerolls from round_resets.free_rerolls when a round starts
-- (new_round in functions/state_events.lua), so rerolls added outside a shop are wiped before the
-- next shop opens. Rerolls granted out of a shop wait in G.GAME (saved with the run) and are added
-- when that shop opens. round_resets is left alone: SMODS.change_free_rerolls would make them permanent.
function PVP.TRAP.grant_free_rerolls(count)
	if G.STATE == G.STATES.SHOP and G.shop then
		G.GAME.current_round.free_rerolls = (G.GAME.current_round.free_rerolls or 0) + count
		calculate_reroll_cost(true)
	else
		G.GAME.mp_pending_free_rerolls = (G.GAME.mp_pending_free_rerolls or 0) + count
	end
end

local update_shop_ref = Game.update_shop
function Game:update_shop(dt)
	if not G.STATE_COMPLETE and (G.GAME.mp_pending_free_rerolls or 0) > 0 then
		G.GAME.current_round.free_rerolls = (G.GAME.current_round.free_rerolls or 0) + G.GAME.mp_pending_free_rerolls
		G.GAME.mp_pending_free_rerolls = nil
		calculate_reroll_cost(true)
	end
	return update_shop_ref(self, dt)
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
