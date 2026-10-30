SMODS.Sticker({
	key = "sticker_persistent",
	atlas = "alt_stickers",
	pos = { x = 0, y = 0 },
	badge_colour = HEX("5541CC"),
	default_compat = false,
	needs_enable_flag = true,
	apply = function(self, card, val)
		if card and PVP.is_phantom(card) then return end
		old_val = card.ability.mp_sticker_persistent or false
		card.ability.mp_sticker_persistent = val
		if old_val ~= val then card:set_cost() end
	end,
	calculate = function(self, card, context)
		if context.end_of_round and not context.repetition and not context.individual then -- should be main_eval i think but i'm copying from vremade so cry about it
			card.ability.mp_extra_sell_price = (card.ability.mp_extra_sell_price or 0) + 3
			card_eval_status_text(
				card,
				"extra",
				nil,
				nil,
				nil,
				{ message = localize("k_cost_up"), colour = G.C.RED, delay = 0.45 }
			)
			card:set_cost()
		end
	end,
})

local is_eternal_ref = SMODS.is_eternal
function SMODS.is_eternal(card, trigger)
	local ret = is_eternal_ref(card, trigger)
	if card.ability.mp_sticker_persistent and not (trigger and trigger.from_sell) then ret = true end
	return ret
end

-- make sell button red
local can_sell_card_ref = G.FUNCS.can_sell_card
G.FUNCS.can_sell_card = function(e)
	if e.config.ref_table.ability and e.config.ref_table.ability.mp_sticker_persistent then
		if e.config.ref_table:can_sell_card() and e.config.ref_table.ability.mp_sell_price <= G.GAME.dollars then
			e.config.colour = G.C.RED
			e.config.button = "sell_card"
		else
			e.config.colour = G.C.UI.BACKGROUND_INACTIVE
			e.config.button = nil
		end
	else
		return can_sell_card_ref(e)
	end
end

-- replicate
-- :(
-- i don't like hooking like this
local sell_card_ref = Card.sell_card
function Card:sell_card()
	if not self.ability.mp_sticker_persistent then return sell_card_ref(self) end

	G.CONTROLLER.locks.selling_card = true
	stop_use()
	local area = self.area
	G.CONTROLLER:save_cardarea_focus(area == G.jokers and "jokers" or "consumeables")

	if self.children.use_button then
		self.children.use_button:remove()
		self.children.use_button = nil
	end
	if self.children.sell_button then
		self.children.sell_button:remove()
		self.children.sell_button = nil
	end

	self:calculate_joker({ selling_self = true })

	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0.2,
		func = function()
			self:juice_up(0.3, 0.4)
			return true
		end,
	}))
	delay(0.2)
	G.E_MANAGER:add_event(Event({
		trigger = "immediate",
		func = function()
			ease_dollars(-self.ability.mp_sell_price)
			self:start_dissolve({ G.C.RED })
			delay(0.3)

			inc_career_stat("c_cards_sold", 1)
			if self.ability.set == "Joker" then inc_career_stat("c_jokers_sold", 1) end
			if self.ability.set == "Joker" and G.GAME.blind and G.GAME.blind.name == "Verdant Leaf" then
				G.E_MANAGER:add_event(Event({
					trigger = "immediate",
					func = function()
						G.GAME.blind:disable()
						return true
					end,
				}))
			end
			G.E_MANAGER:add_event(Event({
				trigger = "after",
				delay = 0.3,
				blocking = false,
				func = function()
					G.E_MANAGER:add_event(Event({
						trigger = "immediate",
						func = function()
							G.E_MANAGER:add_event(Event({
								trigger = "immediate",
								func = function()
									G.CONTROLLER.locks.selling_card = nil
									G.CONTROLLER:recall_cardarea_focus(area == G.jokers and "jokers" or "consumeables")
									return true
								end,
							}))
							return true
						end,
					}))
					return true
				end,
			}))
			return true
		end,
	}))
end

local set_cost_ref = Card.set_cost
function Card:set_cost()
	set_cost_ref(self)
	if self.ability.mp_sticker_persistent then
		self.ability.mp_sell_price = self.sell_cost + (self.ability.mp_extra_sell_price or 0)
		self.sell_cost_label = self.facing == "back" and "?" or self.ability.mp_sell_price
	end
end

local update_ref = Card.update
function Card:update(dt)
	update_ref(self, dt)
	if self.ability and self.ability.mp_sticker_persistent then
		self.sell_cost_label = self.facing == "back" and "?" or self.ability.mp_sell_price
	end
end

local generate_card_ui_ref = generate_card_ui
function generate_card_ui(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
	local ret =
		generate_card_ui_ref(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
	if card and card.ability and card.ability.mp_sticker_persistent and not G.OVERLAY_MENU then -- check for card and for tag
		generate_card_ui_ref({ key = "mp_internal_sell_value", set = "Other", vars = { card.sell_cost } }, ret) -- don't need to assign this to ret because lua
	end
	return ret
end
