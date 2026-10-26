MPAPI.Layer("bigger_shop", {
	calculate = function(self, context)
		if context.apply_bans and not G.GAME.pvp_bigger_shop_applied then
			change_shop_size(1)
			G.GAME.pvp_bigger_shop_applied = true
		end
	end,
})
