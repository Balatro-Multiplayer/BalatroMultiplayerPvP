PVP.MatchmakingPolicy = {}

-- Played when the server has no recipe set.
local BUILT_IN = {
	name = "Bean's Cocktail",
	decks = { "b_abandoned", "b_erratic", "b_checkered" },
}

-- The recipe the server last answered with (set by admins on the website).
-- nil: none set, or none heard yet, so the built-in one applies.
local server_recipe = nil

local function copy(recipe)
	local decks = {}
	for i, key in ipairs(recipe.decks) do
		decks[i] = key
	end
	return { name = recipe.name, decks = decks }
end

-- A recipe off the wire if it has the shape, else nil. PVP.receive_cocktail_recipe
-- still checks every deck against this game when the lobby carries it.
local function wire_recipe(value)
	if type(value) ~= "table" or type(value.decks) ~= "table" or #value.decks < 1 then return nil end
	if type(value.name) ~= "string" then return nil end
	for _, key in ipairs(value.decks) do
		if type(key) ~= "string" then return nil end
	end
	return copy(value)
end

-- Ranked and Casual play the recipe set on the website; private games use the
-- host's selection.
function PVP.MatchmakingPolicy.cocktail_recipe(kind)
	if kind ~= PVP.LobbyAccess.RANKED and kind ~= PVP.LobbyAccess.CASUAL then return nil end
	return copy(server_recipe or BUILT_IN)
end

-- Asks the server for the recipe; an answer replaces the last one, an error
-- keeps it. Call when a matchmaking queue starts, so the host has it when the
-- match is made and stamps the lobby.
function PVP.MatchmakingPolicy.refresh_cocktail()
	local net = MPAPI and MPAPI.networking and MPAPI.networking.nakama_lobby
	if not (net and net.rpc) then return end
	local ok = pcall(net.rpc, "cocktail_recipe", {}, function(err, data)
		if err or type(data) ~= "table" then return end
		server_recipe = wire_recipe(data.recipe)
	end)
	if not ok then sendWarnMessage("[pvp] could not ask for the cocktail recipe", "MULTIPLAYER") end
end

-- For tests: what the last answer set.
function PVP.MatchmakingPolicy._set_server_recipe(value)
	server_recipe = wire_recipe(value)
end
