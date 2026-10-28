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

-- The trap itself answers only one destroy_card context (fire_once), so a trap that must break
-- several cards marks them with mp_trap_break and the cards answer for themselves.
local calculate_enhancement_ref = Card.calculate_enhancement
function Card:calculate_enhancement(context)
	if self.ability and self.ability.mp_trap_break and context.destroy_card == self and context.cardarea == G.play then
		return { remove = true }
	end
	return calculate_enhancement_ref(self, context)
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

-- Seal rewards are made by direct Card method calls, never a calculate context, so Magic Mouth
-- hooks the two methods instead. A Blue or Purple Seal that fires always raises
-- consumeable_buffer (it only fires with room), which is how a trigger is told from a miss.
-- The reward card is made in a queued event; a later event queued here runs right after it,
-- takes the new card away from the Nemesis, and sends it to the Trapper.
local function find_magic_mouth()
	if not G.consumeables then
		return nil
	end
	for _, held in ipairs(G.consumeables.cards) do
		if
			held.ability.mp_trap_hidden
			and not held.ability.mp_trap_fired
			and held.config.center.key == "c_mp_trap_magic_mouth"
		then
			return held
		end
	end
end

local function steal_seal_reward(trap, cards_before)
	G.E_MANAGER:add_event(Event({
		trigger = "before",
		delay = 0,
		blockable = false,
		func = function()
			if trap.ability.mp_trap_fired then
				return true
			end
			local known = {}
			for _, held in ipairs(cards_before) do
				known[held] = true
			end
			for _, held in ipairs(G.consumeables.cards) do
				if not known[held] and held ~= trap then
					trap.ability.mp_trap_fired = true
					local data = PVP.TRAP.notify_owner(trap, { card = MPAPI.serialize_card(held) }).send
					G.consumeables:remove_card(held)
					held:remove()
					PVP.TRAP.reveal_and_consume(trap)
					trap.config.center:sync(data)
					break
				end
			end
			return true
		end,
	}))
end

local function wrap_seal_method(method_name)
	local method_ref = Card[method_name]
	Card[method_name] = function(self, context)
		local trap = (self.seal == "Blue" or self.seal == "Purple") and find_magic_mouth()
		if not trap then
			return method_ref(self, context)
		end
		local cards_before = { unpack(G.consumeables.cards) }
		local buffer_before = G.GAME.consumeable_buffer
		local first, second = method_ref(self, context)
		if G.GAME.consumeable_buffer > buffer_before then
			steal_seal_reward(trap, cards_before)
		end
		return first, second
	end
end
wrap_seal_method("get_end_of_round_effect")
wrap_seal_method("calculate_seal")

-- Forbiddance acts on the refill draw that follows a discard, which is a draw_card call with no
-- calculate context to answer. A discard arms the trap, Blind:stay_flipped keeps the refill cards
-- face-down (a face-down card flips up when played, as for a vanilla boss blind), and an event
-- queued behind the refill draw disarms it and fires it, so later draws are face-up.
local function find_forbiddance()
	if not G.consumeables then
		return nil
	end
	for _, held in ipairs(G.consumeables.cards) do
		if
			held.ability.mp_trap_hidden
			and not held.ability.mp_trap_fired
			and held.config.center.key == "c_mp_trap_forbiddance"
		then
			return held
		end
	end
end

local function armed_forbiddance()
	local trap = find_forbiddance()
	return trap and trap.ability.mp_forbiddance_armed and trap
end

local discard_cards_ref = G.FUNCS.discard_cards_from_highlighted
function G.FUNCS.discard_cards_from_highlighted(e, is_hook_blind)
	local trap = not is_hook_blind and #G.hand.highlighted > 0 and find_forbiddance()
	discard_cards_ref(e, is_hook_blind)
	-- A blind-forced discard sets no draw state, so only a player discard is followed by a refill.
	if trap and G.STATE == G.STATES.DRAW_TO_HAND then
		trap.ability.mp_forbiddance_armed = true
		trap.ability.mp_forbiddance_flipped = 0
	end
end

local stay_flipped_ref = Blind.stay_flipped
function Blind:stay_flipped(to_area, card, from_area)
	local trap = to_area == G.hand and from_area == G.deck and armed_forbiddance()
	if trap then
		trap.ability.mp_forbiddance_flipped = trap.ability.mp_forbiddance_flipped + 1
		return true
	end
	return stay_flipped_ref(self, to_area, card, from_area)
end

local draw_from_deck_to_hand_ref = G.FUNCS.draw_from_deck_to_hand
function G.FUNCS.draw_from_deck_to_hand(e)
	local trap = armed_forbiddance()
	local result = draw_from_deck_to_hand_ref(e)
	if trap then
		G.E_MANAGER:add_event(Event({
			trigger = "immediate",
			func = function()
				trap.ability.mp_forbiddance_armed = nil
				-- An empty deck refills nothing: the trap stays hidden for the next discard.
				if trap.ability.mp_forbiddance_flipped > 0 and not trap.ability.mp_trap_fired then
					trap.ability.mp_trap_fired = true
					PVP.TRAP.reveal_and_consume(trap)
					trap.config.center:sync(PVP.TRAP.notify_owner(trap, {}).send)
				end
				return true
			end,
		}))
	end
	return result
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

-- Programmed Illusion. Card:open reads the pack size in a later event, so growing the opened pack's
-- `extra` by one makes vanilla build the fake as the pack's last card, with the pack's own card
-- generator. Only the Nemesis builds it, so the pseudorandom streams are saved before it is built and
-- restored after: every other client's pack stays in sync.
function PVP.TRAP.add_illusion_slot(booster)
	local ability = booster and booster.ability
	if not (ability and ability.extra) or ability.mp_illusion_index then
		return false
	end
	local modifier = G.GAME.modifiers.booster_size_mod or 0
	local size = math.max(1, ability.extra + modifier)
	ability.extra = size + 1 - modifier
	ability.mp_illusion_index = size + 1
	return true
end

local illusion_rng_state
local function save_pseudorandom()
	illusion_rng_state = {}
	for key, value in pairs(G.GAME.pseudorandom) do
		illusion_rng_state[key] = value
	end
end

local function restore_pseudorandom()
	for key in pairs(G.GAME.pseudorandom) do
		G.GAME.pseudorandom[key] = nil
	end
	for key, value in pairs(illusion_rng_state) do
		G.GAME.pseudorandom[key] = value
	end
	illusion_rng_state = nil
end

local calculate_context_ref = SMODS.calculate_context
function SMODS.calculate_context(context, return_table, no_resolve)
	local booster = type(context) == "table" and context.booster
	local is_fake_slot = booster and booster.ability and booster.ability.mp_illusion_index == context.index
	if is_fake_slot and context.create_booster_card then
		save_pseudorandom()
	end
	local result = calculate_context_ref(context, return_table, no_resolve)
	if is_fake_slot and context.modify_booster_card and illusion_rng_state then
		restore_pseudorandom()
		context.card.ability.mp_illusion_fake = true
		if G.pack_cards then
			G.pack_cards.config.card_limit = math.max(G.pack_cards.config.card_limit, context.index)
		end
	end
	return result
end

-- Picking the fake runs vanilla's pick bookkeeping (one pick spent, pack ends or stays) but hides the
-- card's set and consumeable table so none of the add/use branches match, and SMODS_use_card stops the
-- select-to-area branch. The card then dissolves like any used card.
local use_card_ref = G.FUNCS.use_card
function G.FUNCS.use_card(e, mute, nosave)
	local card = e.config and e.config.ref_table
	if not (card and card.ability and card.ability.mp_illusion_fake) then
		return use_card_ref(e, mute, nosave)
	end
	local set, consumeable = card.ability.set, card.ability.consumeable
	card.ability.set, card.ability.consumeable = "mp_illusion", nil
	local smods_use_card = e.config.SMODS_use_card
	e.config.SMODS_use_card = true
	use_card_ref(e, mute, nosave)
	card.ability.set, card.ability.consumeable = set, consumeable
	e.config.SMODS_use_card = smods_use_card
	G.hand:unhighlight_all()
end

-- Mental Prison watches what is on offer at the moment the Nemesis walks away, so there is no
-- seen-state to save: a Wheel of Fortune still in the shop or the pack at that moment was not taken.
-- Leaving the shop is a calculate context; skipping or finishing a pack and rerolling are not
-- (the reroll context only fires after the shop cards are replaced), so those two wrap the
-- vanilla functions and read the area before it is cleared.
function PVP.TRAP.area_holds_wheel(area)
	for _, offered in ipairs(area and area.cards or {}) do
		if offered.config.center.key == "c_wheel_of_fortune" then
			return true
		end
	end
	return false
end

local function find_mental_prison()
	if not G.consumeables then
		return nil
	end
	for _, held in ipairs(G.consumeables.cards) do
		if
			held.ability.mp_trap_hidden
			and not held.ability.mp_trap_fired
			and held.config.center.key == "c_mp_trap_mental_prison"
		then
			return held
		end
	end
end

local function fire_mental_prison_if_wheel_left(area)
	local trap = find_mental_prison()
	if trap and PVP.TRAP.area_holds_wheel(area) then
		trap.ability.mp_trap_fired = true
		PVP.TRAP.reveal_and_consume(trap)
		trap.config.center:sync(PVP.TRAP.notify_owner(trap, {}).send)
	end
end

-- Runs for both a skipped pack and a pack whose picks are used up.
local end_consumeable_ref = G.FUNCS.end_consumeable
G.FUNCS.end_consumeable = function(e, delayfac)
	fire_mental_prison_if_wheel_left(G.pack_cards)
	return end_consumeable_ref(e, delayfac)
end

local reroll_shop_ref = G.FUNCS.reroll_shop
G.FUNCS.reroll_shop = function(e)
	fire_mental_prison_if_wheel_left(G.shop_jokers)
	return reroll_shop_ref(e)
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
