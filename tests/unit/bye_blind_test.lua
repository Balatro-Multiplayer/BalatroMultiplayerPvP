-- Run from the repo root: luajit tests/unit/bye_blind_test.lua
-- A Nemesis bye plays its Boss as part of the one PvP blind: the Boss the gamemode builds for a bye is a
-- PvP Boss once the game sets the blind (game_state.lua), so the play goes through the blind and not
-- through blindResult (game_state.lua reports "beaten" only for a Boss that is not a PvP Boss).
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

-- The real functions are cut out of their files: those need the whole game to load.
local function load_function(path, header)
	local file = assert(io.open(path, "r"))
	local text = file:read("*a")
	file:close()
	local start = assert(text:find(header, 1, true), "function not found: " .. header)
	local _, finish = text:find("\nend\r?\n", start)
	assert((loadstring or load)(text:sub(start, finish)))()
end

local gamemode
Game = { update = function() end }
MPAPI = { get_current_lobby = function() return {} end }
PVP = {
	LOBBY = { config = { pvp_start_ante = 2, nemesis_pairing = true } },
	GAME = {},
	SP = {},
	Gamemode = function(init) gamemode = init return { inject = function() end } end,
	get_active_gamemode = function() return "attrition" end,
}
G = { GAME = { blind_on_deck = "Boss", round_resets = { ante = 2, pvp_blind_choices = {}, blind_choices = {}, blind_states = {} } } }
Blind = { set_blind = function() end }
blind_set_blindref = function() end

dofile("pvp_api/_view.lua")
dofile("pvp_api/target_reader.lua")
dofile("pvp_api/target_screen.lua")
dofile("gamemodes/attrition.lua")
load_function("objects/blinds/nemesis.lua", "function PVP.is_pvp_boss()")
load_function("ui/game/game_state.lua", "function Blind:set_blind(")

local resets = G.GAME.round_resets
resets.blind_choices = { Boss = "bl_hook" }
PVP.match_net = { view = { me = "a", match = { run = {
	targets = { opponents = {}, cardTargets = {}, myBoss = "bye" },
	players = { a = { ante = 2 } },
} } } }
local _, _, key = gamemode:get_blinds_by_ante(resets.ante)
resets.blind_choices.Boss = key or resets.blind_choices.Boss
eq(resets.blind_choices.Boss, "bl_hook", "the bye plays the rolled boss")

G.GAME.blind = { config = { blind = { key = "bl_hook" } } }
Blind.set_blind(G.GAME.blind, "bl_hook")
eq(PVP.is_pvp_boss(), true, "the bye's Boss is a PvP Boss, so its result goes through the blind")

-- A Boss with no PvP this ante is still a plain blind.
resets.pvp_blind_choices = {}
Blind.set_blind(G.GAME.blind, "bl_hook")
eq(PVP.is_pvp_boss() and true or false, false, "a plain Boss is no PvP Boss")

print(("bye_blind_test: %d checks ok"):format(checks))
