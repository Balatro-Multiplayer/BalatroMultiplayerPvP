-- Forbiddance acts on the refill draw that follows a discard, which is a draw_card call with no
-- calculate context to answer. A discard arms the trap, Blind:stay_flipped keeps the refill cards
-- face-down (a face-down card flips up when played, as for a vanilla boss blind), and an event
-- queued behind the refill draw disarms it and fires it, so later draws are face-up.
-- The armed flag is saved with the run, so a new blind also clears it (the trap's calculate).
function PVP.TRAP.disarm_forbiddance(trap)
	trap.ability.mp_forbiddance_armed = nil
	trap.ability.mp_forbiddance_flipped = nil
end

local function armed_forbiddance()
	local trap = PVP.TRAP.find_planted(PVP.TRAP.KEY.FORBIDDANCE)
	return trap and trap.ability.mp_forbiddance_armed and trap
end

local discard_cards_ref = G.FUNCS.discard_cards_from_highlighted
function G.FUNCS.discard_cards_from_highlighted(e, is_hook_blind)
	if not PVP.in_session() then
		return discard_cards_ref(e, is_hook_blind)
	end
	local trap = not is_hook_blind and #G.hand.highlighted > 0 and PVP.TRAP.find_planted(PVP.TRAP.KEY.FORBIDDANCE)
	local result = discard_cards_ref(e, is_hook_blind)
	-- A blind-forced discard sets no draw state, so only a player discard is followed by a refill.
	if trap and G.STATE == G.STATES.DRAW_TO_HAND then
		trap.ability.mp_forbiddance_armed = true
		trap.ability.mp_forbiddance_flipped = 0
	end
	return result
end

local stay_flipped_ref = Blind.stay_flipped
function Blind:stay_flipped(to_area, card, from_area)
	if not PVP.in_session() then
		return stay_flipped_ref(self, to_area, card, from_area)
	end
	local trap = to_area == G.hand and from_area == G.deck and armed_forbiddance()
	if trap then
		trap.ability.mp_forbiddance_flipped = trap.ability.mp_forbiddance_flipped + 1
		return true
	end
	return stay_flipped_ref(self, to_area, card, from_area)
end

local draw_from_deck_to_hand_ref = G.FUNCS.draw_from_deck_to_hand
function G.FUNCS.draw_from_deck_to_hand(e)
	if not PVP.in_session() then
		return draw_from_deck_to_hand_ref(e)
	end
	local trap = armed_forbiddance()
	local result = draw_from_deck_to_hand_ref(e)
	if trap then
		G.E_MANAGER:add_event(Event({
			trigger = "immediate",
			func = function()
				-- An empty deck refills nothing: the trap stays hidden for the next discard.
				local flipped = trap.ability.mp_forbiddance_flipped or 0
				PVP.TRAP.disarm_forbiddance(trap)
				if flipped > 0 and not trap.ability.mp_trap_fired then
					PVP.TRAP.fire(trap, {})
				end
				return true
			end,
		}))
	end
	return result
end
