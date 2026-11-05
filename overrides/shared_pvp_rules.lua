-- Compose explicit boss abilities with the PvP blind; never replace its
-- identity, target or referee. All callbacks preserve the original behavior.
local R = PVP.SHARED_RULES
local set_blind = Blind.set_blind
function Blind:set_blind(blind, reset, ...)
	if R.reveal_id then
		G.FUNCS.exit_overlay_menu()
		R.reveal_id = nil
	end
	local result = set_blind(self, blind, reset, ...)
	if not reset then
		if PVP.is_pvp_boss() and not self.disabled then
			R.activate()
		elseif G.GAME.pvp_shared_rules and G.GAME.pvp_shared_rules.active then
			R.finish()
		elseif PVP.is_pvp_boss() and self.disabled then
			R.finish()
		end
	end
	return result
end

local defeat = Blind.defeat
function Blind:defeat(...)
	if G.GAME.pvp_shared_rules and G.GAME.pvp_shared_rules.active then R.finish() end
	return defeat(self, ...)
end

-- Boss-disabling effects disable the encounter rules too, restoring capacity.
local disable = Blind.disable
function Blind:disable(...)
	if G.GAME.pvp_shared_rules and G.GAME.pvp_shared_rules.active then R.finish() end
	return disable(self, ...)
end

local set_text = Blind.set_text
function Blind:set_text(...)
	local result = set_text(self, ...)
	local state = G.GAME and G.GAME.pvp_shared_rules
	if state and not state.finished and PVP.is_pvp_boss() then
		for i, key in ipairs(state.rules) do
			local def = R.definitions[key]
			self.loc_debuff_lines[i] = def.label
			self.loc_debuff_text = self.loc_debuff_text .. " " .. def.label .. ": " .. def.text
		end
	end
	return result
end

local debuff_hand = Blind.debuff_hand
function Blind:debuff_hand(cards, hand, handname, check, ...)
	if R.has("arm") and not check and G.GAME.hands[handname].level > 1 then
		level_up_hand(self.children.animatedSprite, handname, nil, -1)
	end
	return debuff_hand(self, cards, hand, handname, check, ...)
end

local press_play = Blind.press_play
function Blind:press_play(...)
	local original = press_play(self, ...)
	local state = G.GAME.pvp_shared_rules
	local tooth = R.has("tooth")
	if tooth then
		-- draw_card transfers are queued before press_play. Count G.play only
		-- after those transfers, as the vanilla Tooth does.
		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = 0.2,
			func = function()
				if G.GAME.pvp_shared_rules == state and R.has("tooth") then ease_dollars(-#G.play.cards) end
				return true
			end,
		}))
	end
	if R.has("hook") then
		G.E_MANAGER:add_event(Event({
			func = function()
				-- An event from an encounter that already ended must not discard
				-- cards in the next one.
				if G.GAME.pvp_shared_rules ~= state or not R.has("hook") then return true end
				local pool = {}
				for _, card in ipairs(G.hand.cards) do
					pool[#pool + 1] = card
				end
				for _ = 1, math.min(2, #pool) do
					local card, index = pseudorandom_element(pool, pseudoseed("hook"))
					G.hand:add_to_highlighted(card, true)
					table.remove(pool, index)
				end
				if #pool < #G.hand.cards then G.FUNCS.discard_cards_from_highlighted(nil, true) end
				return true
			end,
		}))
		delay(0.7)
		return true
	end
	if tooth then return true end
	return original
end

local calculate_context = SMODS.calculate_context
local suits = { club = "Clubs", goad = "Spades", window = "Diamonds", head = "Hearts" }
local function rule_flags(context, flags, ...)
	-- Use SMODS's existing arbitration: immunity/prevent flags still win.
	-- Do not override its final decision by setting card.debuff afterwards.
	if context.debuff_card and not flags.prevent_debuff then
		local card = context.debuff_card
		if card.area ~= G.jokers then
			if R.has("leaf") and not G.GAME.pvp_shared_rules.leaf_sold then flags.debuff = true end
			for key, suit in pairs(suits) do
				if R.has(key) and card:is_suit(suit, true) then flags.debuff = true end
			end
			if R.has("plant") and card:is_face(true) then flags.debuff = true end
		end
	elseif context.debuff_hand and not flags.prevent_debuff and R.has("psychic") and #context.full_hand ~= 5 then
		flags.debuff = true
		flags.debuff_text = flags.debuff_text or R.definitions.psychic.text
	elseif
		context.stay_flipped
		and context.to_area == G.hand
		and R.has("house")
		and G.GAME.current_round.hands_played == 0
		and G.GAME.current_round.discards_used == 0
	then
		flags.stay_flipped = true
	end
	return flags, ...
end

function SMODS.calculate_context(context, ...)
	if R.has("leaf") and context.selling_card and context.card and context.card.ability.set == "Joker" then
		G.GAME.pvp_shared_rules.leaf_sold = true
		R.refresh_debuffs()
	end
	return rule_flags(context, calculate_context(context, ...))
end

local trigger_effect = Back.trigger_effect
function Back:trigger_effect(args)
	local chips, mult = trigger_effect(self, args)
	if args and args.context == "final_scoring_step" and R.has("glass_cannon") then
		return chips, (mult or args.mult) * 4
	end
	return chips, mult
end

local cash_out = G.FUNCS.cash_out
function G.FUNCS.cash_out(...)
	R.finish()
	return cash_out(...)
end

local go_to_menu = G.FUNCS.go_to_menu
function G.FUNCS.go_to_menu(...)
	R.finish()
	R.starting_id, R.offer, R.reveal_id, R.pending_start = nil, nil, nil, nil
	return go_to_menu(...)
end
