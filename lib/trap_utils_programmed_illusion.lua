-- Programmed Illusion. Card:open reads the pack size in a later event, so growing the opened pack's
-- `extra` by one makes vanilla build the fake as the pack's last card, with the pack's own card
-- generator. Only the Nemesis builds it, so the pseudorandom streams and the used-jokers pool marks
-- (Card:set_ability writes G.GAME.used_jokers for the fake) are saved before it is built and
-- restored after: every other client's pack and pools stay in sync.
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

local function copy_table(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = value
	end
	return copy
end

local function restore_table(target, saved)
	for key in pairs(target) do
		target[key] = nil
	end
	for key, value in pairs(saved) do
		target[key] = value
	end
end

local illusion_saved

local function save_illusion_state()
	illusion_saved = { pseudorandom = copy_table(G.GAME.pseudorandom), used_jokers = copy_table(G.GAME.used_jokers) }
end

local function restore_illusion_state()
	restore_table(G.GAME.pseudorandom, illusion_saved.pseudorandom)
	restore_table(G.GAME.used_jokers, illusion_saved.used_jokers)
	illusion_saved = nil
end

local calculate_context_ref = SMODS.calculate_context
function SMODS.calculate_context(context, return_table, no_resolve)
	if not PVP.in_session() then
		return calculate_context_ref(context, return_table, no_resolve)
	end
	local booster = type(context) == "table" and context.booster
	local is_fake_slot = booster and booster.ability and booster.ability.mp_illusion_index == context.index
	if is_fake_slot and context.create_booster_card then
		save_illusion_state()
	end
	local result = calculate_context_ref(context, return_table, no_resolve)
	if is_fake_slot and context.modify_booster_card and illusion_saved then
		restore_illusion_state()
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
	if not PVP.in_session() then
		return use_card_ref(e, mute, nosave)
	end
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
