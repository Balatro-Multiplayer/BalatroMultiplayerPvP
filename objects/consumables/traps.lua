-- Trap: a consumable type that reacts to something your Nemesis does. A Trap can only be
-- taken from a Trap booster pack (objects/boosters/traps.lua); taking one plants it,
-- face-down, in the Trapper's Nemesis's own consumables instead of the Trapper's (the server
-- records the plant, see lib/trap_utils.lua's PVP.TRAP.plant/build/disguise). When the Nemesis's own action
-- satisfies the trap's trigger, it reveals itself on their screen, reports the fire to the server with
-- PVP.TRAP.fire, and its effect benefits the ORIGINAL Trapper -- who also gets a "use" animation on their own
-- screen. The Trapper pays the reward once from the server's record (pvp_api/traps_net.lua), through the
-- `reward` handler of the card below. See lib/trap_utils.lua for the shared plant/disguise/reveal/fire
-- framework every card below reuses, and the layer that gates when these can spawn at all in layers/traps.lua.
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

local ALARM_REROLLS = 2
local PHASE_DOOR_DOLLARS_PER_GOLD = 4
local MAX_PHASE_DOOR_GOLDS = 30

-- The owner's own check of a fired trap's data against the game's tables (the server checks only its shape).
local function is_rare_joker(center)
	return center ~= nil and center.set == "Joker" and (center.rarity == 3 or center.rarity == "Rare")
end

local function is_consumable_set(set)
	return SMODS.ConsumableTypes[set] ~= nil and set ~= "Trap"
end

local TRAPS = {
	-- Glyph of Warding: when the Nemesis uses a Spectral card, the Trapper gets a Ward Tag
	-- (objects/tags/ward.lua), which opens a Jumbo Spectral pack at the next blind choice.
	{
		key = "trap_glyph_of_warding",
		idea = "Virtualized",
		art = "OvertLeaf4",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.using_consumeable and context.consumeable.config.center.set == "Spectral" then
				PVP.TRAP.fire(card)
			end
		end,
		reward = function(data)
			add_tag(Tag("tag_mp_ward"))
			PVP.UI.show_trap_fired_animation("Glyph of Warding")
		end,
	},
	-- Symbol: when the Nemesis plays a flush, convert all scored cards to random suits.
	{
		key = "trap_symbol",
		idea = "Virtualized",
		art = "OvertLeaf4",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.before and context.poker_hands and next(context.poker_hands["Flush"]) then
				for _, scored in ipairs(context.scoring_hand or {}) do
					local suit = pseudorandom_element({ "Spades", "Hearts", "Clubs", "Diamonds" }, pseudoseed("mp_trap_symbol"))
					scored:change_suit(suit)
				end
				PVP.TRAP.fire(card)
			end
		end,
		reward = function(data)
			PVP.UI.show_trap_fired_animation("Symbol")
		end,
	},
	-- Alarm: when the Nemesis rerolls their shop, the Trapper gains 2 free rerolls (now in a shop, else at the next shop).
	-- The count is this mod's own: ALARM_REROLLS, whatever the fired data holds.
	{
		key = "trap_alarm",
		idea = "Virtualized",
		art = "Zwei",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.reroll_shop then
				PVP.TRAP.fire(card)
			end
		end,
		reward = function()
			PVP.TRAP.grant_free_rerolls(ALARM_REROLLS)
			PVP.UI.show_trap_fired_animation("Alarm")
		end,
	},
	-- Explosive Runes: when the Nemesis plays a hand with a glass card, every scored glass card
	-- breaks after it scores.
	{
		key = "trap_explosive_runes",
		idea = "Virtualized",
		art = "shai1n",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.before then
				local armed = false
				for _, scored in ipairs(context.scoring_hand or {}) do
					if not scored.debuff and SMODS.has_enhancement(scored, "m_glass") then
						scored.ability.mp_trap_break = true
						armed = true
					end
				end
				if armed then
					PVP.TRAP.fire(card)
				end
			end
		end,
		reward = function(data)
			PVP.UI.show_trap_fired_animation("Explosive Runes")
		end,
	},
	-- Sepia Snake Sigil: when the Nemesis buys a Rare Joker, the Trapper gains a copy of it.
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
				PVP.TRAP.fire(card, { key = context.card.config.center.key })
			end
		end,
		reward = function(data)
			if not is_rare_joker(G.P_CENTERS[data.key]) then return false, "not a Rare Joker: " .. tostring(data.key) end
			-- The copy needs a free Joker slot, else it is lost.
			if #G.jokers.cards + G.GAME.joker_buffer < G.jokers.config.card_limit then
				-- set required -- SMODS.add_card never infers it from the target center.
				SMODS.add_card({ key = data.key, set = "Joker", area = G.jokers })
			end
			PVP.UI.show_trap_fired_animation("Sepia Snake Sigil")
		end,
	},
	-- Fire Trap: when the Nemesis plays a hand with a pair, decrease the rank of all scored
	-- cards by 1.
	{
		key = "trap_fire_trap",
		idea = "Virtualized",
		art = "Ganpan140",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.before and context.poker_hands and next(context.poker_hands["Pair"]) then
				for _, scored in ipairs(context.scoring_hand or {}) do
					PVP.TRAP.decrease_rank(scored)
				end
				PVP.TRAP.fire(card)
			end
		end,
		reward = function(data)
			PVP.UI.show_trap_fired_animation("Fire Trap")
		end,
	},
	-- Guards and Wards: when the Nemesis adds a playing card to their deck, add 2 Stone cards
	-- to their deck.
	{
		key = "trap_guards_and_wards",
		idea = "Virtualized",
		art = "Nas4xou",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.playing_card_added then
				-- Added here, on the Nemesis's client. create_playing_card sends no
				-- playing_card_added context itself, so the Stone cards cannot re-trigger.
				for _ = 1, 2 do
					create_playing_card({
						front = pseudorandom_element(G.P_CARDS, pseudoseed("mp_trap_guards")),
						center = G.P_CENTERS.m_stone,
					}, G.deck)
				end
				PVP.TRAP.fire(card)
			end
		end,
		reward = function(data)
			PVP.UI.show_trap_fired_animation("Guards and Wards")
		end,
	},
	-- Magic Mouth: when the Nemesis triggers a blue or purple seal, steal the consumable.
	-- No calculate: the trigger is hooked in lib/trap_utils_magic_mouth.lua, which fires with the key of the stolen card.
	{
		key = "trap_magic_mouth",
		idea = "Virtualized",
		art = "TypeFate",
		code = "Virtualized",
		reward = function(data)
			local center = G.P_CENTERS[data.key]
			if not (center and (center.set == "Tarot" or center.set == "Planet")) then
				return false, "not a Tarot or Planet card: " .. tostring(data.key)
			end
			-- Counts the buffer too, so a card still being made does not leave the area over its limit.
			local has_room = #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit
			if has_room then
				SMODS.add_card({ key = data.key, set = center.set, area = G.consumeables })
			end
			PVP.UI.show_trap_fired_animation("Magic Mouth")
		end,
	},
	-- Snare: when the Nemesis skips a blind, the Trapper gains a copy of the tag they got.
	{
		key = "trap_snare",
		idea = "Virtualized",
		art = "Ganpan140",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.skip_blind then
				-- Recorded by lib/trap_utils_snare.lua: other tags may be added before this context runs.
				local tag_key = G.GAME.mp_skipped_tag_key
				if not tag_key then
					-- As before: the trap is spent and pays nothing; the server is told it was lost.
					PVP.match_log("info", "[pvp] snare fired with no recorded tag")
					return PVP.TRAP.fire_unpaid(card)
				end
				local data = { tag_key = tag_key }
				-- Only an Orbital Tag carries its poker hand.
				if tag_key == "tag_orbital" then data.orbital_hand = G.GAME.mp_skipped_orbital_hand end
				PVP.TRAP.fire(card, data)
			end
		end,
		reward = function(data)
			if not G.P_TAGS[data.tag_key] then return false, "no such tag: " .. tostring(data.tag_key) end
			if data.tag_key == "tag_orbital" and not G.GAME.hands[data.orbital_hand] then
				return false, "no such hand: " .. tostring(data.orbital_hand)
			end
			-- Same as the Double Tag: the copy keeps the original's poker hand.
			G.orbital_hand = data.orbital_hand
			local copy = Tag(data.tag_key)
			G.orbital_hand = nil
			add_tag(copy)
			-- add_tag does not run a tag that acts at once (Economy, Orbital, ...): vanilla only does that
			-- on a skip, which the Trapper has not made.
			copy:apply_to_run({ type = "immediate" })
			PVP.UI.show_trap_fired_animation("Snare")
		end,
	},
	-- Arcane Lock: the next Trap card the Nemesis takes from a Trap pack goes face-down into their
	-- own consumables, and this card's Trapper becomes its Trapper. The server does the bounce when it
	-- records the plant (the lock fires with {bounced = new id}), so there is no calculate.
	{
		key = "trap_arcane_lock",
		idea = "Virtualized",
		art = "shai1n",
		code = "Virtualized",
		reward = function(data)
			PVP.UI.show_trap_fired_animation("Arcane Lock")
		end,
	},
	-- Programmed Illusion: when the Nemesis opens a booster pack, one extra card of the pack's type is added.
	-- Picking it uses a pick, then it dissolves and gives nothing (lib/trap_utils_programmed_illusion.lua).
	{
		key = "trap_programmed_illusion",
		idea = "Virtualized",
		art = "TypeFate",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.open_booster and PVP.TRAP.add_illusion_slot(context.card) then
				PVP.TRAP.fire(card)
			end
		end,
		reward = function(data)
			PVP.UI.show_trap_fired_animation("Programmed Illusion")
		end,
	},
	-- Web: when the Nemesis uses any consumable, the Trapper gains a negative copy of it.
	{
		key = "trap_web",
		idea = "Virtualized",
		art = "Ganpan140",
		code = "Virtualized",
		calculate = function(self, card, context)
			-- A Trap card taken from a Trap pack is a plant, not a use: a copy would be a dead card.
			if context.using_consumeable and context.consumeable.config.center.set ~= "Trap" then
				-- `set` must travel with the key: unlike sepia_snake_sigil/glyph_of_warding
				-- (always one fixed type), Web can copy ANY consumable set (Tarot/Planet/
				-- Spectral), and SMODS.add_card never infers `set` from the target center.
				PVP.TRAP.fire(card, { key = context.consumeable.config.center.key, set = context.consumeable.config.center.set })
			end
		end,
		reward = function(data)
			local center = G.P_CENTERS[data.key]
			if not (center and center.set == data.set and is_consumable_set(data.set)) then
				return false, "not a consumable of set " .. tostring(data.set) .. ": " .. tostring(data.key)
			end
			SMODS.add_card({ key = data.key, set = data.set, area = G.consumeables, edition = "e_negative" })
			PVP.UI.show_trap_fired_animation("Web")
		end,
	},
	-- Forbiddance: when the Nemesis discards, the cards drawn to refill their hand come in
	-- face-down. It acts outside calculate (see lib/trap_utils_forbiddance.lua).
	{
		key = "trap_forbiddance",
		idea = "Virtualized",
		art = "shai1n",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.setting_blind then
				PVP.TRAP.disarm_forbiddance(card)
			end
		end,
		reward = function(data)
			PVP.UI.show_trap_fired_animation("Forbiddance")
		end,
	},
	-- Faithful Hound: when the Nemesis uses a Planet card, the Trapper gains 3 levels of that
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
					PVP.TRAP.fire(card, { hand_type = hand_type })
				end
			end
		end,
		reward = function(data)
			if not G.GAME.hands[data.hand_type] then return false, "no such hand: " .. tostring(data.hand_type) end
			level_up_hand(nil, data.hand_type, true, 3)
			PVP.UI.show_trap_fired_animation("Faithful Hound")
		end,
	},
	-- Phase Door: when the Nemesis's held gold cards pay out at end of round, the Trapper gains $4
	-- per gold card in their hand. The firing client sends the count of gold cards as `golds`; the dollars are
	-- computed here, and a count that is not a whole number from 1 to MAX_PHASE_DOOR_GOLDS pays nothing.
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
				PVP.TRAP.fire(card, { golds = gold_count })
			end
		end,
		reward = function(data)
			local golds = data and data.golds
			if type(golds) ~= "number" or golds ~= math.floor(golds) or golds < 1 or golds > MAX_PHASE_DOOR_GOLDS then
				return false, "no gold count: " .. tostring(golds)
			end
			ease_dollars(golds * PHASE_DOOR_DOLLARS_PER_GOLD, true)
			PVP.UI.show_trap_fired_animation("Phase Door")
		end,
	},
	-- Mental Prison: when the Nemesis leaves a Wheel of Fortune in the shop or a pack (skipped,
	-- picks used up elsewhere, shop left or rerolled), the Trapper gets 2 Wheel of Fortunes. Leaving
	-- the shop is handled here; the pack and reroll cases are hooked in lib/trap_utils_mental_prison.lua.
	{
		key = "trap_mental_prison",
		idea = "Virtualized",
		art = "Ganpan140",
		code = "Virtualized",
		calculate = function(self, card, context)
			if context.ending_shop and PVP.TRAP.area_holds_wheel(G.shop_jokers) then
				PVP.TRAP.fire(card)
			end
		end,
		reward = function(data)
			for _ = 1, 2 do
				-- Counts the buffer too, so cards still being made do not leave the area over its limit.
				if #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit then
					G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
					G.E_MANAGER:add_event(Event({
						trigger = "before",
						delay = 0.0,
						func = function()
							-- Built directly: SMODS.add_card / create_card would poll shared pseudorandom streams.
							local wheel = Card(
								G.consumeables.T.x,
								G.consumeables.T.y,
								G.CARD_W,
								G.CARD_H,
								nil,
								G.P_CENTERS.c_wheel_of_fortune
							)
							wheel:add_to_deck()
							G.consumeables:emplace(wheel)
							G.GAME.consumeable_buffer = math.max(0, G.GAME.consumeable_buffer - 1)
							return true
						end,
					}))
				end
			end
			PVP.UI.show_trap_fired_animation("Mental Prison")
		end,
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
		-- Fires exactly once: the moment this card is taken from a Trap pack (see
		-- lib/trap_utils.lua's PVP.TRAP.plant for why this is the sole, exact interception point).
		use = function(self, card, area, copier)
			PVP.TRAP.plant(card)
		end,
		calculate = PVP.TRAP.fire_once(def.calculate),
		mp_credits = {
			idea = { def.idea } or nil,
			art = { def.art } or nil,
			code = { def.code } or nil,
		},
	})
	-- The owner's reward, by the card's full center key ("c_" and the mod prefix).
	PVP.TRAP.REWARDS["c_mp_" .. def.key] = def.reward
end
