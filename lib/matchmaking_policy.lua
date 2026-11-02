PVP.MatchmakingPolicy = {}

-- Ranked and Casual share this recipe; private games use the host's selection.
function PVP.MatchmakingPolicy.cocktail_recipe(kind)
	if kind ~= PVP.LobbyAccess.RANKED and kind ~= PVP.LobbyAccess.CASUAL then return nil end
	return {
		name = "Bean's Cocktail",
		decks = { "b_abandoned", "b_erratic", "b_checkered" },
	}
end
