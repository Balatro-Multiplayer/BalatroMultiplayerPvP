-- Polymorph Spam: every blind, your jokers and consumables re-roll into other centers.
MPAPI.Layer("polymorph_spam", {
	calculate = function(self, context)
		if context.apply_bans then G.GAME.modifiers.mp_polymorph_spam = true end
	end,
})

local function get_area(card)
	if not card then return end
	if card.config.center.set == "Joker" then
		return G.jokers
	elseif card.config.center.consumeable then
		return G.consumeables
	end
	return nil
end

local function get_pos(card)
	local area = get_area(card)
	for i, v in ipairs(area.cards) do
		if card == v then return i end
	end
	return nil
end

local function included(key)
	if G.GAME.banned_keys[key] then return false end
	return not MPAPI.should_exclude_from_pool(G.P_CENTERS[key])
end

-- Build the eligible ring once. An owned card can be banned or absent from
-- its pool; neither case may trap the game in a search for its own center.
local function transmutations(card, count)
	local pool = G.P_CENTER_POOLS[card.config.center.set] or {}
	local start
	for i, center in ipairs(pool) do
		if center == card.config.center then
			start = i
			break
		end
	end
	if not start then return {} end
	local ring = {}
	for offset = 1, #pool do
		local center = pool[(start + offset - 1) % #pool + 1]
		if included(center.key) then ring[#ring + 1] = center end
	end
	local result = {}
	if #ring == 0 then return result end
	for i = 1, count do
		result[i] = ring[(i - 1) % #ring + 1]
	end
	return result
end

local function get_transmutations_loc(card)
	local area, position = get_area(card), get_pos(card)
	local result = {}
	local count = math.min(area.config.card_limit, math.max(5, #area.cards))
	for i, center in ipairs(transmutations(card, count)) do
		result[#result + 1] = {
			strings = { localize({ type = "name_text", key = center.key, set = center.set }) },
			control = { C = i == position and "attention" or nil },
		}
	end
	return result
end

local function mass_polymorph(area)
	for _, card in ipairs(area) do
		local position = get_pos(card)
		local target = position and transmutations(card, position)[position]
		if target then
			card:remove_from_deck()
			card:set_ability(target)
			card:add_to_deck()
			card:set_cost()
		end
	end
end

local calculate_context_ref = SMODS.calculate_context
function SMODS.calculate_context(context, return_table, no_resolve)
	if G.GAME.modifiers.mp_polymorph_spam and context and type(context) == "table" and context.setting_blind then
		mass_polymorph(G.jokers.cards)
		mass_polymorph(G.consumeables.cards)
	end
	return calculate_context_ref(context, return_table, no_resolve)
end

local set_ability_ref = Card.set_ability
function Card:set_ability(center, initial, delay_sprites)
	local ret = set_ability_ref(self, center, initial, delay_sprites)
	if G.GAME.modifiers.mp_polymorph_spam and G.OVERLAY_MENU then
		if not included(center.key) then self.ability.perma_debuff = true end
	end
	return ret
end

local transmute_card = nil -- global local :thinking:

local generate_card_ui_ref = generate_card_ui
function generate_card_ui(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
	local ret =
		generate_card_ui_ref(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
	if G.GAME.modifiers.mp_polymorph_spam then
		if card and card.config.center then -- check for card and for tag
			if get_area(card) and included(card.config.center.key) then
				transmute_card = card -- whatever, surely won't break
				generate_card_ui_ref({ key = "mp_transmutations", set = "Other" }, ret) -- don't need to assign this to ret because lua
			end
		end
	end
	return ret
end

-- really inefficient and throws away a metric shit ton of tables
-- thanks to the advancements of my ancestors, i don't have to worry about it
local localize_ref = localize
function localize(args, misc_cat)
	if args and type(args) == "table" and args.key and args.key == "mp_transmutations" then -- really safe get
		local loc_target = G.localization.descriptions.Other.mp_transmutations.text_parsed
		for i = 2, #loc_target do
			table.remove(loc_target, 2)
		end
		local list = get_transmutations_loc(transmute_card)
		for i = 1, #list do
			loc_target[#loc_target + 1] = { list[i] }
		end
	end
	return localize_ref(args, misc_cat)
end
