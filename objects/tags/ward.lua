-- Ward Tag: Glyph of Warding's reward. Opens a Jumbo Spectral pack at the same point as the
-- vanilla Ethereal Tag (new_blind_choice).
SMODS.Tag({
	key = "ward",
	name = "Ward Tag",
	pos = { x = 3, y = 3 }, -- the Ethereal Tag sprite in the vanilla tags atlas
	config = { type = "new_blind_choice" },
	discovered = true,
	loc_vars = function(self, info_queue)
		info_queue[#info_queue + 1] = G.P_CENTERS.p_spectral_jumbo_1
	end,
	-- Keeps the Ward Tag out of the pool a skipped blind draws its tag from; the collection
	-- lists G.P_TAGS directly, so it still shows there.
	in_pool = function()
		return false
	end,
	apply = function(self, tag, context)
		if context.type ~= "new_blind_choice" then
			return
		end
		local lock = tag.ID
		G.CONTROLLER.locks[lock] = true
		tag:yep("+", G.C.SECONDARY_SET.Spectral, function()
			local card = Card(
				G.play.T.x + G.play.T.w / 2 - G.CARD_W * 1.27 / 2,
				G.play.T.y + G.play.T.h / 2 - G.CARD_H * 1.27 / 2,
				G.CARD_W * 1.27,
				G.CARD_H * 1.27,
				G.P_CARDS.empty,
				G.P_CENTERS.p_spectral_jumbo_1,
				{ bypass_discovery_center = true, bypass_discovery_ui = true }
			)
			card.cost = 0
			card.from_tag = true
			G.FUNCS.use_card({ config = { ref_table = card } })
			card:start_materialize()
			G.CONTROLLER.locks[lock] = nil
			return true
		end)
		tag.triggered = true
		return true
	end,
})
