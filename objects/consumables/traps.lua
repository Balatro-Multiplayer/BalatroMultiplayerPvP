-- Trap: a consumable type that reacts to something your Nemesis does. A Trap can only be
-- drafted from a Trap booster pack (objects/boosters/traps.lua); drafting one plants it,
-- face-down, in the drafter's Nemesis's own consumables instead of the drafter's (see
-- lib/trap_utils.lua's PVP.TRAP.plant/disguise). When the Nemesis's own action satisfies the
-- trap's trigger, it reveals itself on their screen and its effect benefits the ORIGINAL
-- drafter -- who also gets a "use" animation on their own screen. See lib/trap_utils.lua for
-- the shared plant/disguise/reveal/notify_owner framework every card below reuses, and the
-- layer that gates when these can spawn at all in layers/traps.lua.
SMODS.ConsumableType({
	key = "Trap",
	primary_colour = PVP.COLOURS.BLACK,
	secondary_colour = PVP.COLOURS.DARK_PINK,
	loc_txt = {
		["en-us"] = {
			name = "Trap",
			collection = "Trap Cards",
			-- Must be a {name=..., text={...}} table, not a bare string: SMODS.ConsumableType's
			-- process_loc_text writes this straight into G.localization.descriptions.Other, and
			-- the base game's init_localization (functions/misc_functions.lua) unconditionally
			-- does `center.text_parsed = {}` on every entry there, which crashes on a string.
			-- Every vanilla undiscovered_* entry (see Balatro/localization/en-us.lua) is shaped
			-- this way -- Trap was the first custom ConsumableType in this mod stack to supply a
			-- non-empty `undiscovered` at all, so nothing had hit this before.
			undiscovered = {
				name = "??? Trap Card",
				text = {
					"Drafted by an",
					"opponent -- reacts",
					"to something you do",
				},
			},
		},
	},
})

local TRAPS = {
	-- Glyph of Warding: when the holder uses a Spectral card, the drafter gets a Jumbo
	-- Spectral pack to open.
	{
		key = "trap_glyph_of_warding",
		idea = "Virtualized",
		art = "OvertLeaf4",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.using_consumeable and context.consumeable.config.center.set == "Spectral" then
				PVP.TRAP.reveal_and_consume(card)
				return PVP.TRAP.notify_owner(card, {})
			end
		end,
		receive = function(self, context)
			if context.data.owner ~= PVP.TRAP.self_id() then
				return
			end
			-- SMODS.add_card needs `set` explicitly -- it's passed straight through
			-- to vanilla create_card's positional _type arg, never inferred from
			-- the target center's own .set (confirmed by reading SMODS.create_card:
			-- only `area` gets auto-derived from G.P_CENTERS[key], not `set`).
			-- Omitting it crashes deep in create_card's rarity-pool code with
			-- "attempt to concatenate local '_type' (a nil value)" -- found live via
			-- cctl, not from reading this file in isolation.
			local pack_card = SMODS.add_card({ key = "p_spectral_jumbo_1", set = "Booster", area = G.consumeables, skip_materialize = true })
			if pack_card and pack_card.open then
				pack_card:open()
			end
			PVP.UI.show_trap_fired_animation("Glyph of Warding")
		end,
	},
	-- Symbol: when the holder plays a flush, convert all scored cards to random suits.
	{
		key = "trap_symbol",
		idea = "Virtualized",
		art = "OvertLeaf4",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.before and context.poker_hands and next(context.poker_hands["Flush"]) then
				PVP.TRAP.reveal_and_consume(card)
				for _, scored in ipairs(context.scoring_hand or {}) do
					local suit = pseudorandom_element({ "Spades", "Hearts", "Clubs", "Diamonds" }, pseudoseed("mp_trap_symbol"))
					scored:change_suit(suit)
				end
				return PVP.TRAP.notify_owner(card, {})
			end
		end,
		receive = function(self, context)
			if context.data.owner ~= PVP.TRAP.self_id() then
				return
			end
			PVP.UI.show_trap_fired_animation("Symbol")
		end,
	},
	-- Alarm: when the holder rerolls their shop, the drafter gains 2 free rerolls (now in a shop, else at the next shop).
	{
		key = "trap_alarm",
		idea = "Virtualized",
		art = "Zwei",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.reroll_shop then
				PVP.TRAP.reveal_and_consume(card)
				return PVP.TRAP.notify_owner(card, { rerolls = 2 })
			end
		end,
		receive = function(self, context)
			if context.data.owner ~= PVP.TRAP.self_id() then
				return
			end
			PVP.TRAP.grant_free_rerolls(context.data.rerolls)
			PVP.UI.show_trap_fired_animation("Alarm")
		end,
	},
	-- Explosive Runes: when the holder plays a hand with a glass card, all glass cards in
	-- that hand are guaranteed to break. Deferred: forcing a glass break bypasses SMODS's own
	-- probability roll and needs its own destroy_card-context hook (see plan's Phase 3 notes);
	-- not yet implemented.
	{
		key = "trap_explosive_runes",
		idea = "Virtualized",
		art = "shai1n",
		code = "Virtualized",
	},
	-- Sepia Snake Sigil: when the holder buys a Rare Joker, the drafter gains a copy of it.
	{
		key = "trap_sepia_snake_sigil",
		idea = "Virtualized",
		art = "DottyKitty",
		code = "Virtualized",
		calculate = function(self, card, context)
			if
				context.buying_card
				and context.card.ability.set == "Joker"
				and (context.card.config.center.rarity == 3 or context.card.config.center.rarity == "Rare")
			then
				PVP.TRAP.reveal_and_consume(card)
				return PVP.TRAP.notify_owner(card, { key = context.card.config.center.key })
			end
		end,
		receive = function(self, context)
			if context.data.owner ~= PVP.TRAP.self_id() then
				return
			end
			if context.data.key then
				-- set required -- see glyph_of_warding's comment above (SMODS.add_card
				-- never infers it from the target center).
				SMODS.add_card({ key = context.data.key, set = "Joker", area = G.jokers })
			end
			PVP.UI.show_trap_fired_animation("Sepia Snake Sigil")
		end,
	},
	-- Fire Trap: when the holder plays a hand with a pair, decrease the rank of all scored
	-- cards by 1.
	{
		key = "trap_fire_trap",
		idea = "Virtualized",
		art = "Ganpan140",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.before and context.poker_hands and next(context.poker_hands["Pair"]) then
				PVP.TRAP.reveal_and_consume(card)
				for _, scored in ipairs(context.scoring_hand or {}) do
					PVP.TRAP.decrease_rank(scored)
				end
				return PVP.TRAP.notify_owner(card, {})
			end
		end,
		receive = function(self, context)
			if context.data.owner ~= PVP.TRAP.self_id() then
				return
			end
			PVP.UI.show_trap_fired_animation("Fire Trap")
		end,
	},
	-- Guards and Wards: when the holder adds a playing card to their deck, add 2 Stone cards
	-- to their deck.
	{
		key = "trap_guards_and_wards",
		idea = "Virtualized",
		art = "Nas4xou",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.playing_card_added then
				PVP.TRAP.reveal_and_consume(card)
				-- Added here, on the Nemesis's client. create_playing_card sends no
				-- playing_card_added context itself, so the Stone cards cannot re-trigger.
				for _ = 1, 2 do
					create_playing_card({
						front = pseudorandom_element(G.P_CARDS, pseudoseed("mp_trap_guards")),
						center = G.P_CENTERS.m_stone,
					}, G.deck)
				end
				return PVP.TRAP.notify_owner(card, {})
			end
		end,
		receive = function(self, context)
			if context.data.owner ~= PVP.TRAP.self_id() then
				return
			end
			PVP.UI.show_trap_fired_animation("Guards and Wards")
		end,
	},
	-- Magic Mouth: when the holder triggers a blue or purple seal, steal the consumable.
	-- No calculate: the trigger is hooked in lib/trap_utils.lua, which sends the stolen card here.
	{
		key = "trap_magic_mouth",
		idea = "Virtualized",
		art = "TypeFate",
		code = "Virtualized",
		receive = function(self, context)
			if context.data.owner ~= PVP.TRAP.self_id() then
				return
			end
			-- Counts the buffer too, so a card still being made does not leave the area over its limit.
			local has_room = #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit
			if has_room then
				MPAPI.rebuild_card(context.data.card, G.consumeables)
			end
			PVP.UI.show_trap_fired_animation("Magic Mouth")
		end,
	},
	-- Snare: when the holder skips a blind, the drafter gains a copy of the tag they got.
	{
		key = "trap_snare",
		idea = "Virtualized",
		art = "Ganpan140",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.skip_blind then
				-- Vanilla G.FUNCS.skip_blind calls add_tag(skip tag) first, then queues the event that
				-- sends skip_blind, so the Nemesis's skip tag is already the last entry of G.GAME.tags
				-- here. A Double Tag copy has the same key, so the last entry is still the right one.
				local skipped_tag = G.GAME.tags[#G.GAME.tags]
				PVP.TRAP.reveal_and_consume(card)
				return PVP.TRAP.notify_owner(card, { tag_key = skipped_tag and skipped_tag.key })
			end
		end,
		receive = function(self, context)
			if context.data.owner ~= PVP.TRAP.self_id() then
				return
			end
			if context.data.tag_key then
				add_tag(Tag(context.data.tag_key))
			end
			PVP.UI.show_trap_fired_animation("Snare")
		end,
	},
	-- Arcane Lock: when the holder uses (i.e. a different planted trap fires on) a Trap card,
	-- they get trapped instead. Deferred: needs a "another trap just fired" signal, which isn't
	-- a natural calculate-context flag -- would need PVP.TRAP.reveal_and_consume itself to fire a
	-- custom local context so a co-resident Arcane Lock can intercept. Not yet implemented.
	{
		key = "trap_arcane_lock",
		idea = "Virtualized",
		art = "shai1n",
		code = "Virtualized",
	},
	-- Programmed Illusion: when the holder opens a booster pack, add a fake card to it.
	-- Deferred: Card:open builds its pack_cards list in a function-local table with no exposed
	-- extension point for injecting an extra card -- needs a direct hook/override, not a
	-- calculate-context check. Not yet implemented.
	{
		key = "trap_programmed_illusion",
		idea = "Virtualized",
		art = "TypeFate",
		code = "Virtualized",
	},
	-- Web: when the holder uses any consumable, the drafter gains a negative copy of it.
	{
		key = "trap_web",
		idea = "Virtualized",
		art = "Ganpan140",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.using_consumeable then
				PVP.TRAP.reveal_and_consume(card)
				-- `set` must travel with the key: unlike sepia_snake_sigil/glyph_of_warding
				-- (always one fixed type), Web can copy ANY consumable set (Tarot/Planet/
				-- Spectral), and SMODS.add_card never infers `set` from the target center.
				return PVP.TRAP.notify_owner(card, { key = context.consumeable.config.center.key, set = context.consumeable.config.center.set })
			end
		end,
		receive = function(self, context)
			if context.data.owner ~= PVP.TRAP.self_id() then
				return
			end
			if context.data.key then
				SMODS.add_card({ key = context.data.key, set = context.data.set, area = G.consumeables, edition = "e_negative" })
			end
			PVP.UI.show_trap_fired_animation("Web")
		end,
	},
	-- Forbiddance: when the holder discards, the cards drawn from their deck are flipped.
	-- Deferred: the draw loop (G.FUNCS.draw_from_deck_to_hand) has no exposed "flip after
	-- draw" hook -- needs a new override on the draw path, not a calculate-context check.
	-- Not yet implemented.
	{
		key = "trap_forbiddance",
		idea = "Virtualized",
		art = "shai1n",
		code = "Virtualized",
	},
	-- Faithful Hound: when the holder uses a Planet card, the drafter gains 3 levels of that
	-- poker hand.
	{
		key = "trap_faithful_hound",
		idea = "Virtualized",
		art = "StaticTyr",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.using_consumeable and context.consumeable.config.center.set == "Planet" then
				local hand_type = context.consumeable.ability.consumeable and context.consumeable.ability.consumeable.hand_type
				if hand_type then
					PVP.TRAP.reveal_and_consume(card)
					return PVP.TRAP.notify_owner(card, { hand_type = hand_type })
				end
			end
		end,
		receive = function(self, context)
			if context.data.owner ~= PVP.TRAP.self_id() then
				return
			end
			if context.data.hand_type then
				level_up_hand(nil, context.data.hand_type, true, 3)
			end
			PVP.UI.show_trap_fired_animation("Faithful Hound")
		end,
	},
	-- Phase Door: when the holder's held gold cards pay out at end of round, the drafter gains $4
	-- per gold card in their hand.
	{
		key = "trap_phase_door",
		idea = "Virtualized",
		art = "Ganpan140",
		code = "Virtualized",
		calculate = function(self, card, context)
			-- The first held gold card's payout evaluation stands for the whole hand: the trap
			-- fires once, so it counts every held gold card then.
			if
				context.end_of_round
				and context.individual
				and context.cardarea == G.hand
				and context.other_card
				and not context.other_card.debuff
				and SMODS.has_enhancement(context.other_card, "m_gold")
			then
				local gold_count = 0
				for _, held in ipairs(G.hand.cards) do
					if not held.debuff and SMODS.has_enhancement(held, "m_gold") then
						gold_count = gold_count + 1
					end
				end
				PVP.TRAP.reveal_and_consume(card)
				return PVP.TRAP.notify_owner(card, { dollars = gold_count * 4 })
			end
		end,
		receive = function(self, context)
			if context.data.owner ~= PVP.TRAP.self_id() then
				return
			end
			ease_dollars(context.data.dollars, true)
			PVP.UI.show_trap_fired_animation("Phase Door")
		end,
	},
	-- Mental Prison: when the holder fails to use a Wheel of Fortune they saw in a shop, create
	-- 2 Wheel of Fortunes. Deferred: needs new state-tracking (record Wheel of Fortune
	-- appearances per shop visit, checked at ending_shop) -- not a pure calculate-context check.
	-- Not yet implemented.
	{
		key = "trap_mental_prison",
		idea = "Virtualized",
		art = "Ganpan140",
		code = "Virtualized",
	},
}

-- One shared "Trap" sheet holds every trap's art in a single row, in TRAPS order: a trap's
-- column is its index here, so append new traps at the end. Malverk needs one atlas per
-- set under the bare set name, so the atlas key is unprefixed.
SMODS.Atlas({
	key = "Trap",
	path = "Trap.png",
	px = 71,
	py = 95,
	prefix_config = { key = false },
})

for index, def in ipairs(TRAPS) do
	MPAPI.Consumable({
		key = def.key,
		set = "Trap",
		atlas = "Trap",
		pos = { x = index - 1, y = 0 },
		prefix_config = { atlas = false },
		cost = 4,
		unlocked = true,
		discovered = true,
		-- A trap is usable only while it sits in a booster pack: USE there plants it. Once
		-- disguised in someone's inventory it is never clicked; it fires passively via calculate.
		can_use = function(self, card)
			return card.area == G.pack_cards
		end,
		-- Fires exactly once: the moment this card is drafted from a Trap pack (see
		-- lib/trap_utils.lua's PVP.TRAP.plant for why this is the sole, exact interception point).
		use = function(self, card, area, copier)
			PVP.TRAP.plant(card)
		end,
		calculate = PVP.TRAP.fire_once(def.calculate),
		receive = def.receive,
		mp_credits = {
			idea = { def.idea } or nil,
			art = { def.art } or nil,
			code = { def.code } or nil,
		},
	})
end
