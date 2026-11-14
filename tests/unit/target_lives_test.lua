-- Run from the repo root: luajit tests/unit/target_lives_test.lua
-- The real target readers with a stubbed lobby: when a target is named (the server's
-- pvp.targets for Manhunt, Royale and Nemesis, PVP.TeamsNet for Teams), the enemy lives this
-- client holds become that target's lives.
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
		get_state = function() end,
	}
	PVP = {
		GAME = { enemy = { lives = 4 } },
		LOBBY = { config = config, roster = { r = "RUNNER", h1 = "HUNTER", h2 = "HUNTER" }, team_id = team_id },
		UI = {},
		mirror_players = function() end,
	}
	dofile("pvp_api/actions/_helpers.lua")
	dofile("lib/lives_lookup.lua")
	dofile("lib/_state_value.lua")
	dofile("lib/lives_view.lua")
	dofile("pvp_api/lobby_bridge.lua")
	dofile("lib/targets_view.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/targets_net.lua")
	dofile("pvp_api/actions/score_resolution.lua")
	dofile("pvp_api/actions/team_manhunt.lua")
	-- The lives every client caches from the server's pvp.lives state, received before the target.
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
-- The Manhunt target comes from the server's pvp.targets state too (pvp_api/targets_net.lua).
local hunter = "h1"
PVP.TargetsNet.opponent_id = function()
	return hunter
end
PVP.refresh_target_lives()
check("manhunt: the Runner shows its Hunter target's lives", PVP.GAME.enemy.lives, 7)
hunter = "h2"
PVP.refresh_target_lives()
check("manhunt: a new Hunter target brings its own lives", PVP.GAME.enemy.lives, 5)

setup({ starting_lives = 4 }, nil)
-- The Royale target comes from the server's pvp.targets state too (pvp_api/targets_net.lua).
PVP.TargetsNet.opponent_id = function()
	return "h1"
end
PVP.refresh_target_lives()
check("royale: the target's lives", PVP.GAME.enemy.lives, 7)

setup({ starting_lives = 4, nemesis_pairing = true }, nil)
-- The Nemesis opponent comes from the server's pvp.targets state (pvp_api/targets_net.lua).
PVP.TargetsNet.opponent_id = function()
	return "h2"
end
PVP.refresh_target_lives()
check("nemesis: the partner's lives", PVP.GAME.enemy.lives, 5)

setup({ starting_lives = 4, team_based = true }, "A")
-- The card target comes from PVP.TeamsNet (leaf p3a), faked here.
PVP.TeamsNet = {
	card_target_id = function()
		return "h1"
	end,
}
PVP.refresh_target_lives()
check("teams: the card target's lives", PVP.GAME.enemy.lives, 7)

setup({ starting_lives = 4, manhunt = true }, "RUNNER")
PVP.TargetsNet.opponent_id = function()
	return nil
end
PVP.refresh_target_lives()
check("manhunt: no target keeps the lives shown", PVP.GAME.enemy.lives, 4)

if failures > 0 then os.exit(1) end
