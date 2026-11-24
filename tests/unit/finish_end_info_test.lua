-- Run from the repo root: luajit tests/unit/finish_end_info_test.lua
-- ui/game/game_end.lua: the rank line of the end screen, by what the result said.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

G = { FUNCS = { exit_overlay_menu = function() end }, UIDEF = {} }
create_UIBox_game_over = function() end
create_UIBox_win = function() end
Game = { delete_run = function() end }
MPAPI = {}
PVP = { UI = {}, GAME = {}, MATCH_PLAYERS = { State = { ROSTER = 1, LEFT = 2, PLAYING = 3 } } }
localize = function(key) return "text:" .. key end
dofile("ui/game/game_end.lua")

local function line(rank)
	PVP.GAME.end_rank = rank
	return PVP.UI.end_info_line()
end

eq(line("counts").text, "text:k_pvp_game_counts", "a game that counts says so")
eq(line("not_counted").text, "text:k_pvp_game_unrated", "a game that does not count says so")
eq(line("not_counted").scale, 0.4, "the casual line keeps its size")
eq(line("not_counted").padding, 0.05, "and its padding")
eq(line("counts").scale < line("not_counted").scale, true, "the new ranked line is the compact one")
eq(line("unsaid"), nil, "a result that did not say shows no line")
eq(line(nil), nil, "no result shows no line")

print("finish_end_info_test: ok " .. checks)
