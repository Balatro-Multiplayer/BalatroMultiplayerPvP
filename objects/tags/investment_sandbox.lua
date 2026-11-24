SMODS.Tag({
	key = "investment_sandbox",
	pos = { x = 2, y = 1 },
	config = { base_dollars = 5, ante_dollars = 10 },
	loc_vars = function(self, info_queue, tag)
		local total_ante_dollars = (G.GAME.round_resets.ante or 0) * 10
		local total_dollars = tag.config.base_dollars + total_ante_dollars
		return { vars = { tag.config.base_dollars, tag.config.ante_dollars, total_dollars } }
	end,
	apply = function(self, tag, context)
		if context.type == "eval" then
			-- ante change is triggered before reward -> base on last ante
			local last_ante = ((G.GAME.round_resets.ante or 0) - 1)
			local total_ante_dollars = last_ante * tag.config.ante_dollars
			local total_dollars = tag.config.base_dollars + total_ante_dollars
			if G.GAME.last_blind and G.GAME.last_blind.boss then
				tag:yep("+", G.C.GOLD, function()
					return true
				end)
				tag.triggered = true
				return {
					dollars = total_dollars,
					condition = localize("ph_defeat_the_boss"),
					pos = tag.pos,
					tag = tag,
				}
			end
		end
	end,
	unlocked = true,
	discovered = true,
	no_collection = PVP.SANDBOX.no_collection,
})
