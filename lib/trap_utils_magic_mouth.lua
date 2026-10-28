-- Seal rewards are made by direct Card method calls, never a calculate context, so Magic Mouth
-- hooks the two methods instead. A Blue or Purple Seal that fires always raises
-- consumeable_buffer (it only fires with room), which is how a trigger is told from a miss.
-- The reward card is made in a queued event; a later event queued here runs right after it,
-- takes the new card away from the Nemesis, and sends it to the Trapper.
local function steal_seal_reward(trap, cards_before)
	G.E_MANAGER:add_event(Event({
		trigger = "before",
		delay = 0,
		blockable = false,
		func = function()
			if trap.ability.mp_trap_fired then
				return true
			end
			local known = {}
			for _, held in ipairs(cards_before) do
				known[held] = true
			end
			for _, held in ipairs(G.consumeables.cards) do
				if not known[held] and held ~= trap then
					local stolen = MPAPI.serialize_card(held)
					G.consumeables:remove_card(held)
					held:remove()
					PVP.TRAP.fire(trap, { card = stolen })
					break
				end
			end
			return true
		end,
	}))
end

local function wrap_seal_method(method_name)
	local method_ref = Card[method_name]
	Card[method_name] = function(self, context)
		if not PVP.in_session() then
			return method_ref(self, context)
		end
		local trap = (self.seal == "Blue" or self.seal == "Purple") and PVP.TRAP.find_planted(PVP.TRAP.KEY.MAGIC_MOUTH)
		if not trap then
			return method_ref(self, context)
		end
		local cards_before = { unpack(G.consumeables.cards) }
		local buffer_before = G.GAME.consumeable_buffer
		local seal_effect, seal_extra = method_ref(self, context)
		if G.GAME.consumeable_buffer > buffer_before then
			steal_seal_reward(trap, cards_before)
		end
		return seal_effect, seal_extra
	end
end
wrap_seal_method("get_end_of_round_effect")
wrap_seal_method("calculate_seal")
