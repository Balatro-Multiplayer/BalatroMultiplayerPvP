-- Run from the repo root: luajit tests/unit/current_target_test.lua
-- PVP.current_target_id() with the real lobby_bridge.lua and targets_net.lua: a Royale of three
-- or more names its target from the server's pvp.targets state; the Manhunt, Teams and duel
-- branches are unchanged.
local states, lobby

local failed = 0
local function check(label, got, want)
	if got == want then
		print("ok   " .. label)
	else
		failed = failed + 1
		print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
	end
end

local function setup(config, player_count, game)
	states = {}
	lobby = { mod_id = "pvp", player_id = "me", _game = { started = { run_id = "r1" } } }
	function lobby:get_players()
		local players = { { id = "me" }, { id = "a" }, { id = "b" }, { id = "c" } }
		return { (unpack or table.unpack)(players, 1, player_count) }
	end
	MPAPI = {
		get_current_lobby = function()
			return lobby
		end,
		get_state = function(key)
			return states[key]
		end,
		on_state = function() end,
	}
	PVP = {
		id = "pvp",
		GAME = game or { enemy = { lives = 4 } },
		LOBBY = { config = config, roster = { me = "RUNNER", a = "HUNTER", b = "HUNTER" }, team_id = "RUNNER" },
		get_opponent_id = function()
			return "a"
		end,
		refresh_target_lives = function() end,
		mirror_players = function() end,
	}
	dofile("lib/lives_lookup.lua")
	dofile("pvp_api/lobby_bridge.lua")
	dofile("lib/_state_value.lua")
	dofile("lib/targets_view.lua")
	dofile("lib/lives_view.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/targets_net.lua")
end

local function targets(opponents)
	return { runId = "r1", opponents = opponents, cardTargets = {}, safe = {} }
end

setup({ starting_lives = 4 }, 3)
states["pvp.targets"] = targets({ me = "b", a = "me", b = "a" })
check("royale of 3: the target is read from pvp.targets", PVP.current_target_id(), "b")
states["pvp.targets"] = targets({ me = "a", a = "me", b = "a" })
check("royale of 3: a new state names the new target", PVP.current_target_id(), "a")

setup({ starting_lives = 4 }, 3)
check("royale of 3: no state yet, no target", PVP.current_target_id(), nil)
states["pvp.targets"] = { runId = "r0", opponents = { me = "a", a = "me" }, cardTargets = {}, safe = {} }
check("royale of 3: a state of another run, no target", PVP.current_target_id(), nil)

setup({ starting_lives = 4 }, 4, { enemy = {}, royale_target_id = "c" })
states["pvp.targets"] = targets({ me = "a", a = "me" })
check("royale of 4: the old host-broadcast field is not read", PVP.current_target_id(), "a")

-- Manhunt: the server's opponents map names the Runner for a Hunter and the best-scoring Hunter
-- for the Runner; the old host fields are not read.
setup({ starting_lives = 4, manhunt = true }, 3, { enemy = {}, manhunt_target_id = "c" })
states["pvp.targets"] = targets({ me = "b", a = "me", b = "me" })
check("manhunt runner: the Hunter the server names", PVP.current_target_id(), "b")
states["pvp.targets"] = targets({ me = "a", a = "me", b = "me" })
check("manhunt runner: a new leader changes it", PVP.current_target_id(), "a")
setup({ starting_lives = 4, manhunt = true }, 3, { enemy = {} })
PVP.LOBBY.team_id = "HUNTER"
states["pvp.targets"] = targets({ me = "a", a = "me", b = "me" })
lobby.player_id = "a"
check("manhunt hunter: the Runner from opponents", PVP.current_target_id(), "me")
setup({ starting_lives = 4, manhunt = true }, 3, { enemy = {} })
check("manhunt: no state yet, no target", PVP.current_target_id(), nil)

-- Teams: PVP.TeamsNet (leaf p3a) names the card target; faked here.
setup({ starting_lives = 4, team_based = true }, 4, { enemy = {}, team_card_target_id = "c" })
states["pvp.targets"] = targets({ me = "a", a = "me" })
PVP.TeamsNet = {
	card_target_id = function()
		return "b"
	end,
}
check("teams: the card target from TeamsNet", PVP.current_target_id(), "b")
PVP.TeamsNet.card_target_id = function()
	return nil
end
check("teams: TeamsNet names nobody", PVP.current_target_id(), nil)
PVP.TeamsNet = nil
check("teams: no TeamsNet, no target", PVP.current_target_id(), nil)

setup({ starting_lives = 4 }, 2)
states["pvp.targets"] = targets({ me = "b", b = "me" })
check("duel: the sole other player", PVP.current_target_id(), "a")

-- The game's seat count is the run's started count once the server has said it ("pvp.rules"),
-- not the live seats: a seat that leaves does not change the rules.
local function rules(started_count)
	return { runId = "r1", startedCount = started_count }
end

setup({ starting_lives = 4 }, 2)
states["pvp.rules"] = rules(3)
states["pvp.targets"] = targets({ me = "b", a = "me", b = "a" })
check("royale started with 3, 2 seats left: still read from pvp.targets", PVP.current_target_id(), "b")

setup({ starting_lives = 4 }, 3)
states["pvp.rules"] = rules(2)
states["pvp.targets"] = targets({ me = "b", b = "me" })
check("started with 2: the two-player path", PVP.current_target_id(), "a")

setup({ starting_lives = 4 }, 3)
states["pvp.rules"] = { runId = "r0", startedCount = 2 }
states["pvp.targets"] = targets({ me = "b", b = "me" })
check("rules of another run: the live seat count decides", PVP.current_target_id(), "b")

setup({ starting_lives = 4 }, 2)
states["pvp.targets"] = targets({ me = "b", b = "me" })
check("no rules yet: the live seat count decides (2 seats)", PVP.current_target_id(), "a")

-- The Royale score label (ui/game/blind_hud.lua) follows the server's safe marker.
local function load_label_function()
	local file = assert(io.open("ui/game/blind_hud.lua", "rb"))
	local source = file:read("*a")
	file:close()
	local text = assert(source:match("function PVP%.UI%.refresh_enemy_score_label%(%).-\r?\nend"))
	assert((loadstring or load)(text, "refresh_enemy_score_label"))()
end

localize = function(key)
	return key
end

setup({ starting_lives = 4 }, 3)
PVP.UI = {}
load_label_function()
states["pvp.targets"] = { runId = "r1", opponents = { me = "a", a = "me" }, cardTargets = {}, safe = { me = true } }
PVP.UI.refresh_enemy_score_label()
check("label: a safe player is leading", PVP.GAME.enemy.score_label, "k_royale_leading")
states["pvp.targets"].safe = { me = false }
PVP.UI.refresh_enemy_score_label()
check("label: an unsafe player must beat", PVP.GAME.enemy.score_label, "k_royale_beat")
states["pvp.targets"].safe = {}
PVP.UI.refresh_enemy_score_label()
check("label: an empty safe map keeps the plain label", PVP.GAME.enemy.score_label, "k_enemy_score")

if failed > 0 then os.exit(1) end
print("current_target_test: ok")
