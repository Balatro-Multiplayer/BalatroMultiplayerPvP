local GLASS_CANNON_HANDS = -2
local GLASS_CANNON_XMULT = 4

MPAPI.Layer("glass_cannon", {
	calculate = function(self, context)
		if context.apply_bans then PVP.apply_round_deltas("glass_cannon", { hands = GLASS_CANNON_HANDS }) end
	end,
})

-- final_scoring_step called after jokers to let the deck rebalance chips/mult
-- (it's where Plasma does its math)
-- so we wrap that burrito and then scale the mult on top
local _back_trigger_effect = Back.trigger_effect
function Back:trigger_effect(args)
	-- magic. don't ask
	local nu_chip, nu_mult = _back_trigger_effect(self, args)
	if args and args.context == "final_scoring_step" and PVP.is_layer_active("glass_cannon") then
		local base_mult = nu_mult or args.mult
		return nu_chip, base_mult * GLASS_CANNON_XMULT
	end
	return nu_chip, nu_mult
end
