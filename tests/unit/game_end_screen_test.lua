-- Plain LuaJIT test for PVP.Contest.end_screen (which end screen a GAME_ENDED status gets).
-- Run from the repo root: luajit tests/unit/game_end_screen_test.lua
PVP = { LobbyAccess = { PRIVATE = "private", PRACTICE = "practice", RANKED = "ranked", CASUAL = "casual" } }
dofile("lib/contest.lua")
local C = PVP.Contest

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

check("dodged status is named", C.RunStatus.DODGED, "dodged")
check("contested status is unchanged", C.RunStatus.CONTESTED, "contested")

local S = C.EndScreen
check("dodged in the Draft gets the dodge notice", C.end_screen("dodged", { in_run = false }), S.DODGE_NOTICE)
check("dodged in a run gets the dodge notice", C.end_screen("dodged", { in_run = true }), S.DODGE_NOTICE)
check("dodge notice is shown once", C.end_screen("dodged", { in_run = false, dodge_shown = true }), nil)
check("no dodge notice over a contested screen", C.end_screen("dodged", { in_run = true, contested = true }), nil)
check("contested in a run keeps the contested screen", C.end_screen("contested", { in_run = true }), S.CONTESTED)
check("contested outside a run shows nothing", C.end_screen("contested", { in_run = false }), nil)
check("contested twice shows nothing", C.end_screen("contested", { in_run = true, contested = true }), nil)
check("agreed shows nothing", C.end_screen("agreed", { in_run = true }), nil)
check("abandoned shows nothing", C.end_screen("abandoned", { in_run = false }), nil)
check("no status shows nothing", C.end_screen(nil, { in_run = true }), nil)
check("no context does not crash", C.end_screen("dodged", nil), S.DODGE_NOTICE)

-- A game that ended while this client was away: the API raises the server's status with while_away.
check("a dodge learned while away gets the away dodge notice", C.end_screen("dodged", { while_away = true }), "dodge_away")
check("a dodge seen live keeps the stayer's notice", C.end_screen("dodged", { while_away = false }), S.DODGE_NOTICE)
check("an agreed end while away gets the neutral notice", C.end_screen("agreed", { while_away = true }), "ended_away")
check("an abandoned end while away gets the neutral notice", C.end_screen("abandoned", { while_away = true, in_run = true }), "ended_away")
check("a contest while away in a run keeps the contested screen", C.end_screen("contested", { while_away = true, in_run = true }), S.CONTESTED)
check("an away notice is shown once", C.end_screen("agreed", { while_away = true, ended_away_shown = true }), nil)
check("an away dodge notice is shown once", C.end_screen("dodged", { while_away = true, ended_away_shown = true }), nil)
check("no away notice over a contested screen", C.end_screen("agreed", { while_away = true, contested = true }), nil)
check("no away notice after the stayer's dodge notice", C.end_screen("dodged", { while_away = true, dodge_shown = true }), nil)
check("an end seen live and not a dodge shows nothing", C.end_screen("agreed", { while_away = false }), nil)

os.exit(failures == 0 and 0 or 1)
