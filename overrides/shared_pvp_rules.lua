-- Compose explicit boss abilities with the PvP blind; never replace its
-- identity, target or referee. All callbacks preserve the original behavior.
local R = PVP.SHARED_RULES
local Round = R.Round

local function active()
	local round = Round.current()
	return round and round.phase == Round.Phase.ACTIVE
end

local set_blind = Blind.set_blind
function Blind:set_blind(blind, reset, ...)
	if R.reveal_id then
		G.FUNCS.exit_overlay_menu()
		R.reveal_id = nil
	end
	local result = set_blind(self, blind, reset, ...)
	if not reset then
		if PVP.is_pvp_boss() and not self.disabled then
			Round.activate()
		elseif PVP.is_pvp_boss() or active() then
			Round.finish()
		end
	end
	return result
end

local defeat = Blind.defeat
function Blind:defeat(...)
	if active() then Round.finish() end
	return defeat(self, ...)
end

-- Boss-disabling effects disable the shared rules too.
local disable = Blind.disable
function Blind:disable(...)
	if active() then Round.finish() end
	return disable(self, ...)
end

local set_text = Blind.set_text
function Blind:set_text(...)
	local result = set_text(self, ...)
	local round = Round.current()
	if round and round.phase ~= Round.Phase.FINISHED and PVP.is_pvp_boss() then
		for i, key in ipairs(round.rules) do
			local rule = R.definitions[key]
			self.loc_debuff_lines[i] = rule.label
			self.loc_debuff_text = self.loc_debuff_text .. " " .. rule.label .. ": " .. rule.text
		end
	end
	return result
end

local press_play = Blind.press_play
function Blind:press_play(...)
	local original = press_play(self, ...)
	local triggered = false
	for rule in R.in_force("press_play") do
		triggered = rule:press_play() or triggered
	end
	if triggered then return true end
	return original
end

local calculate_context = SMODS.calculate_context
-- Rules only add to SMODS's flags, so its immunity arbitration still decides.
local function apply_rules(context, flags, ...)
	if context.debuff_card then
		local card = context.debuff_card
		if card.area ~= G.jokers then
			for rule in R.in_force("recalc_debuff") do
				if rule:recalc_debuff(card) and not flags.prevent_debuff then flags.debuff = true end
			end
		end
	elseif context.debuff_hand then
		-- Called under prevent_debuff too: the Arm's level loss is not a debuff.
		for rule in R.in_force("debuff_hand") do
			local debuffed =
				rule:debuff_hand(context.full_hand, context.poker_hands, context.scoring_name, context.check)
			if debuffed and not flags.prevent_debuff then
				flags.debuff = true
				flags.debuff_text = flags.debuff_text or rule.text
			end
		end
	elseif context.stay_flipped then
		for rule in R.in_force("stay_flipped") do
			if rule:stay_flipped(context.to_area, context.other_card, context.from_area) then
				flags.stay_flipped = true
			end
		end
	end
	return flags, ...
end

function SMODS.calculate_context(context, ...)
	-- Before the original: Verdant Leaf depends on that order.
	for rule in R.in_force("calculate") do
		rule:calculate(context)
	end
	return apply_rules(context, calculate_context(context, ...))
end

local trigger_effect = Back.trigger_effect
function Back:trigger_effect(args)
	local chips, mult = trigger_effect(self, args)
	if args and args.context == "final_scoring_step" then
		for rule in R.in_force("final_scoring_step") do
			chips, mult = rule:final_scoring_step(chips or args.chips, mult or args.mult)
		end
	end
	return chips, mult
end

local cash_out = G.FUNCS.cash_out
function G.FUNCS.cash_out(...)
	Round.finish()
	return cash_out(...)
end

local go_to_menu = G.FUNCS.go_to_menu
function G.FUNCS.go_to_menu(...)
	Round.reset()
	R.reveal_id = nil
	return go_to_menu(...)
end
