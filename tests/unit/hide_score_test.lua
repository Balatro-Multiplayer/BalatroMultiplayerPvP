-- Plain Lua test for the opponent's score mask on the PvP blind HUD (ui/game/blind_hud.lua):
-- the score reads "???" until we have played our first hand of the PvP blind, in every mode.
-- Run from the repo root: luajit tests/unit/hide_score_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

-- blind_hud.lua needs the whole game to load, so load just the HUD scale function from it.
local file = assert(io.open("ui/game/blind_hud.lua", "r"))
local text = file:read("*a")
file:close()
local header = "G.FUNCS.multiplayer_blind_chip_UI_scale = function(e)"
local start = assert(text:find(header, 1, true), "function not found")
local _, finish = text:find("\nend\r?\n", start)
local chunk = text:sub(start, finish)

local function hud(opts)
	G = {
		FUNCS = {},
		GAME = { blind = {}, current_round = { hands_played = opts.hands_played } },
	}
	scale_number = function() return 0.7 end
	PVP = {
		LOBBY = { config = {} },
		GAME = { enemy = { score = "1200", score_text = "0", hands = 3 } },
		Score = {
			display = function(s) return s end,
			small_number = function(s) return tonumber(s) end,
		},
		is_practice_mode = function() return false end,
		is_pvp_boss = function() return opts.pvp_boss end,
	}
	assert((loadstring or load)(chunk))()
	G.FUNCS.multiplayer_blind_chip_UI_scale({ config = {} })
	return PVP.GAME.enemy
end

check("score is masked before our first hand of the PvP blind",
	hud({ pvp_boss = true, hands_played = 0 }).score_text, "???")
check("score shows once we have played a hand",
	hud({ pvp_boss = true, hands_played = 1 }).score_text, "1200")
check("score is not masked outside the PvP blind",
	hud({ pvp_boss = false, hands_played = 0 }).score_text, "1200")
check("hands left are never masked",
	hud({ pvp_boss = true, hands_played = 0 }).hands_text, "3")

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
