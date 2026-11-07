SMODS.Atlas({
	key = "almanac_back",
	path = "almanac_back.png",
	px = 71,
	py = 95,
})

SMODS.Back({
	key = "almanac",
	atlas = "mp_almanac_back",
	pos = { x = 0, y = 0 },
	config = {},
	unlocked = true,
	discovered = true,
	loc_txt = {
		name = "Almanac",
		text = {
			"At Antes {C:attention}2, 3, 5 and 7{},",
			"choose {C:attention}1{} of {C:attention}3 Decks{}.",
			"Keep their effects.",
		},
	},
	apply = function()
		local lobby = MPAPI.get_current_lobby()
		local player = lobby and lobby.code and lobby.player_id or "solo"
		G.GAME.almanac_draft = PVP.ALMANAC_DRAFT.new("", player)
		-- Back.apply can run before the game's seed is installed.
		G.GAME.almanac_draft.seed_pending = player
	end,
	calculate = function(self, back, context)
		return PVP.ALMANAC_DRAFT.calculate(back, context)
	end,
})
