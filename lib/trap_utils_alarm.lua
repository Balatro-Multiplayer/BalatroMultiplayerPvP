-- Vanilla refills current_round.free_rerolls from round_resets.free_rerolls when a round starts
-- (new_round in functions/state_events.lua), so rerolls added outside a shop are wiped before the
-- next shop opens. Rerolls granted while no shop is open wait in G.GAME (saved with the run) and are
-- added when a shop opens. round_resets is left alone: SMODS.change_free_rerolls would make them permanent.
local function add_free_rerolls(count)
	G.GAME.current_round.free_rerolls = (G.GAME.current_round.free_rerolls or 0) + count
	calculate_reroll_cost(true)
end

-- G.shop exists for the whole shop visit, including while a pack opened from it is open.
function PVP.TRAP.grant_free_rerolls(count)
	if G.shop then
		add_free_rerolls(count)
	else
		G.GAME.mp_pending_free_rerolls = (G.GAME.mp_pending_free_rerolls or 0) + count
	end
end

local update_shop_ref = Game.update_shop
function Game:update_shop(dt)
	if PVP.in_session() and not G.STATE_COMPLETE and (G.GAME.mp_pending_free_rerolls or 0) > 0 then
		local pending = G.GAME.mp_pending_free_rerolls
		G.GAME.mp_pending_free_rerolls = nil
		add_free_rerolls(pending)
	end
	return update_shop_ref(self, dt)
end
