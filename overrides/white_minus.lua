-- Stakes apply before card areas exist. Give the vouchers through the run-start
-- event queue, after the selected back's setup, using the normal voucher effects.
local apply = Back.apply_to_run
function Back:apply_to_run(...)
	local result = apply(self, ...)
	local game = G.GAME
	if game.modifiers.mp_white_minus and not game.mp_white_minus_vouchers then
		G.E_MANAGER:add_event(Event({
			func = function()
				if G.GAME ~= game or game.mp_white_minus_vouchers then return true end
				for _, key in ipairs({ "v_grabber", "v_wasteful" }) do
					if not game.used_vouchers[key] then
						game.used_vouchers[key] = true
						Card.apply_to_run(nil, G.P_CENTERS[key])
					end
				end
				game.mp_white_minus_vouchers = true
				return true
			end,
		}))
	end
	return result
end
