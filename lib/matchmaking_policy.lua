PVP.MatchmakingPolicy = {}

-- Played when the server has no recipe set.
local BUILT_IN = {
	name = "Bean's Cocktail",
	decks = { "b_abandoned", "b_erratic", "b_checkered" },
}

-- The recipe the server last answered with (set by admins on the website).
-- nil: none set, or none heard yet, so the built-in one applies.
-- { name, random = true }: every Cocktail tile on the Draft board gets its own
-- three decks. With same_every_tile, every tile shares one roll per game.
local server_recipe = nil

-- What a random Cocktail draws from: the vanilla and PvP decks, the ones the
-- website offers. Every player has them, so a guest never refuses the roll
-- (PVP.receive_cocktail_recipe leaves a lobby over a deck it doesn't know).
local RANDOM_POOL = {
	"b_red", "b_blue", "b_yellow", "b_green", "b_black", "b_magic", "b_nebula", "b_ghost",
	"b_abandoned", "b_checkered", "b_zodiac", "b_painted", "b_anaglyph", "b_plasma", "b_erratic",
	"b_mp_orange", "b_mp_indigo", "b_mp_violet", "b_mp_white", "b_mp_oracle", "b_mp_gradient",
	"b_mp_heidelberg", "b_mp_echodeck",
}
local RANDOM_DECKS = 3

-- The roll of the lobby the host is in: { code, recipe, played }. A lobby keeps
-- its roll until its next game (PVP.MatchmakingPolicy.next_game_cocktail), so
-- stamping the metadata again doesn't change it.
local rolled = nil
local rng = nil

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
	if type(value) ~= "table" or type(value.name) ~= "string" then return nil end
	if value.random == true then
		return { name = value.name, random = true, same_every_tile = value.sameEveryTile == true }
	end
	if type(value.decks) ~= "table" or #value.decks < 1 then return nil end
	for _, key in ipairs(value.decks) do
		if type(key) ~= "string" then return nil end
	end
	return copy(value)
end

local function roll_random(name)
	rng = rng or PVP.new_rng()
	local pool = {}
	for _, key in ipairs(RANDOM_POOL) do
		local center = G.P_CENTERS[key]
		if center and center.set == "Back" then pool[#pool + 1] = key end
	end
	local decks = {}
	while #decks < RANDOM_DECKS and #pool > 0 do
		decks[#decks + 1] = table.remove(pool, rng(#pool))
	end
	if #decks == 0 then return copy(BUILT_IN) end
	return { name = name, decks = decks }
end

local function current_code()
	local lobby = MPAPI and MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	return (lobby and lobby.code) or (PVP.LOBBY and PVP.LOBBY.code) or nil
end

-- The current lobby's random roll, rolled the first time it is asked for.
local function lobby_roll()
	local code = current_code()
	if not (rolled and code and rolled.code == code) then
		rolled = { code = code, recipe = roll_random(server_recipe.name), played = false }
	end
	return rolled
end

-- Ranked and Casual play the recipe set on the website; private games use the
-- host's selection.
function PVP.MatchmakingPolicy.cocktail_recipe(kind)
	if kind ~= PVP.LobbyAccess.RANKED and kind ~= PVP.LobbyAccess.CASUAL then return nil end
	if server_recipe and server_recipe.random then return copy(lobby_roll().recipe) end
	return copy(server_recipe or BUILT_IN)
end

-- The host, building the Draft board: the mix for one Cocktail tile. Each tile
-- rolls its own when the website asks for a random Cocktail; nil when every
-- tile plays the lobby's recipe (a fixed one, or random "same every tile").
-- The mix travels with the tile (its `cocktail_mix`), so every player sees and
-- plays the same one.
function PVP.MatchmakingPolicy.tile_cocktail(kind)
	if kind ~= PVP.LobbyAccess.RANKED and kind ~= PVP.LobbyAccess.CASUAL then return nil end
	if not (server_recipe and server_recipe.random) or server_recipe.same_every_tile then return nil end
	return roll_random(server_recipe.name)
end

-- The host, before each Ranked or Casual game: a random Cocktail rolls again
-- for every game after the lobby's first (the first plays the roll the lobby
-- was stamped with, which players may already have hovered). nil: nothing to
-- change (a fixed recipe, or the first game).
function PVP.MatchmakingPolicy.next_game_cocktail(kind)
	if kind ~= PVP.LobbyAccess.RANKED and kind ~= PVP.LobbyAccess.CASUAL then return nil end
	if not (server_recipe and server_recipe.random) then return nil end
	local roll = lobby_roll()
	if not roll.played then
		roll.played = true
		return nil
	end
	roll.recipe = roll_random(server_recipe.name)
	return copy(roll.recipe)
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
