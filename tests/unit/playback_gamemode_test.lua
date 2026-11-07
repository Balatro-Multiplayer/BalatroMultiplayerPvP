-- Plain Lua test: a replay playback gets the same PvP blind a live match has (no game needed).
-- A balanced match has no forced gamemode, and a playback has no lobby code, so the playback used to
-- run with no gamemode at all: every PvP boss came out as a plain boss, a 1-chip rule or a normal
-- blind ended the round on the first hand, and the rest of its recorded plays found no cards.
-- Run from the repo root: luajit tests/unit/playback_gamemode_test.lua
MPAPI = { Rulesets = {}, ReworkCenter = function() end, LoadReworks = function() end }
PVP = {
	LOBBY = { config = { pvp_start_round = 2 } },
	GAME = {},
	SP = { practice = false },
	PVP_GAMEMODES = { pvp_nemesis = { gamemode = "gamemode_mp_attrition" } },
}
function PVP.is_practice_mode() return PVP.SP.practice == true end
dofile("rulesets/_rulesets.lua")
local balanced = {}
function PVP.current_ruleset() return balanced end

local gamemode
PVP.Gamemode = function(init) gamemode = init return { inject = function() end } end
dofile("gamemodes/attrition.lua")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

-- Solo practice keeps its behaviour.
PVP.SP.practice = true
check("practice without a forced gamemode has none", PVP.get_active_gamemode(), nil)

-- A playback of a balanced Nemesis match.
PVP.SP.playback_gamemode = PVP.playback_gamemode_of("pvp_nemesis")
check("playback gamemode of a Nemesis match", PVP.SP.playback_gamemode, "gamemode_mp_attrition")
check("a playback runs the match's gamemode", PVP.get_active_gamemode(), "gamemode_mp_attrition")
check("a live lobby still reads its own config", (function()
	PVP.LOBBY.code = "ABC"
	PVP.LOBBY.config.gamemode = "gamemode_mp_other"
	local got = PVP.get_active_gamemode()
	PVP.LOBBY.code = nil
	return got
end)(), "gamemode_mp_other")

-- The opponent is not known in a playback, which reads as a bye: the boss must still be the PvP one.
PVP.is_byed = function() return true end
local _, _, boss = gamemode.get_blinds_by_ante(gamemode, 2)
check("a playback gets the PvP boss even with no partner", boss, "bl_mp_nemesis")
PVP.SP.playback_gamemode = nil
G = { GAME = { round_resets = { pvp_blind_choices = {} } } }
_, _, boss = gamemode.get_blinds_by_ante(gamemode, 2)
check("a real bye still plays a normal boss", boss, nil)

if failures > 0 then os.exit(1) end
