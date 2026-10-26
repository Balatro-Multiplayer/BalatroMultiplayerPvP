-- Shared Pockets: hand, jokers and consumables share one pool of slots.
function PVP.setup_shared_pockets(areas_ready)
	if G.GAME.mp_shared_pockets then return end
	G.GAME.modifiers.mp_shared_pockets = true
	local shared = { count = 0 }
	if areas_ready then
		-- MPAPI applies layers after area creation; challenges apply before it.
		-- SMODS change_size takes effect on a later update, so capture the
		-- intended limits rather than reading the still-old card_limit back.
		shared.joker_limit = G.jokers.config.card_limit + 1e5
		shared.consumable_limit = G.consumeables.config.card_limit + 1e5
		G.jokers:change_size(1e5)
		G.consumeables:change_size(1e5)
		G.hand:change_size(7)
		G.jokers:handle_card_limit()
		G.consumeables:handle_card_limit()
	else
		local params = G.GAME.starting_params
		params.joker_slots = params.joker_slots + 1e5
		params.consumable_slots = params.consumable_slots + 1e5
		params.hand_size = params.hand_size + 7
		shared.joker_limit = params.joker_slots
		shared.consumable_limit = params.consumable_slots
	end
	G.GAME.mp_shared_pockets = shared
end

MPAPI.Layer("shared_pockets", {
	banned_jokers = {
		"j_stencil",
	},
	calculate = function(self, context)
		if context.apply_bans then PVP.setup_shared_pockets(true) end
	end,
})

-- just copy what vanilla does
local cardarea_update_ref = CardArea.update
function CardArea:update(dt)
	if self == G.hand then
		if G.GAME.modifiers.mp_shared_pockets then
			self.config.mp_last_size = self.config.mp_last_size or 0
			local shared = G.GAME.mp_shared_pockets
			local slots = (G.jokers.config.card_count - (G.jokers.config.card_limit - (shared.joker_limit or 100005)))
				+ (
					G.consumeables.config.card_count
					- (G.consumeables.config.card_limit - (shared.consumable_limit or 100002))
				)
			if slots ~= self.config.mp_last_size then
				self:change_size(self.config.mp_last_size - slots)
				self.config.mp_last_size = slots
			end
		end
	end
	local ret = cardarea_update_ref(self, dt)
	if G.GAME.modifiers.mp_shared_pockets then
		G.GAME.mp_shared_pockets.count = G.hand.config.card_count
			+ G.jokers.config.card_count
			+ G.consumeables.config.card_count
		G.GAME.mp_shared_pockets.limit = G.hand.config.card_limit
			+ G.jokers.config.card_count
			+ G.consumeables.config.card_count
	end
	return ret
end

-- ok look this might be a giant hack BUT
-- yeah i have nothing to say
-- whatever
local uie_update_text_ref = UIElement.update_text
function UIElement:update_text()
	if G.GAME.modifiers.mp_shared_pockets then
		if self.config.ref_value == "card_count" then
			if
				self.config.ref_table == G.hand.config
				or self.config.ref_table == G.jokers.config
				or self.config.ref_table == G.consumeables.config
			then
				self.config.ref_table = G.GAME.mp_shared_pockets
				self.config.ref_value = "count"
			end
		end
		if self.config.ref_value == "total_slots" then
			if
				self.config.ref_table == G.hand.config.card_limits
				or self.config.ref_table == G.jokers.config.card_limits
				or self.config.ref_table == G.consumeables.config.card_limits
			then
				self.config.ref_table = G.GAME.mp_shared_pockets
				self.config.ref_value = "limit"
			end
		end
	end
	local ret = uie_update_text_ref(self)
	return ret
end
