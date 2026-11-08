-- Run from the repo root: luajit tests/unit/target_lives_test.lua
-- The real target handlers with a stubbed lobby: when the host names a new target,
-- the enemy lives this client holds become that target's lives.
local handlers, lobby

local function setup(config, team_id)
	handlers = {}
	lobby = { player_id = "r", players = { { id = "r" }, { id = "h1" }, { id = "h2" } } }
	function lobby:get_players()
		return self.players
	end
	MPAPI = {
		get_current_lobby = function()
			return lobby
		end,
		ActionType = function(spec)
			handlers[spec.key] = spec.on_receive
		end,
		sendWarnMessage = function() end,
	}
	PVP = {
		GAME = { enemy = { lives = 4 } },
		LOBBY = { config = config, roster = { r = "RUNNER", h1 = "HUNTER", h2 = "HUNTER" }, team_id = team_id },
		UI = {},
		mirror_players = function() end,
		on_nemesis_pairing = function() end,
	}
	dofile("pvp_api/actions/_helpers.lua")
	dofile("lib/lives_lookup.lua")
	dofile("pvp_api/lobby_bridge.lua")
	dofile("pvp_api/actions/score_resolution.lua")
	dofile("pvp_api/actions/team_manhunt.lua")
	-- The lives every client caches from pvp_player_lives, received before the target.
	PVP._player_lives_cache = { r = 4, h1 = 7, h2 = 5 }
end

local failures = 0
local function check(label, got, want)
	if got == want then
		print("ok   " .. label)
	else
		failures = failures + 1
		print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
	end
end

setup({ starting_lives = 4, manhunt = true }, "RUNNER")
handlers.pvp_manhunt_target(nil, nil, { target_id = "h1" })
check("manhunt: the Runner shows its Hunter target's lives", PVP.GAME.enemy.lives, 7)
handlers.pvp_manhunt_target(nil, nil, { target_id = "h2" })
check("manhunt: a new Hunter target brings its own lives", PVP.GAME.enemy.lives, 5)

setup({ starting_lives = 4 }, nil)
handlers.pvp_royale_target(nil, nil, { targets = { r = "h1" } })
check("royale: the target's lives", PVP.GAME.enemy.lives, 7)

setup({ starting_lives = 4, nemesis_pairing = true }, nil)
handlers.pvp_nemesis_pairing(nil, nil, { pairing = { r = "h2" } })
check("nemesis: the partner's lives", PVP.GAME.enemy.lives, 5)

setup({ starting_lives = 4, team_based = true }, "A")
handlers.pvp_team_card_target(nil, nil, { pairing = { r = "h1" } })
check("teams: the card target's lives", PVP.GAME.enemy.lives, 7)

setup({ starting_lives = 4, manhunt = true }, "RUNNER")
handlers.pvp_manhunt_target(nil, nil, { target_id = "" })
check("manhunt: no target keeps the lives shown", PVP.GAME.enemy.lives, 4)

if failures > 0 then
	os.exit(1)
end
