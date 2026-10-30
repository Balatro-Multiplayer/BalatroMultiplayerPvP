-- The trap itself answers only one destroy_card context (fire_once), so a trap that must break
-- several cards marks them with mp_trap_break and the cards answer for themselves.
local calculate_enhancement_ref = Card.calculate_enhancement
function Card:calculate_enhancement(context)
	if not PVP.in_session() then
		return calculate_enhancement_ref(self, context)
	end
	if self.ability and self.ability.mp_trap_break and context.destroy_card == self and context.cardarea == G.play then
		return { remove = true }
	end
	return calculate_enhancement_ref(self, context)
end

-- The destroy pass is over by context.after, so a marked card that survived it must not break later.
local calculate_context_ref = SMODS.calculate_context
function SMODS.calculate_context(context, return_table, no_resolve)
	local result = calculate_context_ref(context, return_table, no_resolve)
	if PVP.in_session() and type(context) == "table" and context.after then
		for _, played in ipairs(context.full_hand or {}) do
			played.ability.mp_trap_break = nil
		end
	end
	return result
end
