PVP.QUEUE.policy = {}

-- Ranked and Casual share this recipe; private games use the host's selection.
function PVP.QUEUE.policy.cocktail_recipe(kind)
	if kind ~= PVP.LOBBY.Access.RANKED and kind ~= PVP.LOBBY.Access.CASUAL then return nil end
	return {
		name = "Bean's Cocktail",
		decks = { "b_abandoned", "b_erratic", "b_checkered" },
	}
end
