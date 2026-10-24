-- Pre-compile a reversed list of all the centers
local reversed_centers = nil

function PVP.UTILS.card_to_string(card)
	if not card or not card.base or not card.base.suit or not card.base.value then return "" end

	if not reversed_centers then reversed_centers = PVP.UTILS.reverse_key_value_pairs(G.P_CENTERS) end

	local suit = string.sub(card.base.suit, 1, 1)

	local rank_value_map = {
		["10"] = "T",
		Jack = "J",
		Queen = "Q",
		King = "K",
		Ace = "A",
	}
	local rank = rank_value_map[card.base.value] or card.base.value

	local enhancement = reversed_centers[card.config.center] or "none"
	local edition = card.edition and PVP.UTILS.reverse_key_value_pairs(card.edition, true)["true"] or "none"
	local seal = card.seal or "none"

	local card_str = suit .. "-" .. rank .. "-" .. enhancement .. "-" .. edition .. "-" .. seal

	return card_str
end

function PVP.UTILS.joker_to_string(card)
	if not card or not card.config or not card.config.center or not card.config.center.key then return "" end

	local edition = card.edition and PVP.UTILS.reverse_key_value_pairs(card.edition, true)["true"] or "none"
	local eternal_or_perishable = "none"
	if card.ability then
		if card.ability.eternal then
			eternal_or_perishable = "eternal"
		elseif card.ability.perishable then
			eternal_or_perishable = "perishable"
		end
	end
	local rental = (card.ability and card.ability.rental) and "rental" or "none"

	local joker_string = card.config.center.key .. "-" .. edition .. "-" .. eternal_or_perishable .. "-" .. rental

	return joker_string
end

-- Stable area enum for the carbon replay stream. The int identifies WHICH
-- CardArea a positional index refers to, independent of card identity/name.
PVP.UTILS.AREA = {
	shop_jokers = 1,
	shop_booster = 2,
	shop_vouchers = 3,
	jokers = 4,
	consumeables = 5,
	hand = 6,
	pack_cards = 7,
}

-- Map a live CardArea object to its stable AREA enum int (or nil if unknown).
function PVP.UTILS.area_enum(area)
	if not area or not G then return nil end
	-- Compare directly instead of building a lookup table keyed by the CardArea
	-- globals: several of them are nil depending on game state (G.pack_cards
	-- only exists while a booster is open, G.shop_* only in the shop), and a
	-- table literal with a nil key throws "table index is nil". Comparing a
	-- live area against a nil global is simply false, so this is crash-safe.
	if area == G.shop_jokers then return PVP.UTILS.AREA.shop_jokers end
	if area == G.shop_booster then return PVP.UTILS.AREA.shop_booster end
	if area == G.shop_vouchers then return PVP.UTILS.AREA.shop_vouchers end
	if area == G.jokers then return PVP.UTILS.AREA.jokers end
	if area == G.consumeables then return PVP.UTILS.AREA.consumeables end
	if area == G.hand then return PVP.UTILS.AREA.hand end
	if area == G.pack_cards then return PVP.UTILS.AREA.pack_cards end
	return nil
end

-- 1-based index of a card within its CardArea's card list. `area` defaults to
-- card.area. Returns nil if the card is not found. This positional index is the
-- deterministic reference used by the carbon stream (never card.sort_id, which
-- is a per-run counter that won't match across a re-simulation).
function PVP.UTILS.index_in_area(card, area)
	area = area or (card and card.area)
	if not card or not area or not area.cards then return nil end
	for i = 1, #area.cards do
		if area.cards[i] == card then return i end
	end
	return nil
end

-- 1-based G.hand indices of the currently highlighted cards, ascending. Shared
-- by play/discard/consumable-target instrumentation so every hand reference in
-- the carbon stream is a deterministic positional index list.
function PVP.UTILS.highlighted_hand_indices()
	local out = {}
	if not (G and G.hand and G.hand.highlighted) then return out end
	for _, c in ipairs(G.hand.highlighted) do
		local i = PVP.UTILS.index_in_area(c, G.hand)
		if i then out[#out + 1] = i end
	end
	table.sort(out)
	return out
end

-- Given the previous order (a list of card sort_ids) and the current cards,
-- return the new order expressed as a list of the cards' PREVIOUS 1-based
-- indices -- i.e. the permutation a replay applies to reproduce the reorder.
-- Returns nil if it is not a pure reorder (the card set changed) or if nothing
-- moved. Referencing previous indices (not sort_id) keeps the carbon stream
-- positional and replayable.
function PVP.UTILS.reorder_permutation(old_ids, cards)
	if not old_ids or not cards or #cards == 0 or #old_ids ~= #cards then return nil end
	local pos = {}
	for i = 1, #old_ids do
		pos[old_ids[i]] = i
	end
	local perm = {}
	local changed = false
	for j = 1, #cards do
		local oi = pos[cards[j].sort_id]
		if not oi then return nil end -- a card is new/removed: not a pure reorder
		perm[j] = oi
		if oi ~= j then changed = true end
	end
	if not changed then return nil end
	return perm
end

function PVP.UTILS.get_phantom_joker(key)
	if not PVP.shared or not PVP.shared.cards then return nil end
	for i = 1, #PVP.shared.cards do
		if
			PVP.shared.cards[i].ability.name == key
			and PVP.shared.cards[i].edition
			and PVP.shared.cards[i].edition.type == "mp_phantom"
		then
			return PVP.shared.cards[i]
		end
	end
	return nil
end

function PVP.UTILS.run_for_each_phantom_joker(key, func)
	if not PVP.shared or not PVP.shared.cards then return end
	for i = 1, #PVP.shared.cards do
		if PVP.shared.cards[i].ability.name == key then func(PVP.shared.cards[i]) end
	end
end

function PVP.UTILS.get_deck_key_from_name(_name)
	for k, v in pairs(G.P_CENTERS) do
		if v.name == _name then return k end
	end
end

-- Drives the grim/familiar/incantation lovely patch. Returns center *objects*
-- (not keys) to match the vanilla loop body the patch slots into.
function PVP.UTILS.get_spectral_enhancement_pool()
	local bans = PVP.current_ruleset().spectral_banned_enhancements
	local ban_set = {}
	if bans then
		for _, k in ipairs(bans) do
			ban_set[k] = true
		end
	end
	local ret = {}
	for _, v in pairs(G.P_CENTER_POOLS["Enhanced"]) do
		if not ban_set[v.key] then ret[#ret + 1] = v end
	end
	return ret
end
