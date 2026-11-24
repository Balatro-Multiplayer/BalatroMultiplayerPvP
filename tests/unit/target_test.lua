-- Run from the repo root: luajit tests/unit/target_test.lua
-- Who the view says I play, every mode: the current target, a bye, the PvP blind offered or not, the
-- Boss slot built before the view answers, the ante's Nemesis, and the Royale score label. Literal
-- views, no net.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local function show(value)
	if type(value) ~= "table" then return tostring(value) end
	local parts = {}
	for _, item in ipairs(value) do parts[#parts + 1] = tostring(item) end
	return "{" .. table.concat(parts, ",") .. "}"
end

local gamemode
local server_lobby = {}
local current_lobby = server_lobby
Game = { update = function() end }
MPAPI = { get_current_lobby = function() return current_lobby end }
PVP = {
	NET = {}, READ = {}, UI = { trap_row = { refresh = function() end }, lobby = {} },
	LOBBY = { config = { pvp_start_ante = 2 } },
	GAME = {},
	PRACTICE = {},
	RULES = { Gamemode = function(init) gamemode = init return { inject = function() end } end, active_gamemode = function() return "attrition" end },
	NEMESIS = { jokers = {}, hidden_jokers = {}, sort_phantoms = function() end },
}
G = { GAME = { round_resets = { ante = 2, pvp_blind_choices = {}, blind_choices = {}, blind_states = {} } } }

dofile("pvp_api/read/_view.lua")
dofile("pvp_api/read/target.lua")
dofile("pvp_api/ui/target.lua")
T.ticked(PVP.UI.target)
dofile("lib/ante_nemesis.lua")
dofile("gamemodes/attrition.lua")
PVP.RULES.gamemodes = { attrition = gamemode }

-- The run's player "a" is me; the server has me on ante 2 unless told otherwise.
local function view_of(targets, run_id, ante)
	return { me = "a", match = { run = { id = run_id, targets = targets, players = { a = { ante = ante or 2 } } } } }
end

local function mode(config, view, lobby)
	PVP.LOBBY.config = {
		pvp_start_ante = 2,
		nemesis_pairing = config.nemesis_pairing,
		manhunt = config.manhunt,
		team_based = config.team_based,
		normal_bosses = config.normal_bosses,
	}
	PVP.NET = { view = view }
	current_lobby = lobby or server_lobby
end

-- What reset_blinds does: a vanilla Boss is rolled, then the gamemode may replace it.
local function build(rolled)
	local resets = G.GAME.round_resets
	resets.pvp_blind_choices = {}
	resets.blind_choices = { Boss = rolled or "bl_goad" }
	resets.blind_states = { Boss = "Upcoming" }
	local _, _, key = gamemode:get_blinds_by_ante(resets.ante)
	resets.blind_choices.Boss = key or resets.blind_choices.Boss
	return resets.blind_choices.Boss
end

-- A later cash-out inside the same ante: vanilla keeps the Boss it rolled, the gamemode asks again.
local function reset_again()
	local resets = G.GAME.round_resets
	resets.pvp_blind_choices = {}
	local _, _, key = gamemode:get_blinds_by_ante(resets.ante)
	resets.blind_choices.Boss = key or resets.blind_choices.Boss
	return resets.blind_choices.Boss
end

local function boss()
	return build() == "bl_mp_nemesis" and "bl_mp_nemesis" or nil
end

local function nemesis_ids()
	PVP.NEMESIS.init_ante()
	PVP.NEMESIS.refresh_ante()
	return show(PVP.NEMESIS.ante_ids())
end

-- Nemesis with 2 players: the one opponent is the target and the PvP blind is offered.
mode({ nemesis_pairing = true }, view_of({ opponents = { "b" }, cardTargets = { "b" }, myBoss = "plays" }))
eq(PVP.READ.target.current_id(), "b", "2-player Nemesis target")
eq(PVP.READ.target.my_boss() == "bye", false, "2-player Nemesis has no bye")
eq(boss(), "bl_mp_nemesis", "2-player Nemesis offers the PvP blind")
eq(G.GAME.round_resets.pvp_boss, "decided", "2-player Nemesis is decided at build")
eq(nemesis_ids(), "{b}", "2-player Nemesis ante Nemesis")

-- Nemesis with 3 or more: a partner for this ante.
mode({ nemesis_pairing = true }, view_of({ opponents = { "c" }, cardTargets = { "c" }, myBoss = "plays" }))
eq(PVP.READ.target.current_id(), "c", "paired Nemesis target")
eq(boss(), "bl_mp_nemesis", "paired Nemesis offers the PvP blind")

-- A bye: the server says so. A normal boss, and no target.
mode({ nemesis_pairing = true }, view_of({ opponents = {}, cardTargets = {}, myBoss = "bye" }))
eq(PVP.READ.target.current_id(), nil, "bye has no target")
eq(PVP.READ.target.my_boss() == "bye", true, "bye is announced")
eq(boss(), nil, "a bye plays a normal boss")
eq(G.GAME.round_resets.blind_choices.Boss, "bl_goad", "a bye keeps the rolled boss")
eq(G.GAME.round_resets.pvp_boss, "decided", "a bye is decided at build")
eq(G.GAME.round_resets.pvp_blind_choices.Boss, true, "a bye's boss is a PvP Boss")
eq(nemesis_ids(), "{}", "bye has no ante Nemesis")

-- A partner who left empties the opponents but is not a bye: the server still counts me in the blind.
mode({ nemesis_pairing = true }, view_of({ opponents = {}, cardTargets = {}, myBoss = "plays" }))
eq(PVP.READ.target.current_id(), nil, "a partner who left leaves no target")
eq(PVP.READ.target.my_boss() == "bye", false, "a partner who left is no bye")
eq(boss(), "bl_mp_nemesis", "a partner who left still offers the PvP blind")
eq(G.GAME.round_resets.pvp_boss, "decided", "a partner who left is decided at build")

-- Neither the pairing's ante nor an empty opponent list says anything about a bye.
mode({ nemesis_pairing = true }, view_of({ pairingAnte = 2, opponents = {}, cardTargets = {} }))
eq(PVP.READ.target.my_boss(), "unknown", "no bye field is unknown")
eq(PVP.READ.target.my_boss() == "bye", false, "no bye field is no bye")
eq(boss(), "bl_mp_nemesis", "an unknown bye builds the placeholder Boss")
eq(G.GAME.round_resets.pvp_boss, "undecided", "an unknown bye leaves the Boss undecided")

-- A Boss with no PvP this ante is decided and no bye.
for _, answer in ipairs({ "no pvp this ante" }) do
	mode({ nemesis_pairing = true }, view_of({ opponents = {}, cardTargets = {}, myBoss = answer }))
	eq(PVP.READ.target.my_boss() == "bye", false, answer .. " is no bye")
	eq(boss() ~= nil, true, answer .. " builds a Boss")
	eq(G.GAME.round_resets.pvp_boss, "decided", answer .. " is decided at build")
end

-- Unknown: no view, a view with no run, a run with no targets. Nothing is a target or a bye, and the Boss is
-- undecided.
for name, view in pairs({ none = false, norun = { me = "a", match = {} }, notargets = { me = "a", match = { run = {} } } }) do
	mode({ nemesis_pairing = true }, view or nil)
	eq(PVP.READ.target.current_id(), nil, "unknown has no target: " .. name)
	eq(PVP.READ.target.my_boss(), "unknown", "unknown is neither: " .. name)
	eq(PVP.READ.target.my_boss() == "bye", false, "unknown is no bye: " .. name)
	eq(boss(), "bl_mp_nemesis", "unknown builds the placeholder Boss: " .. name)
	eq(G.GAME.round_resets.pvp_boss, "undecided", "unknown leaves the Boss undecided: " .. name)
	eq(nemesis_ids(), "{}", "unknown has no ante Nemesis: " .. name)
end

-- Practice and a playback have no view and no partner to wait for: today's PvP blind, decided at build.
mode({ nemesis_pairing = true }, nil)
current_lobby = nil
eq(PVP.READ.target.my_boss() == "bye", false, "practice has no bye")
eq(boss(), "bl_mp_nemesis", "practice offers the PvP blind")
eq(G.GAME.round_resets.pvp_boss, "decided", "practice is decided at build")
mode({ nemesis_pairing = true }, nil, nil)
current_lobby = nil
PVP.PRACTICE.playback_gamemode = "gamemode_mp_attrition"
eq(boss(), "bl_mp_nemesis", "a playback offers the PvP blind")
eq(G.GAME.round_resets.pvp_boss, "decided", "a playback is decided at build")
PVP.PRACTICE.playback_gamemode = nil
current_lobby = server_lobby

-- Normal bosses need no answer.
mode({ nemesis_pairing = true, normal_bosses = true }, nil)
eq(boss(), nil, "normal bosses play a normal boss")
eq(G.GAME.round_resets.pvp_boss, "decided", "normal bosses are never undecided")
eq(G.GAME.round_resets.pvp_blind_choices.Boss, true, "normal bosses before the answer are a PvP boss until a bye says otherwise")
mode({ nemesis_pairing = true, normal_bosses = true }, view_of({ opponents = {}, cardTargets = {}, myBoss = "bye" }))
eq(boss(), nil, "normal bosses with a bye play a normal boss")
eq(G.GAME.round_resets.pvp_blind_choices.Boss, true, "normal bosses with a bye are a PvP Boss too")

-- Built before the view answered: the Boss is decided when the answer arrives, while it is still Upcoming
-- or Select.
local rebuilt = 0
PVP.UI.rebuild_boss_choice = function() rebuilt = rebuilt + 1 end
PVP.LOBBY.mirror_players = function() end
PVP.UI.lobby.refresh_catching_up_badge = function() end
local resets = G.GAME.round_resets

mode({ nemesis_pairing = true }, nil)
eq(build(), "bl_mp_nemesis", "built before the answer")
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_mp_nemesis", "no answer keeps it undecided")
eq(resets.pvp_boss, "undecided", "no answer leaves the flag")
PVP.NET.view = view_of({ opponents = {}, cardTargets = {}, pairingAnte = 2, myBoss = "bye" })
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_goad", "a bye arriving gives the normal boss")
eq(resets.pvp_boss, "decided", "a bye arriving decides it")
eq(resets.pvp_blind_choices.Boss, true, "a bye arriving makes the normal boss a PvP Boss")
eq(rebuilt, 1, "a bye arriving rebuilds the slot")
PVP.UI.target.update()
eq(rebuilt, 1, "decided once")

mode({ nemesis_pairing = true }, nil)
build()
PVP.NET.view = view_of({ opponents = { "c" }, cardTargets = { "c" }, myBoss = "plays" })
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_mp_nemesis", "no bye arriving keeps the PvP blind")
eq(resets.pvp_boss, "decided", "no bye arriving decides it")
eq(rebuilt, 2, "no bye arriving rebuilds the slot though the key is the same, so the name is no longer ????")
PVP.UI.target.update()
eq(rebuilt, 2, "and only once")

mode({ nemesis_pairing = true }, nil)
build()
resets.blind_states.Boss = "Select"
PVP.NET.view = view_of({ opponents = {}, cardTargets = {}, myBoss = "bye" })
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_goad", "a Boss waiting to be picked is decided")

mode({ nemesis_pairing = true }, nil)
build()
resets.blind_states.Boss = "Current"
PVP.NET.view = view_of({ opponents = {}, cardTargets = {}, myBoss = "bye" })
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_mp_nemesis", "a Boss already being played is not decided again")
resets.blind_states.Boss = "Defeated"
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_mp_nemesis", "nor a defeated one")

-- One decider: a Boss that was decided is asked again, by the next cash-out or while it waits to be picked.
-- A rolled boss that is not the default shows the normal boss is the rolled one, not a constant.
mode({ nemesis_pairing = true }, view_of({ opponents = { "c" }, cardTargets = { "c" }, myBoss = "plays" }))
eq(build("bl_hook"), "bl_mp_nemesis", "built with a partner")
PVP.NET.view = view_of({ opponents = {}, cardTargets = {}, myBoss = "bye" })
eq(reset_again(), "bl_hook", "a cash-out that finds a bye puts the rolled boss back")
eq(resets.pvp_blind_choices.Boss, true, "and it is a PvP Boss")
eq(resets.pvp_boss, "decided", "and it is decided")
PVP.NET.view = view_of({ opponents = { "c" }, cardTargets = { "c" }, myBoss = "plays" })
eq(reset_again(), "bl_mp_nemesis", "a cash-out that finds no bye any more puts the PvP blind back")

build("bl_hook")
PVP.NET.view = view_of({ opponents = {}, cardTargets = {}, myBoss = "bye" })
rebuilt = 0
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_hook", "a decided PvP blind waiting on deck follows a bye")
eq(resets.pvp_blind_choices.Boss, true, "and is a PvP Boss")
eq(rebuilt, 1, "and the slot is rebuilt")
PVP.NET.view = view_of({ opponents = { "c" }, cardTargets = { "c" }, myBoss = "plays" })
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_mp_nemesis", "a normal boss waiting on deck follows no bye")
eq(rebuilt, 2, "and the slot is rebuilt again")
PVP.UI.target.update()
eq(rebuilt, 2, "an answer that agrees rebuilds nothing")
resets.blind_states.Boss = "Select"
PVP.NET.view = view_of({ opponents = {}, cardTargets = {}, myBoss = "bye" })
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_hook", "a Boss on Select follows a bye")
resets.blind_states.Boss = "Current"
PVP.NET.view = view_of({ opponents = { "c" }, cardTargets = { "c" }, myBoss = "plays" })
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_hook", "a Boss being played is not asked again")
resets.blind_states.Boss = "Defeated"
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_hook", "nor a defeated one")

-- Normal bosses: the PvP blind flag follows the answer too.
mode({ nemesis_pairing = true, normal_bosses = true }, nil)
build("bl_hook")
eq(resets.pvp_blind_choices.Boss, true, "normal bosses before the answer are a PvP boss")
PVP.NET.view = view_of({ opponents = {}, cardTargets = {}, myBoss = "bye" })
rebuilt = 0
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_hook", "normal bosses keep the normal boss")
eq(resets.pvp_blind_choices.Boss, true, "normal bosses with a bye keep the PvP blind flag")
eq(rebuilt, 0, "and the slot is not rebuilt")

-- Only an answer about the ante being built counts.
mode({ nemesis_pairing = true }, view_of({ opponents = {}, cardTargets = {}, myBoss = "bye" }, nil, 1))
eq(PVP.READ.target.my_boss(), "unknown", "an answer about an earlier ante is unknown")
eq(PVP.READ.target.my_boss() == "bye", false, "and no bye")
eq(build("bl_hook"), "bl_mp_nemesis", "a Boss built on an earlier ante's answer is the undecided placeholder")
eq(resets.pvp_boss, "undecided", "and undecided")
rebuilt = 0
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_mp_nemesis", "an earlier ante's answer does not decide it")
eq(rebuilt, 0, "nor rebuild it")
PVP.NET.view = view_of({ opponents = {}, cardTargets = {}, myBoss = "bye" }, nil, 2)
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_hook", "the answer for this ante decides it")
mode({ nemesis_pairing = true }, view_of({ opponents = {}, cardTargets = {}, myBoss = "plays" }, nil, 3))
eq(PVP.READ.target.my_boss(), "unknown", "an answer about a later ante is unknown")

local my_boss = PVP.READ.target.boss_of
local BOSSES = { ["bye"] = { "bye", true }, ["plays"] = { "plays", false }, ["no pvp this ante"] = { "no pvp this ante", false } }
for answer, want in pairs(BOSSES) do
	eq(my_boss(view_of({ myBoss = answer }, nil, 2), 2), want[1], "my boss: " .. answer)
end
for _, answer in ipairs({ "something new" }) do
	eq(my_boss(view_of({ myBoss = answer }, nil, 2), 2), "unknown", "my boss stays undecided: " .. answer)
end
eq(my_boss(view_of({ myBoss = "bye" }, nil, 2), 3), "unknown", "another game ante: unknown")
eq(my_boss(view_of({ myBoss = "bye" }, nil, 2), nil), "unknown", "no game ante: unknown")
eq(my_boss(nil, 2), "unknown", "no view: unknown")
eq(my_boss({ me = "a", match = { run = { targets = { myBoss = "bye" } } } }, 2), "unknown", "no players: unknown")
eq(my_boss({ me = "a", match = { run = { targets = { myBoss = "bye" }, players = { a = {} } } } }, 2), "unknown", "no player ante: unknown")
eq(my_boss({ me = "a", match = { run = { targets = { myBoss = "bye" }, players = { b = { ante = 2 } } } } }, 2), "unknown", "I am not in the run: unknown")
eq(my_boss({ me = "a", match = { run = { targets = {}, players = { a = { ante = 2 } } } } }, 2), "unknown", "no boss field: unknown")

-- Manhunt: a Hunter's target is the Runner; the Runner's target is one hunter and every hunter is the Nemesis.
mode({ manhunt = true }, view_of({ opponents = { "r" }, cardTargets = { "r" } }))
eq(PVP.READ.target.current_id(), "r", "Hunter target")
eq(nemesis_ids(), "{r}", "Hunter ante Nemesis")
mode({ manhunt = true }, view_of({ opponents = { "h1" }, cardTargets = { "h1", "h2" } }))
eq(PVP.READ.target.current_id(), "h1", "Runner target")
eq(nemesis_ids(), "{h1,h2}", "Runner ante Nemesis is every hunter")
eq(PVP.READ.target.my_boss() == "bye", false, "Manhunt has no bye")
eq(boss(), "bl_mp_nemesis", "Manhunt offers the PvP blind")
eq(G.GAME.round_resets.pvp_boss, "decided", "Manhunt is decided at build")

-- Teams: the card target.
mode({ team_based = true }, view_of({ opponents = {}, cardTargets = { "x" } }))
eq(PVP.READ.target.current_id(), "x", "Teams card target")
eq(PVP.READ.target.my_boss() == "bye", false, "Teams has no bye")
eq(nemesis_ids(), "{x}", "Teams ante Nemesis")

-- Royale: the neighbour.
mode({}, view_of({ opponents = { "n" }, cardTargets = { "n" }, cut = "above the cut" }))
eq(PVP.READ.target.current_id(), "n", "Royale target")
eq(boss(), "bl_mp_nemesis", "Royale offers the PvP blind")
eq(G.GAME.round_resets.pvp_boss, "decided", "Royale is decided at build")

-- The Royale score label.
local reader = PVP.READ.target
eq(reader.score_label_key(view_of({ opponents = { "n" }, cardTargets = { "n" }, cut = "above the cut" }), true), "k_royale_leading", "safe is Leading")
eq(reader.score_label_key(view_of({ opponents = { "n" }, cardTargets = { "n" }, cut = "below the cut" }), true), "k_royale_beat", "not safe is Beat")
eq(reader.score_label_key(view_of({ opponents = {}, cardTargets = {}, cut = "below the cut" }), true), "k_enemy_score", "no target is the plain label")
eq(reader.score_label_key(view_of({ opponents = { "n" }, cardTargets = { "n" }, cut = "above the cut" }), false), "k_enemy_score", "another mode is the plain label")
eq(reader.score_label_key(nil, true), "k_enemy_score", "no view is the plain label")
eq(reader.score_label_key(view_of({ opponents = { "n" }, cardTargets = { "n" } }), true), "k_enemy_score", "no value is the plain label")
-- A 2-player game, or Royale's last two: the server sends null, which reaches Lua as a missing field.
eq(reader.score_label_key(view_of({ opponents = { "n" }, cardTargets = { "n" }, cut = "no cut" }), true), "k_enemy_score", "no cut is the plain label")
mode({}, view_of({ opponents = { "n" }, cardTargets = { "n" }, myBoss = "plays" }))
eq(PVP.READ.target.enemy_score_label_key(), "k_enemy_score", "a 2-player game keeps the plain label")
mode({}, view_of({ opponents = { "n" }, cardTargets = { "n" }, cut = "above the cut" }))
eq(PVP.READ.target.enemy_score_label_key(), "k_royale_leading", "Royale in the safe half says Leading")
mode({}, view_of({ opponents = { "n" }, cardTargets = { "n" }, cut = "below the cut" }))
eq(PVP.READ.target.enemy_score_label_key(), "k_royale_beat", "Royale out of the safe half says Beat")
for name, config in pairs({ nemesis = { nemesis_pairing = true }, manhunt = { manhunt = true }, teams = { team_based = true } }) do
	mode(config, view_of({ opponents = { "n" }, cardTargets = { "n" }, cut = "above the cut" }))
	eq(PVP.READ.target.enemy_score_label_key(), "k_enemy_score", "a mode with no safe half keeps the plain label: " .. name)
end

-- The screen shows again when the view changes the target or the label, and not otherwise.
local mirrored, refreshed = 0, 0
PVP.LOBBY.mirror_players = function() mirrored = mirrored + 1 end
PVP.GAME.enemy = {}
PVP.UI.refresh_enemy_score_label = function() refreshed = refreshed + 1 end
mode({}, view_of({ opponents = { "n" }, cardTargets = { "n" }, cut = "above the cut" }, "r1"))
PVP.UI.target.update()
eq(mirrored, 1, "a new target is mirrored")
eq(refreshed, 1, "a new label is shown")
PVP.UI.target.update()
eq(mirrored + refreshed, 2, "the same view changes nothing")
mode({}, view_of({ opponents = { "n" }, cardTargets = { "n" }, cut = "below the cut" }, "r1"))
PVP.UI.target.update()
eq(mirrored, 1, "the same target is not mirrored again")
eq(refreshed, 2, "a flipped safe half changes the label")
mode({}, view_of({ opponents = { "m" }, cardTargets = { "m" }, cut = "below the cut" }, "r1"))
PVP.UI.target.update()
eq(mirrored, 2, "another target is mirrored")
mode({}, view_of({ opponents = { "m" }, cardTargets = { "m" }, cut = "below the cut" }, "r2"))
PVP.UI.target.update()
eq(mirrored, 3, "a new run shows the same target and label again")
eq(refreshed, 3, "a new run shows the label again")

-- A reader that throws every frame is logged once.
PVP.NET = PVP.NET or {}
dofile("pvp_api/ui/screens.lua")
local warned = 0
sendWarnMessage = function() warned = warned + 1 end
local target_id_ref = PVP.READ.target.target_id
PVP.READ.target.target_id = function() error("boom") end
PVP.UI.screens.tick({ "target" }, PVP.UI, function(text) sendWarnMessage(text) end)
PVP.UI.screens.tick({ "target" }, PVP.UI, function(text) sendWarnMessage(text) end)
eq(warned, 1, "the same error is logged once")
PVP.READ.target.target_id = function() error("another") end
PVP.UI.screens.tick({ "target" }, PVP.UI, function(text) sendWarnMessage(text) end)
eq(warned, 2, "another error is logged")
PVP.READ.target.target_id = target_id_ref

T.done("target_test")
