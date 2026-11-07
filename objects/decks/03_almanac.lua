-- Neutral carrier only: all acquired effects live in the saved draft state.
-- The chaos deck/atlas IDs remain stable for saved runs and recorded loadouts.
SMODS.Atlas({
	key = "chaos_back",
	path = "chaos_back.png",
	px = 71,
	py = 95,
})

SMODS.Back({
	key = "chaos",
	atlas = "mp_chaos_back",
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
		G.GAME.chaos_draft = PVP.ALMANAC_DRAFT.new("", player)
		-- Back.apply can run before the game's seed is installed.
		G.GAME.chaos_draft.seed_pending = player
	end,
	calculate = function(self, back, context)
		return PVP.ALMANAC_DRAFT.calculate(back, context)
	end,
})
