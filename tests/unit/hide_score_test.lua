-- Plain Lua test for the opponent's score mask on the PvP blind HUD (ui/game/blind_hud.lua):
-- the score reads "???" until we have played our first hand of the PvP blind and the server has
-- revealed it (score_known), in every mode.
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
	local known = opts.score_known ~= false
	if opts.score_known_nil then known = nil end
	local score = "1200"
	if opts.score_nil then score = nil end
	G = {
		FUNCS = {},
		GAME = { blind = {}, current_round = { hands_played = opts.hands_played } },
	}
	scale_number = function() return 0.7 end
	PVP = {
		LOBBY = { config = {} },
		GAME = { enemy = { score = score, score_text = "0", hands = 3, score_known = known } },
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

check("score is masked before the server has revealed it, with no hand played",
	hud({ pvp_boss = true, hands_played = 0, score_known = false }).score_text, "???")
check("score is nil at blind start and shows ???, never 0",
	hud({ pvp_boss = true, hands_played = 0, score_nil = true, score_known = false }).score_text, "???")
check("a nil score shows ??? outside the PvP blind too",
	hud({ pvp_boss = false, hands_played = 0, score_nil = true }).score_text, "???")
check("the server's reveal is the only gate: no local hands_played inference",
	hud({ pvp_boss = true, hands_played = 0 }).score_text, "1200")
check("score shows once we have played a hand",
	hud({ pvp_boss = true, hands_played = 1 }).score_text, "1200")
check("score is not masked outside the PvP blind",
	hud({ pvp_boss = false, hands_played = 0 }).score_text, "1200")
check("score is masked while the server has not revealed it, even after our first hand",
	hud({ pvp_boss = true, hands_played = 2, score_known = false }).score_text, "???")
check("score is not masked outside the PvP blind even when unknown",
	hud({ pvp_boss = false, hands_played = 2, score_known = false }).score_text, "1200")
check("score is masked while score_known is nil (never set), even after our first hand",
	hud({ pvp_boss = true, hands_played = 2, score_known_nil = true }).score_text, "???")
check("hands left are never masked",
	hud({ pvp_boss = true, hands_played = 0 }).hands_text, "3")

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
